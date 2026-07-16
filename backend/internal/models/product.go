package models

import (
	"time"

	"github.com/google/uuid"
)

// Product represents a catalog item (vegetable, fruit, spice, etc.).
type Product struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Category    string    `json:"category" db:"category"`
	DefaultUnit string    `json:"default_unit" db:"default_unit"`
	ImageURL    *string   `json:"image_url,omitempty" db:"image_url"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// Product categories used across the system.
const (
	CategorySayurHijau = "sayur_hijau"
	CategorySayurAkar  = "sayur_akar"
	CategorySayurBuah  = "sayur_buah"
	CategoryBumbu      = "bumbu"
	CategoryBuah       = "buah"
	CategoryLainnya    = "lainnya"
)

// AllCategories returns every valid product category.
func AllCategories() []string {
	return []string{
		CategorySayurHijau,
		CategorySayurAkar,
		CategorySayurBuah,
		CategoryBumbu,
		CategoryBuah,
		CategoryLainnya,
	}
}
