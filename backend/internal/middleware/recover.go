package middleware

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/utils"
	"go.uber.org/zap"
)

func Recover(logger *zap.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		defer func() {
			if r := recover(); r != nil {
				logger.Error("panic recovered",
					zap.Any("error", r),
					zap.String("path", c.Path()),
					zap.String("method", c.Method()),
				)
				_ = utils.ErrorResponse(c, fiber.StatusInternalServerError, "Internal server error", nil)
			}
		}()
		return c.Next()
	}
}
