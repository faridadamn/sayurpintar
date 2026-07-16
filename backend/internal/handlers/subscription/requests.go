package subscription

import "encoding/json"

// CreatePackageRequest is the request body for POST /subscriptions/packages.
type CreatePackageRequest struct {
	Name           string          `json:"name" validate:"required,min=1,max=100"`
	Description    string          `json:"description"`
	Items          json.RawMessage `json:"items" validate:"required"`
	Price          float64         `json:"price" validate:"required,gt=0"`
	Frequency      string          `json:"frequency" validate:"required,oneof=daily weekly biweekly"`
	DeliveryDays   []int           `json:"delivery_days" validate:"required,min=1,dive,gte=0,lte=6"`
	MaxSubscribers int             `json:"max_subscribers" validate:"gte=0"`
}

// UpdatePackageRequest is the request body for PUT /subscriptions/packages/:id.
type UpdatePackageRequest struct {
	Name           string          `json:"name" validate:"omitempty,min=1,max=100"`
	Description    *string         `json:"description"`
	Items          json.RawMessage `json:"items"`
	Price          float64         `json:"price" validate:"gte=0"`
	Frequency      string          `json:"frequency" validate:"omitempty,oneof=daily weekly biweekly"`
	DeliveryDays   []int           `json:"delivery_days" validate:"omitempty,min=1,dive,gte=0,lte=6"`
	MaxSubscribers int             `json:"max_subscribers" validate:"gte=0"`
	IsActive       *bool           `json:"is_active"`
}

// SubscribeRequest is the request body for POST /subscriptions/subscribe.
type SubscribeRequest struct {
	PackageID        string `json:"package_id" validate:"required,uuid"`
	PaymentMethod    string `json:"payment_method" validate:"omitempty,oneof=cash qris transfer"`
	PaymentFrequency string `json:"payment_frequency" validate:"omitempty,oneof=per_delivery weekly monthly"`
	StartDate        string `json:"start_date" validate:"required"`
	EndDate          string `json:"end_date"`
}

// PauseSubscriptionRequest is the request body for PUT /subscriptions/:id/pause.
type PauseSubscriptionRequest struct {
	Reason string `json:"reason" validate:"required,min=1,max=500"`
}

// CancelSubscriptionRequest is the request body for DELETE /subscriptions/:id.
type CancelSubscriptionRequest struct {
	Reason string `json:"reason" validate:"required,min=1,max=500"`
}

// ModifyDeliveryRequest is the request body for POST /subscriptions/:id/modify.
type ModifyDeliveryRequest struct {
	DeliveryDate string          `json:"delivery_date" validate:"required"`
	Items        json.RawMessage `json:"items"`
	SkipDelivery bool            `json:"skip_delivery"`
	Reason       string          `json:"reason" validate:"max=500"`
}
