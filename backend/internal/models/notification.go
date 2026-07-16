package models

import (
	"encoding/json"
	"time"
)

// Notification represents a user notification.
type Notification struct {
	ID        string          `json:"id" db:"id"`
	UserID    string          `json:"user_id" db:"user_id"`
	Type      string          `json:"type" db:"type"`
	Title     string          `json:"title" db:"title"`
	Body      string          `json:"body" db:"body"`
	Data      json.RawMessage `json:"data" db:"data"`
	IsRead    bool            `json:"is_read" db:"is_read"`
	ReadAt    *time.Time      `json:"read_at" db:"read_at"`
	CreatedAt time.Time       `json:"created_at" db:"created_at"`
}

// Notification type constants.
const (
	NotifTypeOrder      = "order"
	NotifTypePayment    = "payment"
	NotifTypeInsight    = "insight"
	NotifTypeReward     = "reward"
	NotifTypePromo      = "promo"
	NotifTypeSystem     = "system"
	NotifTypeSubscriber = "subscriber"
	NotifTypeRoute      = "route"
)
