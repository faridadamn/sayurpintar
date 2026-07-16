package models

import "time"

// GroupOrder represents a group buying order initiated by a pedagang.
type GroupOrder struct {
	ID            string    `json:"id" db:"id"`
	OrganizerID   string    `json:"organizer_id" db:"organizer_id"`
	SupplierID    string    `json:"supplier_id" db:"supplier_id"`
	ProductID     string    `json:"product_id" db:"product_id"`
	ProductName   string    `json:"product_name" db:"product_name"`
	TargetQty     float64   `json:"target_qty" db:"target_qty"`
	CurrentQty    float64   `json:"current_qty" db:"current_qty"`
	GroupPrice    float64   `json:"group_price" db:"group_price"`
	RegularPrice  float64   `json:"regular_price" db:"regular_price"`
	Unit          string    `json:"unit" db:"unit"`
	Deadline      time.Time `json:"deadline" db:"deadline"`
	DeliveryDate  string    `json:"delivery_date" db:"delivery_date"`
	DeliveryPoint string    `json:"delivery_point" db:"delivery_point"`
	Status        string    `json:"status" db:"status"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
	// Computed fields (not stored, populated by queries)
	OrganizerName    string  `json:"organizer_name,omitempty"`
	Savings          float64 `json:"savings,omitempty"`
	ParticipantCount int     `json:"participant_count,omitempty"`
}

// GroupParticipant represents a pedagang who joined a group order.
type GroupParticipant struct {
	ID           string    `json:"id" db:"id"`
	GroupOrderID string    `json:"group_order_id" db:"group_order_id"`
	PedagangID   string    `json:"pedagang_id" db:"pedagang_id"`
	Qty          float64   `json:"qty" db:"qty"`
	TotalPrice   float64   `json:"total_price" db:"total_price"`
	Status       string    `json:"status" db:"status"`
	JoinedAt     time.Time `json:"joined_at" db:"joined_at"`
	// Computed fields
	PedagangName string `json:"pedagang_name,omitempty"`
}

// Supplier represents a wholesale supplier for group buying.
type Supplier struct {
	ID        string    `json:"id" db:"id"`
	Name      string    `json:"name" db:"name"`
	Address   string    `json:"address" db:"address"`
	Phone     string    `json:"phone" db:"phone"`
	Location  *Point    `json:"location" db:"location"`
	Rating    float64   `json:"rating" db:"rating"`
	IsActive  bool      `json:"is_active" db:"is_active"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// GroupOrderStatus constants.
const (
	GroupStatusOpen      = "open"
	GroupStatusFull      = "full"
	GroupStatusOrdered   = "ordered"
	GroupStatusDelivered = "delivered"
	GroupStatusCancelled = "cancelled"
)

// GroupParticipantStatus constants.
const (
	ParticipantJoined   = "joined"
	ParticipantPaid     = "paid"
	ParticipantReceived = "received"
	ParticipantCanceled = "cancelled"
)
