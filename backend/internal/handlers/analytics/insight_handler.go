package analytics

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// InsightHandler handles insight HTTP requests.
type InsightHandler struct {
	insightService *services.InsightService
}

// NewInsightHandler creates a new InsightHandler.
func NewInsightHandler(insightService *services.InsightService) *InsightHandler {
	return &InsightHandler{
		insightService: insightService,
	}
}

// GetInsights returns all insights for the authenticated pedagang.
// GET /insights
func (h *InsightHandler) GetInsights(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	insights, err := h.insightService.GenerateInsights(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get insights", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, insights, nil)
}

// RegisterInsightRoutes registers insight endpoints on the given router.
func RegisterInsightRoutes(app fiber.Router, insightHandler *InsightHandler, authMiddleware fiber.Handler) {
	insights := app.Group("/insights", authMiddleware)

	insights.Get("/", insightHandler.GetInsights)
}
