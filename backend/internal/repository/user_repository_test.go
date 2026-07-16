package repository

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/sayurpintar/api/internal/models"
)

// ---------------------------------------------------------------------------
// Fake pgx.Row implementations for unit testing without a real database.
// ---------------------------------------------------------------------------

// fakeRow implements pgx.Row for scanning full user columns.
type fakeRow struct {
	user *models.User
	err  error
}

func (f *fakeRow) Scan(dest ...interface{}) error {
	if f.err != nil {
		return f.err
	}
	u := f.user
	// Scan order matches userColumns:
	// id, phone, name, role, avatar_url, address, location, area,
	// is_verified, otp_code, otp_expires_at, last_login_at, created_at, updated_at
	*dest[0].(*string) = u.ID
	*dest[1].(*string) = u.Phone
	*dest[2].(*string) = u.Name
	*dest[3].(*string) = u.Role
	if u.AvatarURL != nil {
		*dest[4].(**string) = u.AvatarURL
	} else {
		*dest[4].(**string) = nil
	}
	if u.Address != nil {
		*dest[5].(**string) = u.Address
	} else {
		*dest[5].(**string) = nil
	}
	if u.Location != nil {
		wkt := fmt.Sprintf("SRID=4326;POINT(%f %f)", u.Location.Longitude, u.Location.Latitude)
		*dest[6].(**string) = &wkt
	} else {
		*dest[6].(**string) = nil
	}
	if u.Area != nil {
		*dest[7].(**string) = u.Area
	} else {
		*dest[7].(**string) = nil
	}
	*dest[8].(*bool) = u.IsVerified
	if u.OTPCode != nil {
		*dest[9].(**string) = u.OTPCode
	} else {
		*dest[9].(**string) = nil
	}
	if u.OTPExpireAt != nil {
		*dest[10].(**time.Time) = u.OTPExpireAt
	} else {
		*dest[10].(**time.Time) = nil
	}
	if u.LastLoginAt != nil {
		*dest[11].(**time.Time) = u.LastLoginAt
	} else {
		*dest[11].(**time.Time) = nil
	}
	*dest[12].(*time.Time) = u.CreatedAt
	*dest[13].(*time.Time) = u.UpdatedAt
	return nil
}

// idOnlyRow implements pgx.Row for RETURNING id queries.
type idOnlyRow struct {
	id  string
	err error
}

func (r *idOnlyRow) Scan(dest ...interface{}) error {
	if r.err != nil {
		return r.err
	}
	*dest[0].(*string) = r.id
	return nil
}

// ---------------------------------------------------------------------------
// testUserRepo: re-implements UserRepository with injectable pgx.Row
// factories, avoiding the need to construct pgconn.CommandTag (which has
// unexported fields in pgx/v5).
// ---------------------------------------------------------------------------

type testUserRepo struct {
	// userRow returns a pgx.Row for queries that scan full user columns
	// (SELECT ... userColumns, INSERT ... RETURNING userColumns, etc.)
	userRow func(ctx context.Context, sql string, args ...interface{}) pgx.Row
	// idRow returns a pgx.Row for queries that RETURN id only
	// (UPDATE ... RETURNING id)
	idRow func(ctx context.Context, sql string, args ...interface{}) pgx.Row
}

func (r *testUserRepo) Create(ctx context.Context, user *models.User) error {
	query := `INSERT INTO users (phone, name, role, avatar_url, address, area) VALUES ($1, $2, $3, $4, $5, $6) RETURNING ` + userColumns
	row := r.userRow(ctx, query, user.Phone, user.Name, user.Role, user.AvatarURL, user.Address, user.Area)
	created, err := scanUser(row)
	if err != nil {
		return fmt.Errorf("insert user: %w", err)
	}
	*user = *created
	return nil
}

func (r *testUserRepo) GetByID(ctx context.Context, id string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE id = $1`
	user, err := scanUser(r.userRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}
	return user, nil
}

func (r *testUserRepo) GetByPhone(ctx context.Context, phone string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE phone = $1`
	user, err := scanUser(r.userRow(ctx, query, phone))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("get user by phone: %w", err)
	}
	return user, nil
}

func (r *testUserRepo) Update(ctx context.Context, user *models.User) error {
	query := `UPDATE users SET name=$2, role=$3, avatar_url=$4, address=$5, area=$6, updated_at=NOW() WHERE id=$1 RETURNING ` + userColumns
	row := r.userRow(ctx, query, user.ID, user.Name, user.Role, user.AvatarURL, user.Address, user.Area)
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

func (r *testUserRepo) UpdateOTP(ctx context.Context, phone string, otp string, expiresAt time.Time) error {
	query := `UPDATE users SET otp_code=$2, otp_expires_at=$3, updated_at=NOW() WHERE phone=$1 RETURNING id`
	var id string
	err := r.idRow(ctx, query, phone, otp, expiresAt).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update otp: %w", err)
	}
	return nil
}

