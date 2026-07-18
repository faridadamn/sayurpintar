package models

import (
	"time"

	"github.com/google/uuid"
)

// TransactionType represents the kind of financial transaction.
type TransactionType string

const (
	TxnTypeSale     TransactionType = "sale"
	TxnTypePurchase TransactionType = "purchase"
	TxnTypeExpense  TransactionType = "expense"
	TxnTypePayment  TransactionType = "payment"
	TxnTypeRefund   TransactionType = "refund"
)

// PaymentMethod represents how a payment was made.
type PaymentMethod string

const (
	PayMethodCash     PaymentMethod = "cash"
	PayMethodQRIS     PaymentMethod = "qris"
	PayMethodTransfer PaymentMethod = "transfer"
	PayMethodEWallet  PaymentMethod = "ewallet"
)

// TransactionStatus represents the lifecycle state of a transaction.
type TransactionStatus string

const (
	TxnStatusCompleted TransactionStatus = "completed"
	TxnStatusPending   TransactionStatus = "pending"
	TxnStatusFailed    TransactionStatus = "failed"
	TxnStatusRefunded  TransactionStatus = "refunded"
)

// Transaction represents a financial transaction in the system.
type Transaction struct {
	ID                   uuid.UUID         `json:"id" db:"id"`
	PedagangID           uuid.UUID         `json:"pedagang_id" db:"pedagang_id"`
	PelangganID          *uuid.UUID        `json:"pelanggan_id,omitempty" db:"pelanggan_id"`
	OrderID              *uuid.UUID        `json:"order_id,omitempty" db:"order_id"`
	DebtID               *uuid.UUID        `json:"debt_id,omitempty" db:"debt_id"`
	Type                 TransactionType   `json:"type" db:"type"`
	Amount               float64           `json:"amount" db:"amount"`
	PaymentMethod        PaymentMethod     `json:"payment_method" db:"payment_method"`
	PaymentGateway       *string           `json:"payment_gateway,omitempty" db:"payment_gateway"`
	GatewayTransactionID *string           `json:"gateway_transaction_id,omitempty" db:"gateway_transaction_id"`
	GatewayStatus        *string           `json:"gateway_status,omitempty" db:"gateway_status"`
	Status               TransactionStatus `json:"status" db:"status"`
	Notes                *string           `json:"notes,omitempty" db:"notes"`
	CreatedAt            time.Time         `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time         `json:"updated_at" db:"updated_at"`
}
