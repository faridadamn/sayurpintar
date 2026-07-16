package route

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/go-playground/validator/v10"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// VisitHandler handles HTTP requests related to visits.
type VisitHandler struct {
	visitService *services.VisitService
	validate     *validator.Validate
}

// NewVisitHandler creates a new VisitHandler.
func NewVisitHandler(visitService *services.VisitService) *VisitHandler {
	return &VisitHandler{
		visitService: visitService,
		validate:     validator.New(),
	}
}

// MarkVisitArrived handles POST /routes/visits/:id/arrive
func (h *VisitHandler) MarkVisitArrived(c *fiber.Ctx) error {
	visitID := c.Params("id")
	if visitID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Visit ID is required", nil)
	}

	if err := h.visitService.MarkArrived(c.Context(), visitID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark arrived", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Visit marked as arrived",
		"visit_id": visitID,
	}, nil)
}

// MarkVisitCompleted handles POST /routes/visits/:id/complete
func (h *VisitHandler) MarkVisitCompleted(c *fiber.Ctx) error {
	visitID := c.Params("id")
	if visitID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Visit ID is required", nil)
	}

	var req services.CompleteVisitRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if err := h.validate.Struct(req); err != nil {
		return utils.ValidationErrorResponse(c, err.(validator.ValidationErrors))
	}

	if err := h.visitService.MarkCompleted(c.Context(), visitID, req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark completed", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Visit marked as completed",
		"visit_id": visitID,
	}, nil)
}

// MarkVisitSkipped handles POST /routes/visits/:id/skip
func (h *VisitHandler) MarkVisitSkipped(c *fiber.Ctx) error {
	visitID := c.Params("id")
	if visitID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Visit ID is required", nil)
	}

	var body struct {
		Reason string `json:"reason" validate:"required"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if err := h.validate.Struct(body); err != nil {
		return utils.ValidationErrorResponse(c, err.(validator.ValidationErrors))
	}

	if err := h.visitService.MarkSkipped(c.Context(), visitID, body.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark skipped", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Visit marked as skipped",
		"visit_id": visitID,
	}, nil)
}

// GetTodayVisits handles GET /routes/visits/today
func (h *VisitHandler) GetTodayVisits(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	visits, err := h.visitService.GetTodayVisits(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get today's visits", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, visits, nil)
}

// GetVisitSummary handles GET /routes/visits/summary
func (h *VisitHandler) GetVisitSummary(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	date := c.Query("date", time.Now().Format("2006-01-02"))

	summary, err := h.visitService.GetVisitSummary(c.Context(), userID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get visit summary", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, summary, nil)
}
