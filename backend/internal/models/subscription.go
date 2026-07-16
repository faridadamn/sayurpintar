package models

import (
	"encoding/json"
	"time"
)

// SubscriptionPackage represents a subscription package created by a pedagang.
type SubscriptionPackage struct {
	ID              string          `json:"id" db:"id"`
	PedagangID      string          `json:"pedagang_id" db:"pedagang_id"`
	Name            string          `json:"name" db:"name"`
	Description     *string         `json:"description" db:"description"`
	Items           json.RawMessage `json:"items" db:"items"`
	Price           float64         `json:"price" db:"price"`
	Frequency       string          `json:"frequency" db:"frequency"`
	DeliveryDays    []int           `json:"delivery_days" db:"delivery_days"`
	MaxSubscribers  int             `json:"max_subscribers" db:"max_subscribers"`
	IsActive        bool            `json:"is_active" db:"is_active"`
	CreatedAt       time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time       `json:"updated_at" db:"updated_at"`
	// Computed fields (populated by JOIN queries)
	PedagangName    string `json:"pedagang_name,omitempty" db:"pedagang_name"`
	SubscriberCount int    `json:"subscriber_count,omitempty" db:"subscriber_count"`
}

// PackageItem represents a single item inside a subscription package.
type PackageItem struct {
	ProductID    string  `json:"product_id"`
	Name         string  `json:"name"`
	Qty          float64 `json:"qty"`
	Unit         string  `json:"satuan"`
	PricePerUnit float64 `json:"harga_per_unit"`
}

// Subscription represents an active subscription by a pelanggan to a package.
type Subscription struct {
	ID               string     `json:"id" db:"id"`
	PackageID        string     `json:"package_id" db:"package_id"`
	PedagangID       string     `json:"pedagang_id" db:"pedagang_id"`
	PelangganID      string     `json:"pelanggan_id" db:"pelanggan_id"`
	PaymentMethod    string     `json:"payment_method" db:"payment_method"`
	PaymentFrequency string     `json:"payment_frequency" db:"payment_frequency"`
	Status           string     `json:"status" db:"status"`
	StartDate        string     `json:"start_date" db:"start_date"`
	EndDate          *string    `json:"end_date" db:"end_date"`
	PauseReason      *string    `json:"pause_reason" db:"pause_reason"`
	PausedAt         *time.Time `json:"paused_at" db:"paused_at"`
	CancelledAt      *time.Time `json:"cancelled_at" db:"cancelled_at"`
	CancelReason     *string    `json:"cancel_reason" db:"cancel_reason"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
	// Computed fields (populated by JOIN queries)
	PackageName    string `json:"package_name,omitempty" db:"package_name"`
	PelangganName  string `json:"pelanggan_name,omitempty" db:"pelanggan_name"`
	PelangganPhone string `json:"pelanggan_phone,omitempty" db:"pelanggan_phone"`
	NextDelivery   string `json:"next_delivery,omitempty" db:"next_delivery"`
}

// SubscriptionModification represents a per-delivery modification or skip.
type SubscriptionModification struct {
	ID             string          `json:"id" db:"id"`
	SubscriptionID string          `json:"subscription_id" db:"subscription_id"`
	DeliveryDate   string          `json:"delivery_date" db:"delivery_date"`
	Items          json.RawMessage `json:"items" db:"items"`
	SkipDelivery   bool            `json:"skip_delivery" db:"skip_delivery"`
	Reason         string          `json:"reason" db:"reason"`
	CreatedAt      time.Time       `json:"created_at" db:"created_at"`
}
