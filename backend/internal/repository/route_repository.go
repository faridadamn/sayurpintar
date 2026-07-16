package repository

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// Route-specific errors.
var (
	ErrRouteNotFound = errors.New("route not found")
)

// RouteRepository defines the data access contract for routes.
type RouteRepository interface {
	Create(ctx context.Context, route *models.Route) error
	GetByID(ctx context.Context, id string) (*models.Route, error)
	GetByPedagangAndDate(ctx context.Context, pedagangID string, date string) (*models.Route, error)
	Update(ctx context.Context, route *models.Route) error
	UpdateStatus(ctx context.Context, routeID string, status string) error
	ListByPedagang(ctx context.Context, pedagangID string, from, to string) ([]models.Route, error)
	Delete(ctx context.Context, id string) error
}

// routeRepo implements RouteRepository backed by pgxpool.
type routeRepo struct {
	pool *pgxpool.Pool
}

// NewRouteRepository returns a new RouteRepository backed by the given pool.
func NewRouteRepository(pool *pgxpool.Pool) RouteRepository {
	return &routeRepo{pool: pool}
}

const routeColumns = `
	id, pedagang_id, date, start_location,
	waypoint_ids, optimized_order,
	total_distance_km, estimated_duration_min, estimated_fuel_cost,
	actual_distance_km, actual_duration_min,
	status, started_at, completed_at, created_at, updated_at
`

// scanRoute scans a row into a Route struct.
func scanRoute(row pgx.Row) (*models.Route, error) {
	var r models.Route
	var locationWKT *string

	err := row.Scan(
		&r.ID,
		&r.PedagangID,
		&r.Date,
		&locationWKT,
		&r.WaypointIDs,
		&r.OptimizedOrder,
		&r.TotalDistanceKm,
		&r.EstimatedDurationMin,
		&r.EstimatedFuelCost,
		&r.ActualDistanceKm,
		&r.ActualDurationMin,
		&r.Status,
		&r.StartedAt,
		&r.CompletedAt,
		&r.CreatedAt,
		&r.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if locationWKT != nil {
		pt, err := models.ScanPoint(*locationWKT)
		if err != nil {
			return nil, fmt.Errorf("scan start_location: %w", err)
		}
		r.StartLocation = pt
	}

	return &r, nil
}

// Create inserts a new route and populates generated fields.
func (r *routeRepo) Create(ctx context.Context, route *models.Route) error {
	query := `
		INSERT INTO routes (
			pedagang_id, date, start_location,
			waypoint_ids, optimized_order,
			total_distance_km, estimated_duration_min, estimated_fuel_cost,
			actual_distance_km, actual_duration_min,
			status, started_at, completed_at
		) VALUES (
			$1, $2, CASE WHEN $3::text IS NOT NULL THEN ST_GeographyFromText($3) ELSE NULL END,
			$4, $5,
			$6, $7, $8,
			$9, $10,
			$11, $12, $13
		)
		RETURNING ` + routeColumns

	var locationWKT *string
	if route.StartLocation != nil {
		wkt := models.RouteStartLocationWKT(route.StartLocation.Latitude, route.StartLocation.Longitude)
		locationWKT = &wkt
	}

	row := r.pool.QueryRow(ctx, query,
		route.PedagangID,
		route.Date,
		locationWKT,
		route.WaypointIDs,
		route.OptimizedOrder,
		route.TotalDistanceKm,
		route.EstimatedDurationMin,
		route.EstimatedFuelCost,
		route.ActualDistanceKm,
		route.ActualDurationMin,
		route.Status,
		route.StartedAt,
		route.CompletedAt,
	)

	created, err := scanRoute(row)
	if err != nil {
		return fmt.Errorf("insert route: %w", err)
	}

	*route = *created
	return nil
}

// GetByID fetches a route by its UUID.
func (r *routeRepo) GetByID(ctx context.Context, id string) (*models.Route, error) {
	query := `SELECT ` + routeColumns + ` FROM routes WHERE id = $1`

	route, err := scanRoute(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRouteNotFound
		}
		return nil, fmt.Errorf("get route by id: %w", err)
	}
	return route, nil
}

// GetByPedagangAndDate fetches a route for a specific pedagang on a specific date.
func (r *routeRepo) GetByPedagangAndDate(ctx context.Context, pedagangID string, date string) (*models.Route, error) {
	query := `SELECT ` + routeColumns + ` FROM routes WHERE pedagang_id = $1 AND date = $2`

	route, err := scanRoute(r.pool.QueryRow(ctx, query, pedagangID, date))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRouteNotFound
		}
		return nil, fmt.Errorf("get route by pedagang and date: %w", err)
	}
	return route, nil
}

