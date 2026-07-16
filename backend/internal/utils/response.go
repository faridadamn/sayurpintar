package utils

import (
	"fmt"
	"strings"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
)

// SuccessResponse sends a standard success response.
func SuccessResponse(c *fiber.Ctx, statusCode int, data interface{}, meta interface{}) error {
	resp := fiber.Map{
		"success": true,
		"data":    data,
	}
	if meta != nil {
		resp["meta"] = meta
	}
	return c.Status(statusCode).JSON(resp)
}

// ErrorResponse sends a standard error response.
func ErrorResponse(c *fiber.Ctx, statusCode int, message string, details interface{}) error {
	resp := fiber.Map{
		"success": false,
		"error": fiber.Map{
			"code":    statusCode,
			"message": message,
		},
	}
	if details != nil {
		resp["error"].(fiber.Map)["details"] = details
	}
	return c.Status(statusCode).JSON(resp)
}

// PaginatedResponse sends a paginated response.
func PaginatedResponse(c *fiber.Ctx, data interface{}, page, perPage, total int) error {
	totalPages := (total + perPage - 1) / perPage
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"data":    data,
		"meta": fiber.Map{
			"page":        page,
			"per_page":    perPage,
			"total":       total,
			"total_pages": totalPages,
		},
	})
}

// ValidationErrorResponse formats validation errors.
func ValidationErrorResponse(c *fiber.Ctx, errs validator.ValidationErrors) error {
	details := make(map[string]string)
	for _, e := range errs {
		field := strings.ToLower(e.Field())
		switch e.Tag() {
		case "required":
			details[field] = fmt.Sprintf("%s is required", field)
		case "min":
			details[field] = fmt.Sprintf("%s must be at least %s characters", field, e.Param())
		case "max":
			details[field] = fmt.Sprintf("%s must be at most %s characters", field, e.Param())
		case "email":
			details[field] = fmt.Sprintf("%s must be a valid email", field)
		case "oneof":
			details[field] = fmt.Sprintf("%s must be one of: %s", field, e.Param())
		default:
			details[field] = fmt.Sprintf("%s failed validation: %s", field, e.Tag())
		}
	}
	return ErrorResponse(c, fiber.StatusBadRequest, "Validation failed", details)
}
