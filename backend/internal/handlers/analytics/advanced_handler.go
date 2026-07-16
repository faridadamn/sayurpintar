package analytics

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// AdvancedAnalyticsHandler handles advanced analytics HTTP requests.
type AdvancedAnalyticsHandler struct {
	creditScoreService *services.CreditScoreService
	demandPredictor    *services.DemandPredictor
}

// NewAdvancedAnalyticsHandler creates a new AdvancedAnalyticsHandler.
func NewAdvancedAnalyticsHandler(
	creditScoreService *services.CreditScoreService,
	demandPredictor *services.DemandPredictor,
) *AdvancedAnalyticsHandler {
	return &AdvancedAnalyticsHandler{
		creditScoreService: creditScoreService,
		demandPredictor:    demandPredictor,
	}
}

// GetCreditScore handles GET /analytics/credit-score
// Returns the authenticated pedagang's credit score.
func (h *AdvancedAnalyticsHandler) GetCreditScore(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	score, err := h.creditScoreService.CalculateCreditScore(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to calculate credit score", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, score, nil)
}

// GetCreditScoreHistory handles GET /analytics/credit-score/history
// Query: months (default 6, max 24)
func (h *AdvancedAnalyticsHandler) GetCreditScoreHistory(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	months, err := strconv.Atoi(c.Query("months", "6"))
	if err != nil || months <= 0 {
		months = 6
	}
	if months > 24 {
		months = 24
	}

	history, err := h.creditScoreService.GetScoreHistory(c.Context(), pedagangID, months)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get score history", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, history, nil)
}

// GetDemandPrediction handles GET /analytics/demand-prediction
// Query: date (default tomorrow, format YYYY-MM-DD)
func (h *AdvancedAnalyticsHandler) GetDemandPrediction(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	dateStr := c.Query("date", "")
	var date time.Time
	if dateStr != "" {
		var err error
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid date format, use YYYY-MM-DD", nil)
		}
	} else {
		date = time.Now().AddDate(0, 0, 1) // tomorrow
	}

	predictions, err := h.demandPredictor.PredictDemand(c.Context(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to predict demand", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"date":        date.Format("2006-01-02"),
		"predictions": predictions,
	}, nil)
}
