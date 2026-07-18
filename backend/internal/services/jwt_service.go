package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/sayurpintar/api/internal/config"
	"github.com/sayurpintar/api/internal/models"
)

const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

var (
	ErrInvalidToken     = errors.New("invalid or expired token")
	ErrTokenExpired     = errors.New("token has expired")
	ErrInvalidTokenType = errors.New("invalid token type")
)

// Claims represents the JWT claims used in SayurPintar tokens.
type Claims struct {
	UserID    string `json:"user_id"`
	Phone     string `json:"phone"`
	Role      string `json:"role"`
	TokenType string `json:"token_type"`
	jwt.RegisteredClaims
}

// TokenPair contains both access and refresh tokens.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

// JWTService handles JWT token creation and validation.
type JWTService struct {
	secret        []byte
	issuer        string
	accessExpiry  time.Duration
	refreshExpiry time.Duration
}

// NewJWTService creates a new JWTService from configuration.
func NewJWTService(cfg *config.Config) *JWTService {
	accessExpiry := cfg.JWT.AccessExpiry
	if accessExpiry <= 0 {
		accessExpiry = 24 * time.Hour
	}

	refreshExpiry := cfg.JWT.RefreshExpiry
	if refreshExpiry <= 0 {
		refreshExpiry = 30 * 24 * time.Hour
	}

	return &JWTService{
		secret:        []byte(cfg.JWT.Secret),
		issuer:        "sayurpintar",
		accessExpiry:  accessExpiry,
		refreshExpiry: refreshExpiry,
	}
}

func (s *JWTService) generateToken(user *models.User, tokenType string, expiry time.Duration) (string, error) {
	now := time.Now()
	claims := &Claims{
		UserID:    user.ID,
		Phone:     user.Phone,
		Role:      string(user.Role),
		TokenType: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    s.issuer,
			Subject:   user.ID,
			Audience:  jwt.ClaimStrings{"sayurpintar-app"},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(expiry)),
			NotBefore: jwt.NewNumericDate(now),
			ID:        uuid.New().String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(s.secret)
	if err != nil {
		return "", fmt.Errorf("sign %s token: %w", tokenType, err)
	}
	return tokenString, nil
}

// GenerateAccessToken creates a short-lived access token.
func (s *JWTService) GenerateAccessToken(user *models.User) (string, error) {
	return s.generateToken(user, TokenTypeAccess, s.accessExpiry)
}

// GenerateRefreshToken creates a long-lived refresh token.
func (s *JWTService) GenerateRefreshToken(user *models.User) (string, error) {
	return s.generateToken(user, TokenTypeRefresh, s.refreshExpiry)
}

// GenerateTokenPair creates both access and refresh tokens.
func (s *JWTService) GenerateTokenPair(user *models.User) (*TokenPair, error) {
	accessToken, err := s.GenerateAccessToken(user)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	refreshToken, err := s.GenerateRefreshToken(user)
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(s.accessExpiry.Seconds()),
	}, nil
}

func (s *JWTService) validateToken(tokenString, expectedType string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(
		tokenString,
		claims,
		func(t *jwt.Token) (interface{}, error) {
			if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
				return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
			}
			return s.secret, nil
		},
		jwt.WithIssuer(s.issuer),
		jwt.WithAudience("sayurpintar-app"),
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
	)

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrInvalidToken
	}
	if !token.Valid {
		return nil, ErrInvalidToken
	}
	if claims.TokenType != expectedType {
		return nil, ErrInvalidTokenType
	}
	if claims.Subject == "" || claims.Subject != claims.UserID || claims.ID == "" {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

// ValidateToken validates an access token. Kept as the public access-token validator.
func (s *JWTService) ValidateToken(tokenString string) (*Claims, error) {
	return s.validateToken(tokenString, TokenTypeAccess)
}

// ValidateRefreshToken validates that a token is specifically a refresh token.
func (s *JWTService) ValidateRefreshToken(tokenString string) (*Claims, error) {
	return s.validateToken(tokenString, TokenTypeRefresh)
}

// ExtractUserID is a convenience method to get just the user ID from an access token.
func (s *JWTService) ExtractUserID(tokenString string) (string, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return "", err
	}
	return claims.UserID, nil
}