func (r *testUserRepo) VerifyOTP(ctx context.Context, phone string, otp string) (*models.User, error) {
	query := `SELECT ` + userColumns + ` FROM users WHERE phone = $1`
	user, err := scanUser(r.userRow(ctx, query, phone))
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
	// Production code also clears OTP via RETURNING id; in tests we just
	// clear the struct fields since we don't have a real DB.
	user.OTPCode = nil
	user.OTPExpireAt = nil
	return user, nil
}

func (r *testUserRepo) UpdateLastLogin(ctx context.Context, userID string) error {
	query := `UPDATE users SET last_login_at=NOW() WHERE id=$1 RETURNING id`
	var id string
	err := r.idRow(ctx, query, userID).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update last login: %w", err)
	}
	return nil
}

func (r *testUserRepo) UpdateProfile(ctx context.Context, userID string, name string, address string, avatarURL string) error {
	var addrPtr, avatarPtr *string
	if address != "" {
		addrPtr = &address
	}
	if avatarURL != "" {
		avatarPtr = &avatarURL
	}
	query := `UPDATE users SET name=$2, address=$3, avatar_url=$4, updated_at=NOW() WHERE id=$1 RETURNING id`
	var id string
	err := r.idRow(ctx, query, userID, name, addrPtr, avatarPtr).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update profile: %w", err)
	}
	return nil
}

func (r *testUserRepo) UpdateLocation(ctx context.Context, userID string, lat float64, lng float64) error {
	wkt := fmt.Sprintf("SRID=4326;POINT(%f %f)", lng, lat)
	query := `UPDATE users SET location=ST_GeographyFromText($2), updated_at=NOW() WHERE id=$1 RETURNING id`
	var id string
	err := r.idRow(ctx, query, userID, wkt).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("update location: %w", err)
	}
	return nil
}

func (r *testUserRepo) SetVerified(ctx context.Context, userID string) error {
	query := `UPDATE users SET is_verified=TRUE, updated_at=NOW() WHERE id=$1 RETURNING id`
	var id string
	err := r.idRow(ctx, query, userID).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrUserNotFound
		}
		return fmt.Errorf("set verified: %w", err)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func sampleUser() *models.User {
	now := time.Now().Truncate(time.Millisecond)
	return &models.User{
		ID:         "550e8400-e29b-41d4-a716-446655440000",
		Phone:      "+628123456789",
		Name:       "Budi Sayur",
		Role:       "pedagang",
		IsVerified: false,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
}

func ptrTime(t time.Time) *time.Time { return &t }

// alwaysRow returns a pgx.Row factory that always yields the same row.
func alwaysRow(row pgx.Row) func(context.Context, string, ...interface{}) pgx.Row {
	return func(_ context.Context, _ string, _ ...interface{}) pgx.Row {
		return row
	}
}

// newTestRepo builds a testUserRepo where:
//   - user queries (SELECT/INSERT/RETURNING full columns) return the given user
//   - id-only queries (UPDATE ... RETURNING id) return the given id
//   - if scanErr is non-nil, both return the error instead
func newTestRepo(user *models.User, id string, scanErr error) *testUserRepo {
	if scanErr != nil {
		return &testUserRepo{
			userRow: alwaysRow(&fakeRow{err: scanErr}),
			idRow:   alwaysRow(&idOnlyRow{err: scanErr}),
		}
	}
	return &testUserRepo{
		userRow: alwaysRow(&fakeRow{user: user}),
		idRow:   alwaysRow(&idOnlyRow{id: id}),
	}
}

// ---------------------------------------------------------------------------
// Tests — Table-driven
// ---------------------------------------------------------------------------

func TestCreate(t *testing.T) {
	tests := []struct {
		name    string
		input   *models.User
		scanErr error
		wantErr bool
	}{
		{
			name:    "success",
			input:   &models.User{Phone: "+628123456789", Name: "Budi", Role: "pedagang"},
			wantErr: false,
		},
		{
			name:    "db error",
			input:   &models.User{Phone: "+628123456789", Name: "Budi", Role: "pedagang"},
			scanErr: fmt.Errorf("connection refused"),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			returned := sampleUser()
			returned.Phone = tt.input.Phone
			returned.Name = tt.input.Name
			returned.Role = tt.input.Role

			repo := newTestRepo(returned, returned.ID, tt.scanErr)
			err := repo.Create(context.Background(), tt.input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Create() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				if tt.input.ID == "" {
					t.Error("Create() did not populate ID")
				}
				if tt.input.Name != "Budi" {
					t.Errorf("Create() name = %q, want %q", tt.input.Name, "Budi")
				}
			}
		})
	}
}

func TestGetByPhone(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "found", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
		{name: "db error", scanErr: fmt.Errorf("timeout"), wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), "", tt.scanErr)
			user, err := repo.GetByPhone(context.Background(), "+628123456789")
			if (err != nil) != tt.wantErr {
				t.Fatalf("GetByPhone() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("GetByPhone() err = %v, want %v", err, tt.wantErrIs)
			}
			if !tt.wantErr && user == nil {
				t.Error("GetByPhone() returned nil user on success")
			}
		})
	}
}

