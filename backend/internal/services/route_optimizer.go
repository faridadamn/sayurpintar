package services

import (
	"context"
	"fmt"
	"math"
	"sort"

	"github.com/sayurpintar/api/internal/models"
	"go.uber.org/zap"
)

// Constraints configures the route optimization algorithm.
type Constraints struct {
	PriorityWeight bool    // Higher priority waypoints visited first
	TimeWindows    bool    // Respect preferred_time_start/end
	MaxIterations  int     // 2-opt iteration limit (default: 1000)
	MaxDuration    float64 // Max total route duration in minutes (0 = unlimited)
}

// DefaultConstraints returns sensible defaults for route optimization.
func DefaultConstraints() *Constraints {
	return &Constraints{
		PriorityWeight: true,
		TimeWindows:    true,
		MaxIterations:  1000,
		MaxDuration:    0,
	}
}

// OptimizedRoute holds the result of route optimization.
type OptimizedRoute struct {
	OrderedWaypoints     []models.WaypointWithOrder `json:"ordered_waypoints"`
	TotalDistanceKm      float64                    `json:"total_distance_km"`
	EstimatedDurationMin int                        `json:"estimated_duration_min"`
	EstimatedFuelCost    float64                    `json:"estimated_fuel_cost"`
	Polyline             string                     `json:"polyline"`
}

// RouteOptimizer implements the TSP solver using Nearest Neighbor + 2-opt.
type RouteOptimizer struct {
	osrm   *OSRMService
	logger *zap.Logger
}

// NewRouteOptimizer creates a new route optimizer.
func NewRouteOptimizer(osrm *OSRMService, logger *zap.Logger) *RouteOptimizer {
	return &RouteOptimizer{
		osrm:   osrm,
		logger: logger,
	}
}

// OptimizeRoute takes waypoints and returns the optimal visiting order.
// Algorithm: Nearest Neighbor initial solution + 2-opt improvement.
func (o *RouteOptimizer) OptimizeRoute(ctx context.Context, start OSRMPoint, waypoints []models.Waypoint, constraints *Constraints) (*OptimizedRoute, error) {
	if len(waypoints) == 0 {
		return &OptimizedRoute{
			OrderedWaypoints:     []models.WaypointWithOrder{},
			TotalDistanceKm:      0,
			EstimatedDurationMin: 0,
			EstimatedFuelCost:    0,
		}, nil
	}

	if constraints == nil {
		constraints = DefaultConstraints()
	}

	// Build the list of all points: [start, waypoint1, waypoint2, ...]
	allPoints := make([]OSRMPoint, 0, len(waypoints)+1)
	allPoints = append(allPoints, start)
	for _, wp := range waypoints {
		allPoints = append(allPoints, OSRMPoint{
			Longitude: wp.Location.Longitude,
			Latitude:  wp.Location.Latitude,
		})
	}

	// Get distance matrix from OSRM
	matrix, err := o.osrm.GetDistanceMatrix(ctx, allPoints)
	if err != nil {
		return nil, fmt.Errorf("get distance matrix: %w", err)
	}

	// Run Nearest Neighbor to get initial solution
	// Indices 1..N correspond to waypoints (0 is start)
	route := o.NearestNeighbor(matrix, 0, waypoints, constraints)

	// Apply 2-opt improvement
	maxIter := constraints.MaxIterations
	if maxIter <= 0 {
		maxIter = 1000
	}
	route = o.TwoOptImprovement(route, matrix, maxIter)

	// Apply time window constraints if enabled
	if constraints.TimeWindows {
		route = o.ApplyTimeWindows(route, waypoints)
	}

	// Calculate totals
	totalDist, totalDur := o.calculateRouteTotals(route, matrix)

	// Check max duration constraint
	if constraints.MaxDuration > 0 && totalDur > constraints.MaxDuration {
		o.logger.Warn("optimized route exceeds max duration",
			zap.Float64("duration_min", totalDur),
			zap.Float64("max_duration", constraints.MaxDuration))
	}

	// Build ordered waypoints with ETA
	orderedWaypoints := o.buildOrderedWaypoints(route, waypoints, matrix, start)

	// Build full route polyline
	polyline, err := o.buildRoutePolyline(ctx, start, route, waypoints)
	if err != nil {
		o.logger.Warn("failed to build route polyline", zap.Error(err))
		// Non-fatal: continue without polyline
	}

	return &OptimizedRoute{
		OrderedWaypoints:     orderedWaypoints,
		TotalDistanceKm:      math.Round(totalDist*100) / 100,
		EstimatedDurationMin: int(math.Round(totalDur)),
		EstimatedFuelCost:    math.Round(CalculateFuelCost(totalDist)*100) / 100,
		Polyline:             polyline,
	}, nil
}

