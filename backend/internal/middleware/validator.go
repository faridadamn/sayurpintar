package middleware

import (
	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/utils"
)

var validate = validator.New()

func Validate(s interface{}) error {
	return validate.Struct(s)
}

// ValidateBody parses and validates the request body.
// Usage: return middleware.ValidateBody(c, &req)
func ValidateBody(c *fiber.Ctx, s interface{}) error {
	if err := c.BodyParser(s); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", map[string]string{
			"error": err.Error(),
		})
	}
	if err := validate.Struct(s); err != nil {
		return utils.ValidationErrorResponse(c, err.(validator.ValidationErrors))
	}
	return nil
}
