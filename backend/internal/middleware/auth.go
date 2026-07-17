package middleware

import (
	"context"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

type TokenRevocationChecker interface {
	IsTokenBlacklisted(ctx context.Context, token string) (bool, error)
}

// AuthMiddleware validates JWT from the Authorization header and rejects revoked tokens.
func AuthMiddleware(jwtService *services.JWTService, revocations TokenRevocationChecker) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authorization header required", nil)
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authorization format", nil)
		}
		tokenString := strings.TrimSpace(parts[1])

		claims, err := jwtService.ValidateToken(tokenString)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid or expired token", nil)
		}
		if revocations != nil {
			revoked, err := revocations.IsTokenBlacklisted(c.Context(), tokenString)
			if err != nil {
				return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "Authentication service unavailable", nil)
			}
			if revoked {
				return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Token has been revoked", nil)
			}
		}

		c.Locals("user_id", claims.UserID)
		c.Locals("phone", claims.Phone)
		c.Locals("role", claims.Role)
		c.Locals("token_id", claims.ID)
		return c.Next()
	}
}

func RequireRole(roles ...string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		role, ok := c.Locals("role").(string)
		if !ok {
			return utils.ErrorResponse(c, fiber.StatusForbidden, "Role not found", nil)
		}
		for _, r := range roles {
			if role == r {
				return c.Next()
			}
		}
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Insufficient permissions", nil)
	}
}

func GetUserID(c *fiber.Ctx) string { id, _ := c.Locals("user_id").(string); return id }
func GetUserRole(c *fiber.Ctx) string { role, _ := c.Locals("role").(string); return role }
func GetUserPhone(c *fiber.Ctx) string { phone, _ := c.Locals("phone").(string); return phone }
