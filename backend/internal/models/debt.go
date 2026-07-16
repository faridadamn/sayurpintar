package models

import (
	"time"

	"github.com/google/uuid"
)

// DebtStatus represents the lifecycle state of a debt (piutang).
type DebtStatus string

const (
	DebtStatusOutstanding DebtStatus = "outstanding"
	DebtStatusPartial     DebtStatus = "partial"
	DebtStatusSettled     DebtStatus = "settled"
	DebtStatusWrittenOff  DebtStatus = "written_off"
)

// Debt represents a piutang (receivable) from a pelanggan to a pedagang.
type Debt struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	PedagangID     uuid.UUID  `json:"pedagang_id" db:"pedagang_id"`
	PelangganID    uuid.UUID  `json:"pelanggan_id" db:"pelanggan_id"`
	OrderID        *uuid.UUID `json:"order_id,omitempty" db:"order_id"`
	Amount         float64    `json:"amount" db:"amount"`
	AmountPaid     float64    `json:"amount_paid" db:"amount_paid"`
	Remaining      float64    `json:"remaining" db:"remaining"`
	Status         DebtStatus `json:"status" db:"status"`
	ReminderCount  int        `json:"reminder_count" db:"reminder_count"`
	LastReminderAt *time.Time `json:"last_reminder_at,omitempty" db:"last_reminder_at"`
	DueDate        *time.Time `json:"due_date,omitempty" db:"due_date"`
	SettledAt      *time.Time `json:"settled_at,omitempty" db:"settled_at"`
	WriteOffReason *string    `json:"write_off_reason,omitempty" db:"write_off_reason"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
	// Computed fields (populated by JOIN queries)
	PelangganName  string `json:"pelanggan_name,omitempty" db:"pelanggan_name"`
	PelangganPhone string `json:"pelanggan_phone,omitempty" db:"pelanggan_phone"`
}
