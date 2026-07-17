package auth

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

type AuthHandler struct { authService *services.AuthService }
func NewAuthHandler(authService *services.AuthService) *AuthHandler { return &AuthHandler{authService: authService} }

func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req RegisterRequest
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	resp, err := h.authService.SendOTP(c.Context(), req.Phone)
	if err != nil { return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to send OTP", nil) }
	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

func (h *AuthHandler) SendOTP(c *fiber.Ctx) error {
	var req SendOTPRequest
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	resp, err := h.authService.SendOTP(c.Context(), req.Phone)
	if err != nil {
		if strings.Contains(err.Error(), "too many OTP requests") { return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Too many OTP requests, please wait", nil) }
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to send OTP", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

func (h *AuthHandler) VerifyOTP(c *fiber.Ctx) error {
	var req VerifyOTPRequest
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	resp, err := h.authService.VerifyOTP(c.Context(), req.Phone, req.OTP)
	if err != nil {
		msg := err.Error()
		switch {
		case strings.Contains(msg, "invalid OTP"): return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid OTP", nil)
		case strings.Contains(msg, "maximum verification attempts"): return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Too many attempts, please request a new OTP", nil)
		case strings.Contains(msg, "expired"): return utils.ErrorResponse(c, fiber.StatusGone, "OTP has expired, please request a new one", nil)
		default: return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Verification failed", nil)
		}
	}
	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

func (h *AuthHandler) SetRole(c *fiber.Ctx) error {
	var req SetRoleRequest
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" { return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil) }
	if err := h.authService.SetRole(c.Context(), userID, req.Role); err != nil {
		msg := err.Error()
		switch {
		case strings.Contains(msg, "invalid role"): return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid role, must be 'pedagang' or 'pelanggan'", nil)
		case strings.Contains(msg, "role already set"): return utils.ErrorResponse(c, fiber.StatusConflict, "Role has already been set", nil)
		default: return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to set role", nil)
		}
	}
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message":"Role set successfully", "role":req.Role}, nil)
}

func (h *AuthHandler) RefreshToken(c *fiber.Ctx) error {
	var req RefreshTokenRequest
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	resp, err := h.authService.RefreshToken(c.Context(), req.RefreshToken)
	if err != nil {
		if strings.Contains(err.Error(), "invalid refresh token") || strings.Contains(err.Error(), "revoked") { return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid or expired refresh token", nil) }
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to refresh token", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusOK, resp, nil)
}

func (h *AuthHandler) GetProfile(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" { return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil) }
	user, err := h.authService.GetProfile(c.Context(), userID)
	if err != nil { return utils.ErrorResponse(c, fiber.StatusNotFound, "User not found", nil) }
	return utils.SuccessResponse(c, fiber.StatusOK, user, nil)
}

func (h *AuthHandler) UpdateProfile(c *fiber.Ctx) error {
	var req UpdateProfileBody
	if err := middleware.ValidateBody(c, &req); err != nil { return err }
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" { return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil) }
	user, err := h.authService.UpdateProfile(c.Context(), userID, services.UpdateProfileRequest{Name:req.Name, Address:req.Address, AvatarURL:req.AvatarURL})
	if err != nil { return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to update profile", nil) }
	return utils.SuccessResponse(c, fiber.StatusOK, user, nil)
}

func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") || strings.TrimSpace(parts[1]) == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authorization format", nil)
	}
	if err := h.authService.Logout(c.Context(), strings.TrimSpace(parts[1])); err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid or expired access token", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message":"Logged out successfully"}, nil)
}