// NearestNeighbor creates an initial greedy solution.
// Starting from the start point, always visits the nearest unvisited waypoint.
// When PriorityWeight is enabled, high-priority waypoints are sorted first.
func (o *RouteOptimizer) NearestNeighbor(matrix *DistanceMatrix, startIdx int, waypoints []models.Waypoint, constraints *Constraints) []int {
	n := len(waypoints)
	if n == 0 {
		return []int{}
	}

	// Build priority-sorted index if needed
	type indexedWP struct {
		idx      int
		priority int
	}
	sorted := make([]indexedWP, n)
	for i, wp := range waypoints {
		sorted[i] = indexedWP{idx: i + 1, priority: wp.Priority} // +1 because 0 is start
	}

	if constraints.PriorityWeight {
		sort.Slice(sorted, func(i, j int) bool {
			return sorted[i].priority > sorted[j].priority
		})
	}

	visited := make(map[int]bool)
	route := make([]int, 0, n)
	current := startIdx

	for len(route) < n {
		// Find the nearest unvisited waypoint
		// If priority weight is on, prefer high-priority waypoints within a close distance tier
		bestIdx := -1
		bestDist := math.MaxFloat64

		for _, wp := range sorted {
			if visited[wp.idx] {
				continue
			}

			dist := matrix.Distances[current][wp.idx]

			// With priority weighting, give a distance discount to high-priority waypoints
			if constraints.PriorityWeight {
				// Priority 3 → 40% discount, Priority 2 → 20%, Priority 1 → 0%
				discount := float64(wp.priority-1) * 0.2
				dist = dist * (1.0 - discount)
			}

			if dist < bestDist {
				bestDist = dist
				bestIdx = wp.idx
			}
		}

		if bestIdx == -1 {
			break // shouldn't happen
		}

		visited[bestIdx] = true
		route = append(route, bestIdx)
		current = bestIdx
	}

	return route
}

// TwoOptImprovement improves the route by swapping edges.
// Iteratively reverses segments to reduce total distance.
// Stops when no improvement is found or max iterations reached.
func (o *RouteOptimizer) TwoOptImprovement(route []int, matrix *DistanceMatrix, maxIter int) []int {
	n := len(route)
	if n < 3 {
		return route
	}

	// We need to include the start (index 0) in the distance calculation.
	// The route is a sequence of waypoint indices; distances are looked up from the full matrix.
	improved := true
	iter := 0

	for improved && iter < maxIter {
		improved = false
		iter++

		for i := 0; i < n-1; i++ {
			for j := i + 2; j < n; j++ {
				// Wrap around: if j+1 is out of bounds, we compare against start (0)
				jNext := j + 1
				if jNext >= n {
					jNext = 0 // wrap to start point
				}

				var iPrev int
				if i == 0 {
					iPrev = 0 // from start point
				} else {
					iPrev = route[i-1]
				}

				// Current edges: (route[i-1]→route[i]) and (route[j]→route[jNext])
				// New edges:    (route[i-1]→route[j]) and (route[i]→route[jNext])
				//
				// For i==0: the "previous" is the start point (index 0 in the matrix)
				// For the last waypoint wrapping: route[jNext] = 0 (start point)

				currentDist := matrix.Distances[iPrev][route[i]] + matrix.Distances[route[j]][route[jNext]]
				newDist := matrix.Distances[iPrev][route[j]] + matrix.Distances[route[i]][route[jNext]]

				if newDist < currentDist-1e-9 { // small epsilon for float comparison
					// Reverse the segment between i and j (inclusive)
					o.reverse(route, i, j)
					improved = true
				}
			}
		}
	}

	o.logger.Debug("2-opt completed",
		zap.Int("iterations", iter),
		zap.Int("route_length", n))

	return route
}