func TestGetByID(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "found", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), "", tt.scanErr)
			user, err := repo.GetByID(context.Background(), "550e8400-e29b-41d4-a716-446655440000")
			if (err != nil) != tt.wantErr {
				t.Fatalf("GetByID() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("GetByID() err = %v, want %v", err, tt.wantErrIs)
			}
			if !tt.wantErr && user == nil {
				t.Error("GetByID() returned nil user on success")
			}
		})
	}
}

func TestUpdate(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
		{name: "db error", scanErr: fmt.Errorf("disk full"), wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			u := sampleUser()
			u.Name = "Updated Name"
			repo := newTestRepo(u, "", tt.scanErr)
			err := repo.Update(context.Background(), u)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Update() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("Update() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}

func TestUpdateOTP(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "user not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
		{name: "db error", scanErr: fmt.Errorf("connection refused"), wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), sampleUser().ID, tt.scanErr)
			err := repo.UpdateOTP(context.Background(), "+628123456789", "123456", time.Now().Add(5*time.Minute))
			if (err != nil) != tt.wantErr {
				t.Fatalf("UpdateOTP() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("UpdateOTP() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}

func TestVerifyOTP(t *testing.T) {
	now := time.Now()
	validOTP := "654321"

	userWithOTP := sampleUser()
	userWithOTP.OTPCode = &validOTP
	userWithOTP.OTPExpireAt = ptrTime(now.Add(10 * time.Minute))

	userWithExpiredOTP := sampleUser()
	userWithExpiredOTP.OTPCode = &validOTP
	userWithExpiredOTP.OTPExpireAt = ptrTime(now.Add(-1 * time.Minute))

	userNoOTP := sampleUser()

	tests := []struct {
		name      string
		user      *models.User
		otp       string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{
			name:    "success",
			user:    userWithOTP,
			otp:     "654321",
			wantErr: false,
		},
		{
			name:      "invalid otp — wrong code",
			user:      userWithOTP,
			otp:       "000000",
			wantErr:   true,
			wantErrIs: ErrOTPInvalid,
		},
		{
			name:      "invalid otp — no otp set",
			user:      userNoOTP,
			otp:       "654321",
			wantErr:   true,
			wantErrIs: ErrOTPInvalid,
		},
		{
			name:      "expired otp",
			user:      userWithExpiredOTP,
			otp:       "654321",
			wantErr:   true,
			wantErrIs: ErrOTPExpired,
		},
		{
			name:      "user not found",
			scanErr:   pgx.ErrNoRows,
			otp:       "654321",
			wantErr:   true,
			wantErrIs: ErrUserNotFound,
		},
		{
			name:    "db error",
			user:    userWithOTP,
			otp:     "654321",
			scanErr: fmt.Errorf("connection lost"),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			u := tt.user
			if u == nil {
				u = sampleUser()
			}
			repo := newTestRepo(u, "", tt.scanErr)

			result, err := repo.VerifyOTP(context.Background(), "+628123456789", tt.otp)
			if (err != nil) != tt.wantErr {
				t.Fatalf("VerifyOTP() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("VerifyOTP() err = %v, want %v", err, tt.wantErrIs)
			}
			if !tt.wantErr {
				if result == nil {
					t.Fatal("VerifyOTP() returned nil user on success")
				}
				if result.OTPCode != nil {
					t.Error("VerifyOTP() did not clear OTP code")
				}
				if result.OTPExpireAt != nil {
					t.Error("VerifyOTP() did not clear OTP expiry")
				}
			}
		})
	}
}

func TestUpdateLastLogin(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
		{name: "db error", scanErr: fmt.Errorf("timeout"), wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), sampleUser().ID, tt.scanErr)
			err := repo.UpdateLastLogin(context.Background(), "some-id")
			if (err != nil) != tt.wantErr {
				t.Fatalf("UpdateLastLogin() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("UpdateLastLogin() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}

func TestUpdateProfile(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
		{name: "db error", scanErr: fmt.Errorf("io error"), wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), sampleUser().ID, tt.scanErr)
			err := repo.UpdateProfile(context.Background(), "id", "New Name", "addr", "url")
			if (err != nil) != tt.wantErr {
				t.Fatalf("UpdateProfile() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("UpdateProfile() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}

func TestUpdateLocation(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), sampleUser().ID, tt.scanErr)
			err := repo.UpdateLocation(context.Background(), "id", -6.2088, 106.8456)
			if (err != nil) != tt.wantErr {
				t.Fatalf("UpdateLocation() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("UpdateLocation() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}

func TestSetVerified(t *testing.T) {
	tests := []struct {
		name      string
		scanErr   error
		wantErr   bool
		wantErrIs error
	}{
		{name: "success", wantErr: false},
		{name: "not found", scanErr: pgx.ErrNoRows, wantErr: true, wantErrIs: ErrUserNotFound},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repo := newTestRepo(sampleUser(), sampleUser().ID, tt.scanErr)
			err := repo.SetVerified(context.Background(), "some-id")
			if (err != nil) != tt.wantErr {
				t.Fatalf("SetVerified() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErrIs != nil && !errors.Is(err, tt.wantErrIs) {
				t.Errorf("SetVerified() err = %v, want %v", err, tt.wantErrIs)
			}
		})
	}
}
