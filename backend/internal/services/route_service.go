package services

import (
	"context"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// RouteStats holds aggregate route statistics returned by the service.
type RouteStats struct {
	TotalRoutes     int     `json:"total_routes"`
	AvgDistanceKm   float64 `json:"avg_distance_km"`
	AvgDurationMin  float64 `json:"avg_duration_min"`
	AvgFuelCost     float64 `json:"avg_fuel_cost"`
	TotalDistanceKm float64 `json:"total_distance_km"`
	TotalDurationHr float64 `json:"total_duration_hr"`
	CompletionRate  float64 `json:"completion_rate"`
}

// RouteService manages daily route lifecycle and optimization.
type RouteService struct {
	routeRepo    repository.RouteRepository
	waypointRepo repository.WaypointRepository
	optimizer    *RouteOptimizer
	osrm         *OSRMService
	logger       *zap.Logger
}

// NewRouteService creates a new RouteService.
func NewRouteService(
	routeRepo repository.RouteRepository,
	waypointRepo repository.WaypointRepository,
	optimizer *RouteOptimizer,
	osrm *OSRMService,
	logger *zap.Logger,
) *RouteService {
	return &RouteService{
		routeRepo:    routeRepo,
		waypointRepo: waypointRepo,
		optimizer:    optimizer,
		osrm:         osrm,
		logger:       logger,
	}
}

// GetOrCreateTodayRoute gets today's route for a pedagang, or creates a new one
// auto-populated with all active langganan waypoints.
func (s *RouteService) GetOrCreateTodayRoute(ctx context.Context, pedagangID string) (*models.Route, error) {
	today := time.Now().Format("2006-01-02")

	// Try to get existing route for today
	route, err := s.routeRepo.GetByPedagangAndDate(ctx, pedagangID, today)
	if err == nil {
		return route, nil
	}
	if err != repository.ErrRouteNotFound {
		return nil, fmt.Errorf("get today route: %w", err)
	}

	// No route for today — create one with all active waypoints
	waypoints, err := s.waypointRepo.ListByPedagang(ctx, pedagangID, true)
	if err != nil {
		return nil, fmt.Errorf("list active waypoints: %w", err)
	}

	waypointIDs := make([]string, len(waypoints))
	for i, wp := range waypoints {
		waypointIDs[i] = wp.ID
	}

	// Get pedagang's start location (from the users table via waypoint or default)
	// For now, use the first waypoint as start location if available
	var startLocation *models.Point
	if len(waypoints) > 0 {
		startLocation = &waypoints[0].Location
	}

	newRoute := &models.Route{
		PedagangID:    pedagangID,
		Date:          today,
		StartLocation: startLocation,
		WaypointIDs:   waypointIDs,
		Status:        string(models.RouteStatusPlanned),
	}

	if err := s.routeRepo.Create(ctx, newRoute); err != nil {
		return nil, fmt.Errorf("create today route: %w", err)
	}

	s.logger.Info("created today's route",
		zap.String("pedagang_id", pedagangID),
		zap.String("date", today),
		zap.Int("waypoint_count", len(waypointIDs)))

	return newRoute, nil
}

// OptimizeTodayRoute calculates the optimal route for today.
func (s *RouteService) OptimizeTodayRoute(ctx context.Context, pedagangID string) (*OptimizedRoute, error) {
	route, err := s.GetOrCreateTodayRoute(ctx, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("get today route: %w", err)
	}

	if len(route.WaypointIDs) == 0 {
		return &OptimizedRoute{
			OrderedWaypoints:    []models.WaypointWithOrder{},
			TotalDistanceKm:      0,
			EstimatedDurationMin: 0,
			EstimatedFuelCost:    0,
		}, nil
	}

	// Fetch full waypoint details
	waypoints := make([]models.Waypoint, 0, len(route.WaypointIDs))
	validIDs := make([]string, 0, len(route.WaypointIDs))

	for _, wpID := range route.WaypointIDs {
		wp, err := s.waypointRepo.GetByID(ctx, wpID)
		if err != nil {
			s.logger.Warn("skipping waypoint in optimization",
				zap.String("waypoint_id", wpID),
				zap.Error(err))
			continue
		}
		waypoints = append(waypoints, *wp)
		validIDs = append(validIDs, wpID)
	}

	if len(waypoints) == 0 {
		return &OptimizedRoute{
			OrderedWaypoints:    []models.WaypointWithOrder{},
			TotalDistanceKm:      0,
			EstimatedDurationMin: 0,
			EstimatedFuelCost:    0,
		}, nil
	}

	// Determine start location
	var start OSRMPoint
	if route.StartLocation != nil {
		start = OSRMPoint{
			Longitude: route.StartLocation.Longitude,
			Latitude:  route.StartLocation.Latitude,
		}
	} else {
		// Default: use first waypoint's location
		start = OSRMPoint{
			Longitude: waypoints[0].Location.Longitude,
			Latitude:  waypoints[0].Location.Latitude,
		}
	}

	// Run optimization
	optimized, err := s.optimizer.OptimizeRoute(ctx, start, waypoints, DefaultConstraints())
	if err != nil {
		return nil, fmt.Errorf("optimize route: %w", err)
	}

	// Build optimized order (waypoint IDs in optimized sequence)
	optimizedOrder := make([]string, len(optimized.OrderedWaypoints))
	for i, owp := range optimized.OrderedWaypoints {
		optimizedOrder[i] = owp.Waypoint.ID
	}

	// Update route in database
	route.WaypointIDs = validIDs
	route.OptimizedOrder = optimizedOrder
	route.TotalDistanceKm = optimized.TotalDistanceKm
	route.EstimatedDurationMin = optimized.EstimatedDurationMin
	route.EstimatedFuelCost = optimized.EstimatedFuelCost

	if err := s.routeRepo.Update(ctx, route); err != nil {
		s.logger.Error("failed to save optimized route", zap.Error(err))
		// Continue — the optimization result is still valid
	}

	s.logger.Info("route optimized",
		zap.String("pedagang_id", pedagangID),
		zap.Int("waypoints", len(optimized.OrderedWaypoints)),
		zap.Float64("total_km", optimized.TotalDistanceKm),
		zap.Int("duration_min", optimized.EstimatedDurationMin),
		zap.Float64("fuel_cost", optimized.EstimatedFuelCost))

	return optimized, nil
}

// AddWaypointToRoute adds a waypoint to today's route.
func (s *RouteService) AddWaypointToRoute(ctx context.Context, pedagangID, waypointID string) error {
	// Validate waypoint exists and belongs to this pedagang
	wp, err := s.waypointRepo.GetByID(ctx, waypointID)
	if err != nil {
		return fmt.Errorf("get waypoint: %w", err)
	}
	if wp.PedagangID != pedagangID {
		return fmt.Errorf("waypoint does not belong to this pedagang")
	}

	route, err := s.GetOrCreateTodayRoute(ctx, pedagangID)
	if err != nil {
		return fmt.Errorf("get today route: %w", err)
	}

	// Check if already in route
	for _, id := range route.WaypointIDs {
		if id == waypointID {
			return fmt.Errorf("waypoint already in today's route")
		}
	}

	route.WaypointIDs = append(route.WaypointIDs, waypointID)
	// Clear optimized order since route changed
	route.OptimizedOrder = nil

	if err := s.routeRepo.Update(ctx, route); err != nil {
		return fmt.Errorf("update route: %w", err)
	}

	return nil
}

// RemoveWaypointFromRoute removes a waypoint from today's route.
func (s *RouteService) RemoveWaypointFromRoute(ctx context.Context, pedagangID, waypointID string) error {
	route, err := s.GetOrCreateTodayRoute(ctx, pedagangID)
	if err != nil {
		return fmt.Errorf("get today route: %w", err)
	}

	found := false
	newIDs := make([]string, 0, len(route.WaypointIDs)-1)
	for _, id := range route.WaypointIDs {
		if id == waypointID {
			found = true
			continue
		}
		newIDs = append(newIDs, id)
	}

	if !found {
		return fmt.Errorf("waypoint not in today's route")
	}

	route.WaypointIDs = newIDs
	// Clear optimized order since route changed
	route.OptimizedOrder = nil

	if err := s.routeRepo.Update(ctx, route); err != nil {
		return fmt.Errorf("update route: %w", err)
	}

	return nil
}

// StartRoute marks a route as in_progress and records the start time.
func (s *RouteService) StartRoute(ctx context.Context, routeID string) error {
	route, err := s.routeRepo.GetByID(ctx, routeID)
	if err != nil {
		return fmt.Errorf("get route: %w", err)
	}

	if route.Status != string(models.RouteStatusPlanned) {
		return fmt.Errorf("cannot start route with status '%s'", route.Status)
	}

	now := time.Now()
	route.Status = string(models.RouteStatusInProgress)
	route.StartedAt = &now

	if err := s.routeRepo.Update(ctx, route); err != nil {
		return fmt.Errorf("update route: %w", err)
	}

	return nil
}

// CompleteRoute marks a route as completed with actual metrics.
func (s *RouteService) CompleteRoute(ctx context.Context, routeID string, actualDistance float64, actualDuration int) error {
	route, err := s.routeRepo.GetByID(ctx, routeID)
	if err != nil {
		return fmt.Errorf("get route: %w", err)
	}

	if route.Status != string(models.RouteStatusInProgress) {
		return fmt.Errorf("cannot complete route with status '%s'", route.Status)
	}

	now := time.Now()
	route.Status = string(models.RouteStatusCompleted)
	route.CompletedAt = &now
	route.ActualDistanceKm = &actualDistance
	route.ActualDurationMin = &actualDuration

	if err := s.routeRepo.Update(ctx, route); err != nil {
		return fmt.Errorf("update route: %w", err)
	}

	return nil
}

// GetRouteHistory returns routes for a pedagang within a date range.
func (s *RouteService) GetRouteHistory(ctx context.Context, pedagangID string, from, to string) ([]models.Route, error) {
	routes, err := s.routeRepo.ListByPedagang(ctx, pedagangID, from, to)
	if err != nil {
		return nil, fmt.Errorf("list routes: %w", err)
	}
	return routes, nil
}

// GetRouteStats returns aggregate statistics for a pedagang's routes.
func (s *RouteService) GetRouteStats(ctx context.Context, pedagangID string, days int) (*RouteStats, error) {
	if days <= 0 {
		days = 30 // default to last 30 days
	}

	stats, err := s.routeRepo.GetRouteStats(ctx, pedagangID, days)
	if err != nil {
		return nil, fmt.Errorf("get route stats: %w", err)
	}

	return &RouteStats{
		TotalRoutes:     stats.TotalRoutes,
		AvgDistanceKm:   stats.AvgDistanceKm,
		AvgDurationMin:  stats.AvgDurationMin,
		AvgFuelCost:     stats.AvgFuelCost,
		TotalDistanceKm: stats.TotalDistanceKm,
		TotalDurationHr: stats.TotalDurationHr,
		CompletionRate:  stats.CompletionRate,
	}, nil
}