// reverse reverses the segment route[i..j] in-place.
func (o *RouteOptimizer) reverse(route []int, i, j int) {
	for i < j {
		route[i], route[j] = route[j], route[i]
		i++
		j--
	}
}

// ApplyTimeWindows reorders the route to respect customer time preferences.
// Waypoints with preferred_time_start are moved to an appropriate position.
func (o *RouteOptimizer) ApplyTimeWindows(route []int, waypoints []models.Waypoint) []int {
	if len(route) < 2 {
		return route
	}

	// Separate time-constrained and unconstrained waypoints
	type constrainedWP struct {
		originalIdx int // index in route slice
		wpIdx       int // waypoint index (1-based)
		startMin    int // preferred start time in minutes from midnight
		endMin      int // preferred end time in minutes from midnight
	}

	var constrained []constrainedWP
	var unconstrained []int

	for i, wpIdx := range route {
		wp := waypoints[wpIdx-1] // wpIdx is 1-based
		if wp.PreferredTimeStart != nil && wp.PreferredTimeEnd != nil {
			startMin := parseTimeToMinutes(*wp.PreferredTimeStart)
			endMin := parseTimeToMinutes(*wp.PreferredTimeEnd)
			if startMin >= 0 && endMin >= 0 {
				constrained = append(constrained, constrainedWP{
					originalIdx: i,
					wpIdx:       wpIdx,
					startMin:    startMin,
					endMin:      endMin,
				})
				continue
			}
		}
		unconstrained = append(unconstrained, wpIdx)
	}

	if len(constrained) == 0 {
		return route
	}

	// Sort constrained by preferred start time
	sort.Slice(constrained, func(i, j int) bool {
		return constrained[i].startMin < constrained[j].startMin
	})

	// Build new route: interleave constrained into unconstrained at their preferred positions
	// Simple strategy: place constrained waypoints at positions proportional to their time window
	totalSlots := len(route)
	result := make([]int, totalSlots)
	used := make([]bool, totalSlots)

	// Place constrained waypoints at positions proportional to their start time
	for _, cw := range constrained {
		// Calculate ideal position based on time window (0-1440 minutes → 0-totalSlots)
		ratio := float64(cw.startMin) / 1440.0
		idealPos := int(ratio * float64(totalSlots))
		if idealPos >= totalSlots {
			idealPos = totalSlots - 1
		}

		// Find nearest free slot
		pos := o.findNearestFreeSlot(used, idealPos, totalSlots)
		result[pos] = cw.wpIdx
		used[pos] = true
	}

	// Fill remaining slots with unconstrained waypoints
	unconIdx := 0
	for i := 0; i < totalSlots; i++ {
		if !used[i] && unconIdx < len(unconstrained) {
			result[i] = unconstrained[unconIdx]
			unconIdx++
		}
	}

	return result
}

// findNearestFreeSlot finds the closest unused position to the target.
func (o *RouteOptimizer) findNearestFreeSlot(used []bool, target, size int) int {
	for offset := 0; offset < size; offset++ {
		// Check right first, then left
		right := target + offset
		if right < size && !used[right] {
			return right
		}
		left := target - offset
		if left >= 0 && !used[left] {
			return left
		}
	}
	return target
}

// parseTimeToMinutes converts a time string (HH:MM or HH:MM:SS) to minutes from midnight.
func parseTimeToMinutes(t string) int {
	var h, m int
	n, err := fmt.Sscanf(t, "%d:%d", &h, &m)
	if n < 2 || err != nil {
		return -1
	}
	return h*60 + m
}

