package services

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/config"
)

const (
	otpKeyPrefix       = "otp:"
	otpAttemptsPrefix  = "otp:attempts:"
	otpSpamPrefix      = "otp:spam:"
	otpCooldownPrefix  = "otp:cooldown:"
	defaultOTPExpiry   = 5 * time.Minute
	defaultMaxAttempts = 5
	defaultSpamWindow  = 10 * time.Minute
	defaultSpamLimit   = 3
)

// OTPService handles OTP generation, verification, and rate limiting.
type OTPService struct {
	redis  *redis.Client
	config *config.Config
}

// NewOTPService creates a new OTP service.
func NewOTPService(redis *redis.Client, cfg *config.Config) *OTPService {
	return &OTPService{
		redis:  redis,
		config: cfg,
	}
}

// GenerateOTP creates a numeric OTP of configured length, stores it in Redis with TTL.
// Enforces anti-spam: max N OTPs per phone within a window.
func (s *OTPService) GenerateOTP(ctx context.Context, phone string) (string, error) {
	otpLen := s.config.OTP.Length
	if otpLen <= 0 {
		otpLen = 6
	}

	// Anti-spam check
	spamKey := otpSpamPrefix + phone
	spamCount, err := s.redis.Get(ctx, spamKey).Int()
	if err != nil && err != redis.Nil {
		return "", fmt.Errorf("check spam counter: %w", err)
	}

	spamLimit := defaultSpamLimit
	if spamCount >= spamLimit {
		return "", fmt.Errorf("too many OTP requests, please wait before trying again")
	}

	// Generate random numeric OTP
	otp, err := generateRandomDigits(otpLen)
	if err != nil {
		return "", fmt.Errorf("generate otp: %w", err)
	}

	// Store OTP in Redis with expiry
	otpKey := otpKeyPrefix + phone
	expiry := s.config.OTP.Expiry
	if expiry <= 0 {
		expiry = defaultOTPExpiry
	}

	if err := s.redis.Set(ctx, otpKey, otp, expiry).Err(); err != nil {
		return "", fmt.Errorf("store otp: %w", err)
	}

	// Set cooldown key
	cooldownKey := otpCooldownPrefix + phone
	cooldown := s.config.OTP.ResendCooldown
	if cooldown <= 0 {
		cooldown = 60 * time.Second
	}
	if err := s.redis.Set(ctx, cooldownKey, "1", cooldown).Err(); err != nil {
		return "", fmt.Errorf("set cooldown: %w", err)
	}

	// Increment spam counter
	pipe := s.redis.Pipeline()
	pipe.Incr(ctx, spamKey)
	pipe.Expire(ctx, spamKey, defaultSpamWindow)
	if _, err := pipe.Exec(ctx); err != nil {
		return "", fmt.Errorf("increment spam counter: %w", err)
	}

	return otp, nil
}

// VerifyOTP checks the provided OTP against the stored value.
// On success, deletes the OTP key and resets attempt counter.
// On failure, increments the attempt counter (max attempts before lockout).
func (s *OTPService) VerifyOTP(ctx context.Context, phone string, otp string) (bool, error) {
	// Check attempt counter
	attemptsKey := otpAttemptsPrefix + phone
	attempts, err := s.redis.Get(ctx, attemptsKey).Int()
	if err != nil && err != redis.Nil {
		return false, fmt.Errorf("check attempts: %w", err)
	}

	maxAttempts := s.config.OTP.MaxAttempts
	if maxAttempts <= 0 {
		maxAttempts = defaultMaxAttempts
	}

	if attempts >= maxAttempts {
		return false, fmt.Errorf("maximum verification attempts exceeded, please request a new OTP")
	}

	// Get stored OTP
	otpKey := otpKeyPrefix + phone
	storedOTP, err := s.redis.Get(ctx, otpKey).Result()
	if err != nil {
		if err == redis.Nil {
			return false, fmt.Errorf("OTP has expired or was not requested")
		}
		return false, fmt.Errorf("get otp: %w", err)
	}

	// Compare
	if storedOTP != otp {
		// Increment attempt counter
		pipe := s.redis.Pipeline()
		pipe.Incr(ctx, attemptsKey)
		pipe.Expire(ctx, attemptsKey, s.config.OTP.Expiry)
		if _, err := pipe.Exec(ctx); err != nil {
			return false, fmt.Errorf("increment attempts: %w", err)
		}
		return false, nil
	}

	// Success: delete OTP key and attempt counter
	pipe := s.redis.Pipeline()
	pipe.Del(ctx, otpKey)
	pipe.Del(ctx, attemptsKey)
	if _, err := pipe.Exec(ctx); err != nil {
		return false, fmt.Errorf("cleanup after verify: %w", err)
	}

	return true, nil
}

// ResendCooldown returns the remaining cooldown duration.
// If the cooldown has expired, returns 0 and allows resend.
func (s *OTPService) ResendCooldown(ctx context.Context, phone string) (time.Duration, error) {
	cooldownKey := otpCooldownPrefix + phone
	ttl, err := s.redis.TTL(ctx, cooldownKey).Result()
	if err != nil {
		return 0, fmt.Errorf("check cooldown: %w", err)
	}

	if ttl <= 0 {
		return 0, nil
	}

	return ttl, nil
}

// generateRandomDigits generates a cryptographically secure random numeric string of the given length.
func generateRandomDigits(length int) (string, error) {
	result := make([]byte, length)
	for i := range result {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		result[i] = byte('0' + n.Int64())
	}
	return string(result), nil
}