// Update persists changes to mutable route fields.
func (r *routeRepo) Update(ctx context.Context, route *models.Route) error {
	query := `
		UPDATE routes
		SET start_location = CASE WHEN $2::text IS NOT NULL THEN ST_GeographyFromText($2) ELSE NULL END,
		    waypoint_ids = $3,
		    optimized_order = $4,
		    total_distance_km = $5,
		    estimated_duration_min = $6,
		    estimated_fuel_cost = $7,
		    actual_distance_km = $8,
		    actual_duration_min = $9,
		    status = $10,
		    started_at = $11,
		    completed_at = $12,
		    updated_at = NOW()
		WHERE id = $1
		RETURNING ` + routeColumns

	var locationWKT *string
	if route.StartLocation != nil {
		wkt := models.RouteStartLocationWKT(route.StartLocation.Latitude, route.StartLocation.Longitude)
		locationWKT = &wkt
	}

	row := r.pool.QueryRow(ctx, query,
		route.ID,
		locationWKT,
		route.WaypointIDs,
		route.OptimizedOrder,
		route.TotalDistanceKm,
		route.EstimatedDurationMin,
		route.EstimatedFuelCost,
		route.ActualDistanceKm,
		route.ActualDurationMin,
		route.Status,
		route.StartedAt,
		route.CompletedAt,
	)

	updated, err := scanRoute(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRouteNotFound
		}
		return fmt.Errorf("update route: %w", err)
	}

	*route = *updated
	return nil
}

// UpdateStatus changes the status of a route.
func (r *routeRepo) UpdateStatus(ctx context.Context, routeID string, status string) error {
	query := `
		UPDATE routes
		SET status = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, routeID, status).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRouteNotFound
		}
		return fmt.Errorf("update route status: %w", err)
	}
	return nil
}

// ListByPedagang returns routes for a pedagang within a date range.
func (r *routeRepo) ListByPedagang(ctx context.Context, pedagangID string, from, to string) ([]models.Route, error) {
	var conditions []string
	var args []interface{}
	argIdx := 1

	conditions = append(conditions, fmt.Sprintf("pedagang_id = $%d", argIdx))
	args = append(args, pedagangID)
	argIdx++

	if from != "" {
		conditions = append(conditions, fmt.Sprintf("date >= $%d", argIdx))
		args = append(args, from)
		argIdx++
	}
	if to != "" {
		conditions = append(conditions, fmt.Sprintf("date <= $%d", argIdx))
		args = append(args, to)
		argIdx++
	}

	query := fmt.Sprintf(
		`SELECT %s FROM routes WHERE %s ORDER BY date DESC`,
		routeColumns,
		strings.Join(conditions, " AND "),
	)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list routes: %w", err)
	}
	defer rows.Close()

	var routes []models.Route
	for rows.Next() {
		route, err := scanRoute(rows)
		if err != nil {
			return nil, fmt.Errorf("scan route row: %w", err)
		}
		routes = append(routes, *route)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate routes: %w", err)
	}

	if routes == nil {
		routes = []models.Route{}
	}
	return routes, nil
}

// Delete removes a route by ID.
func (r *routeRepo) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM routes WHERE id = $1 RETURNING id`

	var deletedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&deletedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRouteNotFound
		}
		return fmt.Errorf("delete route: %w", err)
	}
	return nil
}

// RouteStats holds aggregate route statistics.
type RouteStats struct {
	TotalRoutes     int      `json:"total_routes"`
	AvgDistanceKm   float64  `json:"avg_distance_km"`
	AvgDurationMin  float64  `json:"avg_duration_min"`
	AvgFuelCost     float64  `json:"avg_fuel_cost"`
	TotalDistanceKm float64  `json:"total_distance_km"`
	TotalDurationHr float64  `json:"total_duration_hr"`
	CompletionRate  float64  `json:"completion_rate"`
}

// GetRouteStats returns aggregate statistics for a pedagang's routes over the given number of days.
func (r *routeRepo) GetRouteStats(ctx context.Context, pedagangID string, days int) (*RouteStats, error) {
	query := `
		SELECT
			COUNT(*) AS total_routes,
			COALESCE(AVG(total_distance_km), 0) AS avg_distance_km,
			COALESCE(AVG(estimated_duration_min), 0) AS avg_duration_min,
			COALESCE(AVG(estimated_fuel_cost), 0) AS avg_fuel_cost,
			COALESCE(SUM(total_distance_km), 0) AS total_distance_km,
			COALESCE(SUM(estimated_duration_min), 0) AS total_duration_min,
			CASE
				WHEN COUNT(*) > 0 THEN
					ROUND(COUNT(*) FILTER (WHERE status = 'completed')::decimal / COUNT(*) * 100, 1)
				ELSE 0
			END AS completion_rate
		FROM routes
		WHERE pedagang_id = $1
		  AND date >= CURRENT_DATE - INTERVAL '1 day' * $2`

	var stats RouteStats
	var totalDurationMin float64
	err := r.pool.QueryRow(ctx, query, pedagangID, days).Scan(
		&stats.TotalRoutes,
		&stats.AvgDistanceKm,
		&stats.AvgDurationMin,
		&stats.AvgFuelCost,
		&stats.TotalDistanceKm,
		&totalDurationMin,
		&stats.CompletionRate,
	)
	if err != nil {
		return nil, fmt.Errorf("get route stats: %w", err)
	}

	stats.TotalDurationHr = totalDurationMin / 60.0

	// Round values
	stats.AvgDistanceKm = math.Round(stats.AvgDistanceKm*100) / 100
	stats.AvgDurationMin = math.Round(stats.AvgDurationMin*100) / 100
	stats.AvgFuelCost = math.Round(stats.AvgFuelCost*100) / 100
	stats.TotalDistanceKm = math.Round(stats.TotalDistanceKm*100) / 100
	stats.TotalDurationHr = math.Round(stats.TotalDurationHr*100) / 100

	return &stats, nil
}
