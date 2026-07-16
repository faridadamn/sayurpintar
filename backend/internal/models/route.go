package models

import (
	"fmt"
	"time"
)

// RouteStatus represents the lifecycle state of a vendor's daily route.
type RouteStatus string

const (
	RouteStatusPlanned    RouteStatus = "planned"
	RouteStatusInProgress RouteStatus = "in_progress"
	RouteStatusCompleted  RouteStatus = "completed"
	RouteStatusCancelled  RouteStatus = "cancelled"
)

// Route represents a pedagang's daily optimized delivery route.
type Route struct {
	ID                   string     `json:"id" db:"id"`
	PedagangID           string     `json:"pedagang_id" db:"pedagang_id"`
	Date                 string     `json:"date" db:"date"`
	StartLocation        *Point     `json:"start_location" db:"start_location"`
	WaypointIDs          []string   `json:"waypoint_ids" db:"waypoint_ids"`
	OptimizedOrder       []string   `json:"optimized_order" db:"optimized_order"`
	TotalDistanceKm      float64    `json:"total_distance_km" db:"total_distance_km"`
	EstimatedDurationMin int        `json:"estimated_duration_min" db:"estimated_duration_min"`
	EstimatedFuelCost    float64    `json:"estimated_fuel_cost" db:"estimated_fuel_cost"`
	ActualDistanceKm     *float64   `json:"actual_distance_km" db:"actual_distance_km"`
	ActualDurationMin    *int       `json:"actual_duration_min" db:"actual_duration_min"`
	Status               string     `json:"status" db:"status"`
	StartedAt            *time.Time `json:"started_at" db:"started_at"`
	CompletedAt          *time.Time `json:"completed_at" db:"completed_at"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
	// Computed: populated by service layer after optimization
	Waypoints []WaypointWithOrder `json:"waypoints,omitempty"`
}

// WaypointWithOrder pairs a waypoint with its position in an optimized route and estimated arrival time.
type WaypointWithOrder struct {
	Waypoint Waypoint `json:"waypoint"`
	Order    int      `json:"order"`
	ETA      string   `json:"eta"`
}

// RouteStartLocationWKT returns the WKT representation for PostGIS insertion.
func RouteStartLocationWKT(lat, lng float64) string {
	return fmt.Sprintf("SRID=4326;POINT(%f %f)", lng, lat)
}
