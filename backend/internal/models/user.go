package models

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/go-playground/validator/v10"
)

// UserRole represents a valid user role in the system.
type UserRole string

const (
	RolePedagang  UserRole = "pedagang"
	RolePelanggan UserRole = "pelanggan"
	RoleAdmin     UserRole = "admin"
)

// ValidRoles enumerates all accepted role values for validation.
var ValidRoles = []string{string(RolePedagang), string(RolePelanggan), string(RoleAdmin)}

// Point represents a geographic coordinate.
type Point struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// Value implements the driver.Valuer interface for PostGIS geography storage.
func (p Point) Value() (interface{}, error) {
	// WKT format for PostGIS POINT(lng lat) — note: longitude first, then latitude
	return fmt.Sprintf("SRID=4326;POINT(%f %f)", p.Longitude, p.Latitude), nil
}

// User is the core user model mapping to the users table.
type User struct {
	ID          string     `json:"id" db:"id" validate:"required,uuid"`
	Phone       string     `json:"phone" db:"phone" validate:"required,e164"`
	Name        string     `json:"name" db:"name" validate:"required,min=1,max=100"`
	Role        string     `json:"role" db:"role" validate:"required,oneof=pedagang pelanggan admin"`
	AvatarURL   *string    `json:"avatar_url,omitempty" db:"avatar_url" validate:"omitempty,url"`
	Address     *string    `json:"address,omitempty" db:"address" validate:"omitempty,max=500"`
	Location    *Point     `json:"location,omitempty" db:"location"`
	Area        *string    `json:"area,omitempty" db:"area" validate:"omitempty,max=50"`
	IsVerified  bool       `json:"is_verified" db:"is_verified"`
	OTPCode     *string    `json:"-" db:"otp_code"`
	OTPExpireAt *time.Time `json:"-" db:"otp_expires_at"`
	LastLoginAt *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

// Validate runs struct validation on the User.
func (u *User) Validate() error {
	validate := validator.New()
	return validate.Struct(u)
}

// HasRole returns true if the user has the given role.
func (u *User) HasRole(role string) bool {
	return u.Role == role
}

// IsPedagang returns true if the user is a vendor (pedagang).
func (u *User) IsPedagang() bool {
	return u.Role == string(RolePedagang)
}

// IsPelanggan returns true if the user is a customer (pelanggan).
func (u *User) IsPelanggan() bool {
	return u.Role == string(RolePelanggan)
}

// IsAdmin returns true if the user is an admin.
func (u *User) IsAdmin() bool {
	return u.Role == string(RoleAdmin)
}

// DisplayName returns the user's name, or a fallback if empty.
func (u *User) DisplayName() string {
	if u.Name != "" {
		return u.Name
	}
	return "Anonymous"
}

// ToSafeJSON returns a JSON representation excluding sensitive fields (OTP).
func (u *User) ToSafeJSON() ([]byte, error) {
	safe := struct {
		ID          string     `json:"id"`
		Phone       string     `json:"phone"`
		Name        string     `json:"name"`
		Role        string     `json:"role"`
		AvatarURL   *string    `json:"avatar_url,omitempty"`
		Address     *string    `json:"address,omitempty"`
		Location    *Point     `json:"location,omitempty"`
		Area        *string    `json:"area,omitempty"`
		IsVerified  bool       `json:"is_verified"`
		LastLoginAt *time.Time `json:"last_login_at,omitempty"`
		CreatedAt   time.Time  `json:"created_at"`
		UpdatedAt   time.Time  `json:"updated_at"`
	}{
		ID:          u.ID,
		Phone:       u.Phone,
		Name:        u.Name,
		Role:        u.Role,
		AvatarURL:   u.AvatarURL,
		Address:     u.Address,
		Location:    u.Location,
		Area:        u.Area,
		IsVerified:  u.IsVerified,
		LastLoginAt: u.LastLoginAt,
		CreatedAt:   u.CreatedAt,
		UpdatedAt:   u.UpdatedAt,
	}
	return json.Marshal(safe)
}

// ScanPoint is a helper for scanning PostGIS POINT values from the database.
// The scanner receives a string like "POINT(lng lat)" and populates the Point struct.
func ScanPoint(src interface{}) (*Point, error) {
	if src == nil {
		return nil, nil
	}

	var s string
	switch v := src.(type) {
	case string:
		s = v
	case []byte:
		s = string(v)
	default:
		return nil, fmt.Errorf("unsupported type for point scan: %T", src)
	}

	var lat, lng float64
	// PostGIS returns WKT: SRID=4326;POINT(lng lat)
	if _, err := fmt.Sscanf(s, "SRID=4326;POINT(%f %f)", &lng, &lat); err != nil {
		// Try plain POINT(lng lat) format
		if _, err2 := fmt.Sscanf(s, "POINT(%f %f)", &lng, &lat); err2 != nil {
			return nil, fmt.Errorf("parse point %q: %w", s, err2)
		}
	}

	return &Point{Latitude: lat, Longitude: lng}, nil
}
