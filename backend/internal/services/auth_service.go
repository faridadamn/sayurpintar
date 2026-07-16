package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/config"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
)

const tokenBlacklistPrefix = "token:blacklist:"

// SendOTPResponse is the response returned after sending an OTP.
type SendOTPResponse struct {
	Phone     string        `json:"phone"`
	ExpiresIn time.Duration `json:"expires_in"`
	Cooldown  time.Duration `json:"cooldown,omitempty"`
}

// AuthResponse is the response returned after successful OTP verification.
type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int64        `json:"expires_in"`
	User         *models.User `json:"user"`
	NeedsRole    bool         `json:"needs_role"`
}

// UpdateProfileRequest holds the fields allowed for profile updates.
type UpdateProfileRequest struct {
	Name      string `json:"name" validate:"omitempty,min=2,max=100"`
	Address   string `json:"address" validate:"omitempty,max=500"`
	AvatarURL string `json:"avatar_url" validate:"omitempty,url"`
}

// AuthService handles authentication business logic.
type AuthService struct {
	userRepo   repository.UserRepository
	otpService *OTPService
	jwtService *JWTService
	notifDisp  *NotificationDispatcher
	redis      *redis.Client
}

// NewAuthService creates a new auth service.
func NewAuthService(
	userRepo repository.UserRepository,
	otpService *OTPService,
	jwtService *JWTService,
	notifDisp *NotificationDispatcher,
	redisClient *redis.Client,
	cfg *config.Config,
) *AuthService {
	return &AuthService{
		userRepo:   userRepo,
		otpService: otpService,
		jwtService: jwtService,
		notifDisp:  notifDisp,
		redis:      redisClient,
	}
}

// SendOTP generates and sends an OTP to the given phone number.
// Creates a new user if one doesn't exist. Returns cooldown if recently sent.
func (s *AuthService) SendOTP(ctx context.Context, phone string) (*SendOTPResponse, error) {
	// Check cooldown
	cooldown, err := s.otpService.ResendCooldown(ctx, phone)
	if err != nil {
		return nil, fmt.Errorf("check cooldown: %w", err)
	}
	if cooldown > 0 {
		return &SendOTPResponse{
			Phone:     phone,
			ExpiresIn: s.otpService.config.OTP.Expiry,
			Cooldown:  cooldown,
		}, nil
	}

	// Generate OTP
	_, err = s.otpService.GenerateOTP(ctx, phone)
	if err != nil {
		return nil, fmt.Errorf("generate otp: %w", err)
	}

	// Create user if not exists
	_, err = s.userRepo.GetByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, repository.ErrUserNotFound) {
			newUser := &models.User{
				Phone:      phone,
				Name:       "",
				Role:       "",
				IsVerified: false,
			}
			if createErr := s.userRepo.Create(ctx, newUser); createErr != nil {
				return nil, fmt.Errorf("create user: %w", createErr)
			}
		} else {
			return nil, fmt.Errorf("get user: %w", err)
		}
	}

	expiry := s.otpService.config.OTP.Expiry
	if expiry <= 0 {
		expiry = defaultOTPExpiry
	}

	return &SendOTPResponse{
		Phone:     phone,
		ExpiresIn: expiry,
	}, nil
}

// VerifyOTP verifies the OTP and returns JWT tokens.
// If the user has no role set, NeedsRole is true in the response.
func (s *AuthService) VerifyOTP(ctx context.Context, phone string, otp string) (*AuthResponse, error) {
	valid, err := s.otpService.VerifyOTP(ctx, phone, otp)
	if err != nil {
		return nil, fmt.Errorf("verify otp: %w", err)
	}
	if !valid {
		return nil, fmt.Errorf("invalid OTP")
	}

	// Get user
	user, err := s.userRepo.GetByPhone(ctx, phone)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}

	// Mark as verified
	if !user.IsVerified {
		if err := s.userRepo.SetVerified(ctx, user.ID); err != nil {
			return nil, fmt.Errorf("set verified: %w", err)
		}
		user.IsVerified = true
	}

	// Update last login
	_ = s.userRepo.UpdateLastLogin(ctx, user.ID)

	// Generate tokens
	tokens, err := s.jwtService.GenerateTokenPair(user)
	if err != nil {
		return nil, fmt.Errorf("generate jwt: %w", err)
	}

	return &AuthResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		ExpiresIn:    tokens.ExpiresIn,
		User:         user,
		NeedsRole:    user.Role == "",
	}, nil
}

// SetRole sets the user's role. Only allowed if the user has no role yet.
func (s *AuthService) SetRole(ctx context.Context, userID string, role string) error {
	roleVal := models.UserRole(role)
	if roleVal != models.RolePedagang && roleVal != models.RolePelanggan {
		return fmt.Errorf("invalid role: must be 'pedagang' or 'pelanggan'")
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return fmt.Errorf("get user: %w", err)
	}

	if user.Role != "" {
		return fmt.Errorf("role already set")
	}

	user.Role = role
	return s.userRepo.Update(ctx, user)
}

// RefreshToken validates a refresh token and issues a new access token.
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*TokenPair, error) {
	// Check if token is blacklisted
	blacklistKey := tokenBlacklistPrefix + refreshToken
	exists, err := s.redis.Exists(ctx, blacklistKey).Result()
	if err != nil {
		return nil, fmt.Errorf("check token blacklist: %w", err)
	}
	if exists > 0 {
		return nil, fmt.Errorf("refresh token has been revoked")
	}

	// Validate the refresh token
	claims, err := s.jwtService.ValidateToken(refreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token: %w", err)
	}

	// Get user
	user, err := s.userRepo.GetByID(ctx, claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}

	// Generate new tokens
	return s.jwtService.GenerateTokenPair(user)
}

// GetProfile returns the user profile by ID.
func (s *AuthService) GetProfile(ctx context.Context, userID string) (*models.User, error) {
	return s.userRepo.GetByID(ctx, userID)
}

// UpdateProfile updates user profile fields.
func (s *AuthService) UpdateProfile(ctx context.Context, userID string, req UpdateProfileRequest) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}

	name := user.Name
	if req.Name != "" {
		name = req.Name
	}

	address := ""
	if user.Address != nil {
		address = *user.Address
	}
	if req.Address != "" {
		address = req.Address
	}

	avatarURL := ""
	if user.AvatarURL != nil {
		avatarURL = *user.AvatarURL
	}
	if req.AvatarURL != "" {
		avatarURL = req.AvatarURL
	}

	if err := s.userRepo.UpdateProfile(ctx, userID, name, address, avatarURL); err != nil {
		return nil, fmt.Errorf("update profile: %w", err)
	}

	// Re-fetch to get updated state
	return s.userRepo.GetByID(ctx, userID)
}

// Logout adds the access token to the Redis blacklist.
func (s *AuthService) Logout(ctx context.Context, accessToken string, expiresAt time.Time) error {
	blacklistKey := tokenBlacklistPrefix + accessToken
	ttl := time.Until(expiresAt)
	if ttl <= 0 {
		return nil
	}
	return s.redis.Set(ctx, blacklistKey, "1", ttl).Err()
}

// IsTokenBlacklisted checks if a token has been blacklisted.
func (s *AuthService) IsTokenBlacklisted(ctx context.Context, accessToken string) (bool, error) {
	blacklistKey := tokenBlacklistPrefix + accessToken
	exists, err := s.redis.Exists(ctx, blacklistKey).Result()
	if err != nil {
		return false, fmt.Errorf("check blacklist: %w", err)
	}
	return exists > 0, nil
}
