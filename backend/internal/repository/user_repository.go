package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// UserRepository defines the data access contract for users.
type UserRepository interface {
	Create(ctx context.Context, user *models.User) error
	GetByID(ctx context.Context, id string) (*models.User, error)
	GetByPhone(ctx context.Context, phone string) (*models.User, error)
	Update(ctx context.Context, user *models.User) error
	UpdateOTP(ctx context.Context, phone string, otp string, expiresAt time.Time) error
	VerifyOTP(ctx context.Context, phone string, otp string) (*models.User, error)
	UpdateLastLogin(ctx context.Context, userID string) error
	UpdateProfile(ctx context.Context, userID string, name string, address string, avatarURL string) error
	UpdateLocation(ctx context.Context, userID string, lat float64, lng float64) error
	SetVerified(ctx context.Context, userID string) error
}

// userRepo implements UserRepository backed by pgxpool.
type userRepo struct {
	pool *pgxpool.Pool
}

// NewUserRepository returns a new UserRepository backed by the given pool.
func NewUserRepository(pool *pgxpool.Pool) UserRepository {
	return &userRepo{pool: pool}
}

const userColumns = `
	id, phone, name, role, avatar_url, address, location, area,
	is_verified, otp_code, otp_expires_at, last_login_at, created_at, updated_at
`

// scanUser scans a row into a User struct, handling the PostGIS geography point.
func scanUser(row pgx.Row) (*models.User, error) {
	var u models.User
	var locationWKT *string // scan raw WKT string from PostGIS

	err := row.Scan(
		&u.ID,
		&u.Phone,
		&u.Name,
		&u.Role,
		&u.AvatarURL,
		&u.Address,
		&locationWKT,
		&u.Area,
		&u.IsVerified,
		&u.OTPCode,
		&u.OTPExpireAt,
		&u.LastLoginAt,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if locationWKT != nil {
		pt, err := models.ScanPoint(*locationWKT)
		if err != nil {
			return nil, fmt.Errorf("scan location: %w", err)
		}
		u.Location = pt
	}

	return &u, nil
}

// Create inserts a new user. The user.ID, CreatedAt, UpdatedAt are populated
// by the database defaults; the struct is re-scanned after insert to capture them.
func (r *userRepo) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (phone, name, role, avatar_url, address, area)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING ` + userColumns

	row := r.pool.QueryRow(ctx, query,
		user.Phone,
		user.Name,
		user.Role,
		user.AvatarURL,
		user.Address,
		user.Area,
	)

	created, err := scanUser(row)
	if err != nil {
		return fmt.Errorf("insert user: %w", err)
	}

	*user = *created
	return nil
}

// GetByID fetches a user by their UUID.
func (r *userRepo) GetByID(ctx context.Context, id string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE id = $1`

	user, err := scanUser(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}
	return user, nil
}

// GetByPhone fetches a user by phone number.
func (r *userRepo) GetByPhone(ctx context.Context, phone string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE phone = $1`

	user, err := scanUser(r.pool.QueryRow(ctx, query, phone))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by phone: %w", err)
	}
	return user, nil
}

// Update persists changes to mutable user fields (name, role, avatar, address, area).
func (r *userRepo) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET name = $2, role = $3, avatar_url = $4, address = $5,
		    area = $6, updated_at = NOW()
		WHERE id = $1
		RETURNING ` + userColumns

	row := r.pool.QueryRow(ctx, query,
		user.ID,
		user.Name,
		user.Role,
		user.AvatarURL,
		user.Address,
		user.Area,
	)

	updated, err := scanUser(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update user: %w", err)
	}

	*user = *updated
	return nil
}

// UpdateOTP sets the OTP code and expiry for the user identified by phone.
// Uses RETURNING id to verify the user exists (pgx.ErrNoRows → ErrUserNotFound).
func (r *userRepo) UpdateOTP(ctx context.Context, phone string, otp string, expiresAt time.Time) error {
	query := `
		UPDATE users
		SET otp_code = $2, otp_expires_at = $3, updated_at = NOW()
		WHERE phone = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, phone, otp, expiresAt).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update otp: %w", err)
	}
	return nil
}

// VerifyOTP validates the OTP for the given phone and returns the user.
// Returns ErrOTPInvalid if the OTP doesn't match, ErrOTPExpired if it's past expiry.
// On success the OTP fields are cleared.
func (r *userRepo) VerifyOTP(ctx context.Context, phone string, otp string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE phone = $1`

	user, err := scanUser(r.pool.QueryRow(ctx, query, phone))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("verify otp fetch: %w", err)
	}

	if user.OTPCode == nil || *user.OTPCode != otp {
		return nil, ErrOTPInvalid
	}
	if user.OTPExpireAt != nil && user.OTPExpireAt.Before(time.Now()) {
		return nil, ErrOTPExpired
	}

	// Clear OTP after successful verification
	clearQuery := `
		UPDATE users
		SET otp_code = NULL, otp_expires_at = NULL, updated_at = NOW()
		WHERE id = $1
		RETURNING id`
	var clearedID string
	if err := r.pool.QueryRow(ctx, clearQuery, user.ID).Scan(&clearedID); err != nil {
		return nil, fmt.Errorf("clear otp: %w", err)
	}

	user.OTPCode = nil
	user.OTPExpireAt = nil
	return user, nil
}

// UpdateLastLogin sets last_login_at to now for the given user.
func (r *userRepo) UpdateLastLogin(ctx context.Context, userID string) error {
	query := `
		UPDATE users SET last_login_at = NOW()
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, userID).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update last login: %w", err)
	}
	return nil
}

// UpdateProfile updates name, address, and avatar_url for the given user.
func (r *userRepo) UpdateProfile(ctx context.Context, userID string, name string, address string, avatarURL string) error {
	query := `
		UPDATE users
		SET name = $2, address = $3, avatar_url = $4, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, userID, name, strPtrOrNil(address), strPtrOrNil(avatarURL)).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update profile: %w", err)
	}
	return nil
}

// UpdateLocation sets the PostGIS geography point for the given user.
func (r *userRepo) UpdateLocation(ctx context.Context, userID string, lat float64, lng float64) error {
	pointWKT := fmt.Sprintf("SRID=4326;POINT(%f %f)", lng, lat)
	query := `
		UPDATE users
		SET location = ST_GeographyFromText($2), updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, userID, pointWKT).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update location: %w", err)
	}
	return nil
}

// SetVerified marks the user as verified.
func (r *userRepo) SetVerified(ctx context.Context, userID string) error {
	query := `
		UPDATE users SET is_verified = TRUE, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, userID).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("set verified: %w", err)
	}
	return nil
}

// strPtrOrNil returns a *string: nil for empty strings, pointer otherwise.
func strPtrOrNil(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
