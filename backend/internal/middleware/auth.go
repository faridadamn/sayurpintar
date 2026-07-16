package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// AuthMiddleware validates JWT from the Authorization header.
// On success: sets user_id, phone, role in Fiber locals.
// On failure: returns 401 Unauthorized.
func AuthMiddleware(jwtService *services.JWTService) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authorization header required", nil)
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authorization format", nil)
		}

		claims, err := jwtService.ValidateToken(parts[1])
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid or expired token", nil)
		}

		c.Locals("user_id", claims.UserID)
		c.Locals("phone", claims.Phone)
		c.Locals("role", claims.Role)

		return c.Next()
	}
}

// RequireRole middleware checks if the authenticated user has one of the allowed roles.
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

// GetUserID extracts the user ID from Fiber locals.
func GetUserID(c *fiber.Ctx) string {
	id, _ := c.Locals("user_id").(string)
	return id
}

// GetUserRole extracts the user role from Fiber locals.
func GetUserRole(c *fiber.Ctx) string {
	role, _ := c.Locals("role").(string)
	return role
}

// GetUserPhone extracts the user phone from Fiber locals.
func GetUserPhone(c *fiber.Ctx) string {
	phone, _ := c.Locals("phone").(string)
	return phone
}