// CalculateFuelCost estimates fuel cost based on distance.
// Uses: distance_km / fuel_efficiency * fuel_price_per_liter
// Default: 35 km/L motor (typical Indonesian scooter), Rp 10,000/L Pertalite.
func CalculateFuelCost(distanceKm float64) float64 {
	const (
		fuelEfficiencyKmPerL = 35.0    // km per liter
		fuelPricePerLiter    = 10000.0 // IDR per liter
	)
	return (distanceKm / fuelEfficiencyKmPerL) * fuelPricePerLiter
}

// calculateRouteTotals computes total distance and duration for a route.
// It sums distances between consecutive waypoints, including start→first and last→start.
func (o *RouteOptimizer) calculateRouteTotals(route []int, matrix *DistanceMatrix) (totalDist float64, totalDur float64) {
	if len(route) == 0 {
		return 0, 0
	}

	// Start → first waypoint
	totalDist += matrix.Distances[0][route[0]]
	totalDur += matrix.Durations[0][route[0]]

	// Waypoint → waypoint
	for i := 0; i < len(route)-1; i++ {
		totalDist += matrix.Distances[route[i]][route[i+1]]
		totalDur += matrix.Durations[route[i]][route[i+1]]
	}

	// Last waypoint → start (return trip)
	totalDist += matrix.Distances[route[len(route)-1]][0]
	totalDur += matrix.Durations[route[len(route)-1]][0]

	return totalDist, totalDur
}

// buildOrderedWaypoints creates WaypointWithOrder entries with estimated arrival times.
func (o *RouteOptimizer) buildOrderedWaypoints(route []int, waypoints []models.Waypoint, matrix *DistanceMatrix, start OSRMPoint) []models.WaypointWithOrder {
	result := make([]models.WaypointWithOrder, len(route))
	// Assume start at 06:00 (typical vendor start time)
	currentMinute := 6 * 60 // 6:00 AM in minutes

	// Add travel from start to first waypoint
	if len(route) > 0 {
		currentMinute += int(matrix.Durations[0][route[0]])
	}

	for i, wpIdx := range route {
		wp := waypoints[wpIdx-1] // wpIdx is 1-based
		hours := currentMinute / 60
		mins := currentMinute % 60
		eta := fmt.Sprintf("%02d:%02d", hours, mins)

		result[i] = models.WaypointWithOrder{
			Waypoint: wp,
			Order:    i + 1,
			ETA:      eta,
		}

		// Add travel time to next waypoint
		if i < len(route)-1 {
			currentMinute += int(matrix.Durations[route[i]][route[i+1]])
			// Add 5 minutes service time per stop
			currentMinute += 5
		}
	}

	return result
}

// buildRoutePolyline fetches the full route geometry from OSRM.
func (o *RouteOptimizer) buildRoutePolyline(ctx context.Context, start OSRMPoint, route []int, waypoints []models.Waypoint) (string, error) {
	if len(route) == 0 {
		return "", nil
	}

	// Build waypoints for OSRM route: start → wp1 → wp2 → ... → start
	routePoints := make([]OSRMPoint, 0, len(route)+2)
	routePoints = append(routePoints, start)
	for _, wpIdx := range route {
		wp := waypoints[wpIdx-1]
		routePoints = append(routePoints, OSRMPoint{
			Longitude: wp.Location.Longitude,
			Latitude:  wp.Location.Latitude,
		})
	}
	routePoints = append(routePoints, start) // return to start

	// Build OSRM URL with all waypoints
	coords := make([]string, len(routePoints))
	for i, p := range routePoints {
		coords[i] = p.String()
	}

	// We'll fetch the full route in segments to avoid URL length limits
	// For simplicity, fetch start→end pairs and concatenate
	var fullGeometry string
	for i := 0; i < len(routePoints)-1; i++ {
		seg, err := o.osrm.GetRoute(ctx, routePoints[i], routePoints[i+1])
		if err != nil {
			return fullGeometry, fmt.Errorf("get route segment %d: %w", i, err)
		}
		if fullGeometry == "" {
			fullGeometry = seg.Geometry
		} else {
			fullGeometry += ";" + seg.Geometry
		}
	}

	return fullGeometry, nil
}
