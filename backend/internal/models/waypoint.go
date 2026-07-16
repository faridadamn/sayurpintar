package models

import (
	"fmt"
	"time"
)

// Waypoint represents a customer location managed by a pedagang (vendor).
type Waypoint struct {
	ID                 string     `json:"id" db:"id"`
	PedagangID         string     `json:"pedagang_id" db:"pedagang_id"`
	PelangganID        *string    `json:"pelanggan_id,omitempty" db:"pelanggan_id"`
	Label              string     `json:"label" db:"label"`
	Address            *string    `json:"address,omitempty" db:"address"`
	Location           Point      `json:"location" db:"location"`
	Notes              *string    `json:"notes,omitempty" db:"notes"`
	Priority           int        `json:"priority" db:"priority"`
	IsActive           bool       `json:"is_active" db:"is_active"`
	PreferredTimeStart *string    `json:"preferred_time_start,omitempty" db:"preferred_time_start"`
	PreferredTimeEnd   *string    `json:"preferred_time_end,omitempty" db:"preferred_time_end"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
	// Computed fields (populated via LEFT JOINs)
	PelangganName string     `json:"pelanggan_name,omitempty" db:"pelanggan_name"`
	VisitCount    int        `json:"visit_count,omitempty" db:"visit_count"`
	LastVisitAt   *time.Time `json:"last_visit_at,omitempty" db:"last_visit_at"`
	// Distance in meters, populated by spatial queries
	DistanceM *float64 `json:"distance_m,omitempty" db:"distance_m"`
}

// WaypointLocationWKT returns the WKT representation for PostGIS insertion.
func WaypointLocationWKT(lat, lng float64) string {
	return fmt.Sprintf("SRID=4326;POINT(%f %f)", lng, lat)
}
