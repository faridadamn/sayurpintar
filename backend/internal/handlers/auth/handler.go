package auth

import (
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// AuthHandler handles authentication HTTP requests.
type AuthHandler struct {
	authService *services.AuthService
}

// NewAuthHandler creates a new auth handler.
func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// Register handles POST /auth/register.
// Sends an OTP to the given phone number. Creates user if not exists.
func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req RegisterRequest
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	resp, err := h.authService.SendOTP(c.Context(), req.Phone)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to send OTP", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

// SendOTP handles POST /auth/otp/send.
// Resends an OTP to the given phone number.
func (h *AuthHandler) SendOTP(c *fiber.Ctx) error {
	var req SendOTPRequest
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	resp, err := h.authService.SendOTP(c.Context(), req.Phone)
	if err != nil {
		if strings.Contains(err.Error(), "too many OTP requests") {
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Too many OTP requests, please wait", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to send OTP", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

// VerifyOTP handles POST /auth/otp/verify.
// Verifies the OTP and returns JWT tokens.
func (h *AuthHandler) VerifyOTP(c *fiber.Ctx) error {
	var req VerifyOTPRequest
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	resp, err := h.authService.VerifyOTP(c.Context(), req.Phone, req.OTP)
	if err != nil {
		msg := err.Error()
		switch {
		case strings.Contains(msg, "invalid OTP"):
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid OTP", nil)
		case strings.Contains(msg, "maximum verification attempts"):
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Too many attempts, please request a new OTP", nil)
		case strings.Contains(msg, "expired"):
			return utils.ErrorResponse(c, fiber.StatusGone, "OTP has expired, please request a new one", nil)
		default:
			return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Verification failed", nil)
		}
	}

	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

// SetRole handles POST /auth/role.
// Sets the user's role (first time only).
func (h *AuthHandler) SetRole(c *fiber.Ctx) error {
	var req SetRoleRequest
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	err := h.authService.SetRole(c.Context(), userID, req.Role)
	if err != nil {
		msg := err.Error()
		switch {
		case strings.Contains(msg, "invalid role"):
			return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid role, must be 'pedagang' or 'pelanggan'", nil)
		case strings.Contains(msg, "role already set"):
			return utils.ErrorResponse(c, fiber.StatusConflict, "Role has already been set", nil)
		default:
			return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to set role", nil)
		}
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Role set successfully",
		"role":    req.Role,
	}, nil)
}

// RefreshToken handles POST /auth/token/refresh.
// Validates a refresh token and issues a new access token.
func (h *AuthHandler) RefreshToken(c *fiber.Ctx) error {
	var req RefreshTokenRequest
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	resp, err := h.authService.RefreshToken(c.Context(), req.RefreshToken)
	if err != nil {
		if strings.Contains(err.Error(), "invalid refresh token") || strings.Contains(err.Error(), "revoked") {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid or expired refresh token", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to refresh token", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

// GetProfile handles GET /auth/me.
// Returns the authenticated user's profile.
func (h *AuthHandler) GetProfile(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	user, err := h.authService.GetProfile(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "User not found", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, user, nil)
}

// UpdateProfile handles PUT /auth/me.
// Updates the authenticated user's profile.
func (h *AuthHandler) UpdateProfile(c *fiber.Ctx) error {
	var req UpdateProfileBody
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}

	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	updateReq := services.UpdateProfileRequest{
		Name:      req.Name,
		Address:   req.Address,
		AvatarURL: req.AvatarURL,
	}

	user, err := h.authService.UpdateProfile(c.Context(), userID, updateReq)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to update profile", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, user, nil)
}

// Logout handles POST /auth/logout.
// Invalidates the current access token by adding it to the Redis blacklist.
func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Missing authorization header", nil)
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authorization format", nil)
	}

	tokenStr := parts[1]

	// Blacklist the token with a 24h TTL (safe default; actual expiry is enforced at verify time)
	if err := h.authService.Logout(c.Context(), tokenStr, time.Now().Add(24*time.Hour)); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to logout", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Logged out successfully",
	}, nil)
}
