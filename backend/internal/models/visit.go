package models

import (
	"encoding/json"
	"time"
)

// Visit represents a vendor's visit to a customer location within a route.
type Visit struct {
	ID              string          `json:"id" db:"id"`
	RouteID         string          `json:"route_id" db:"route_id"`
	WaypointID      string          `json:"waypoint_id" db:"waypoint_id"`
	PelangganID     *string         `json:"pelanggan_id" db:"pelanggan_id"`
	OrderID         *string         `json:"order_id" db:"order_id"`
	VisitOrder      int             `json:"visit_order" db:"visit_order"`
	PlannedArrival  *string         `json:"planned_arrival" db:"planned_arrival"`
	ActualArrival   *time.Time      `json:"actual_arrival" db:"actual_arrival"`
	ActualDeparture *time.Time      `json:"actual_departure" db:"actual_departure"`
	ItemsSold       json.RawMessage `json:"items_sold" db:"items_sold"`
	Amount          *float64        `json:"amount" db:"amount"`
	PaymentMethod   string          `json:"payment_method" db:"payment_method"`
	PaymentStatus   string          `json:"payment_status" db:"payment_status"`
	Notes           *string         `json:"notes" db:"notes"`
	Status          string          `json:"status" db:"status"`
	CreatedAt       time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at" db:"updated_at"`
	// Computed fields (populated via LEFT JOINs)
	WaypointLabel string `json:"waypoint_label,omitempty" db:"waypoint_label"`
	PelangganName string `json:"pelanggan_name,omitempty" db:"pelanggan_name"`
	DurationMin   int    `json:"duration_min,omitempty" db:"duration_min"`
}

// VisitItem represents a single product sold during a visit.
type VisitItem struct {
	ProductID string  `json:"product_id"`
	Name      string  `json:"name"`
	Qty       float64 `json:"qty"`
	Unit      string  `json:"unit"`
	Price     float64 `json:"price"`
	Subtotal  float64 `json:"subtotal"`
}
