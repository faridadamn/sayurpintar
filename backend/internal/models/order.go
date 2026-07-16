package models

import (
	"encoding/json"
	"time"
)

// OrderStatus represents the lifecycle state of an order.
type OrderStatus string

const (
	OrderStatusPending    OrderStatus = "pending"
	OrderStatusPreparing  OrderStatus = "preparing"
	OrderStatusDelivering OrderStatus = "delivering"
	OrderStatusDelivered  OrderStatus = "delivered"
	OrderStatusCancelled  OrderStatus = "cancelled"
	OrderStatusSkipped    OrderStatus = "skipped"
)

// PaymentStatus represents the payment state of an order.
type PaymentStatus string

const (
	PaymentStatusPending  PaymentStatus = "pending"
	PaymentStatusPaid     PaymentStatus = "paid"
	PaymentStatusPartial  PaymentStatus = "partial"
	PaymentStatusDeferred PaymentStatus = "deferred"
)

// Order represents a single delivery order.
type Order struct {
	ID             string          `json:"id" db:"id"`
	SubscriptionID *string         `json:"subscription_id" db:"subscription_id"`
	PedagangID     string          `json:"pedagang_id" db:"pedagang_id"`
	PelangganID    string          `json:"pelanggan_id" db:"pelanggan_id"`
	Items          json.RawMessage `json:"items" db:"items"`
	TotalPrice     float64         `json:"total_price" db:"total_price"`
	Status         string          `json:"status" db:"status"`
	DeliveryDate   string          `json:"delivery_date" db:"delivery_date"`
	DeliveryNotes  *string         `json:"delivery_notes" db:"delivery_notes"`
	DeliveredAt    *time.Time      `json:"delivered_at" db:"delivered_at"`
	CancelledAt    *time.Time      `json:"cancelled_at" db:"cancelled_at"`
	CancelReason   *string         `json:"cancel_reason" db:"cancel_reason"`
	Rating         *int            `json:"rating" db:"rating"`
	RatingComment  *string         `json:"rating_comment" db:"rating_comment"`
	RatedAt        *time.Time      `json:"rated_at" db:"rated_at"`
	PaymentMethod  string          `json:"payment_method" db:"payment_method"`
	PaymentStatus  string          `json:"payment_status" db:"payment_status"`
	PaidAt         *time.Time      `json:"paid_at" db:"paid_at"`
	CreatedAt      time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at" db:"updated_at"`
	// Computed fields (populated by JOIN queries)
	PelangganName  string `json:"pelanggan_name,omitempty" db:"pelanggan_name"`
	PelangganPhone string `json:"pelanggan_phone,omitempty" db:"pelanggan_phone"`
	PelangganAddr  string `json:"pelanggan_address,omitempty" db:"pelanggan_address"`
}

// OrderItem represents a single line item inside an order.
type OrderItem struct {
	ProductID string  `json:"product_id"`
	Name      string  `json:"nama"`
	Qty       float64 `json:"qty"`
	Unit      string  `json:"satuan"`
	Price     float64 `json:"harga"`
	Subtotal  float64 `json:"subtotal"`
}
