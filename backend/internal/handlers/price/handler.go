package price

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
	"go.uber.org/zap"
)

// PriceHandler handles price-related HTTP requests.
type PriceHandler struct {
	service *services.PriceService
	logger  *zap.Logger
}

// NewPriceHandler creates a new PriceHandler backed by PriceService.
func NewPriceHandler(service *services.PriceService, logger *zap.Logger) *PriceHandler {
	return &PriceHandler{
		service: service,
		logger:  logger,
	}
}

// SubmitPrice handles price data submission.
// POST /prices/submit
func (h *PriceHandler) SubmitPrice(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	var body struct {
		ProductID   string  `json:"product_id"`
		ProductName string  `json:"product_name"`
		Price       float64 `json:"price"`
		Market      string  `json:"market"`
		Area        string  `json:"area"`
		Unit        string  `json:"unit"`
	}

	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.ProductID == "" && body.ProductName == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "product_id or product_name is required", nil)
	}
	if body.Price <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "price must be greater than 0", nil)
	}
	if body.Area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area is required", nil)
	}
	if body.Market == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "market is required", nil)
	}

	// Resolve product ID from name if not provided
	if body.ProductID == "" {
		resolvedID, err := h.service.ProductIDFromName(c.Context(), body.ProductName)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusBadRequest, "Product not found: "+body.ProductName, nil)
		}
		body.ProductID = resolvedID
	}

	// Resolve default unit if not provided
	if body.Unit == "" {
		unit, _ := h.service.DefaultUnitForProduct(c.Context(), body.ProductID)
		body.Unit = unit
	}

	submission := &models.PriceSubmission{
		ProductID:   body.ProductID,
		ProductName: body.ProductName,
		Area:        body.Area,
		Market:      body.Market,
		Price:       body.Price,
		Unit:        body.Unit,
		SubmittedBy: userID,
		Date:        time.Now().Format("2006-01-02"),
	}

	if err := h.service.SubmitPrice(c.Context(), submission); err != nil {
		if err == repository.ErrSpamLimitReached {
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests,
				"Submission limit reached: max 3 submissions per product per day", nil)
		}
		h.logger.Error("Failed to submit price", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to submit price", nil)
	}

	// Reward: +1 point for verified pedagang
	role := middleware.GetUserRole(c)
	if role == "pedagang" {
		h.logger.Info("Price submission reward", zap.String("user_id", userID), zap.Int("points", 1))
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, fiber.Map{
		"message":       "Price submitted successfully",
		"submission_id": submission.ID,
	}, nil)
}

// GetCurrentPrices returns current aggregated prices by area.
// GET /prices/current?area=jakarta_selatan&date=2026-07-16
func (h *PriceHandler) GetCurrentPrices(c *fiber.Ctx) error {
	area := c.Query("area", "")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	date := c.Query("date", time.Now().Format("2006-01-02"))

	prices, err := h.service.GetCurrentPrices(c.Context(), area, date)
	if err != nil {
		h.logger.Error("Failed to get current prices", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get current prices", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, prices, nil)
}

// GetPriceTrend returns price trend for a product over N days.
// GET /prices/trend/:product_id?area=jakarta_selatan&days=7
func (h *PriceHandler) GetPriceTrend(c *fiber.Ctx) error {
	productID := c.Params("product_id")
	if productID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "product_id is required", nil)
	}

	area := c.Query("area", "")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	days := services.ParseDays(c.Query("days", "7"))

	trend, err := h.service.GetPriceTrend(c.Context(), productID, area, days)
	if err != nil {
		h.logger.Error("Failed to get price trend", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get price trend", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, trend, nil)
}

// GetRecommendedPrice calculates a recommended selling price.
// GET /prices/recommend/:product_id?area=jakarta_selatan&margin_pct=30
func (h *PriceHandler) GetRecommendedPrice(c *fiber.Ctx) error {
	productID := c.Params("product_id")
	if productID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "product_id is required", nil)
	}

	area := c.Query("area", "")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	marginPct := services.ParseMargin(c.Query("margin_pct", "30"))

	today := time.Now().Format("2006-01-02")
	medianPrice, err := h.service.GetMedianPrice(c.Context(), productID, area, today)
	if err != nil {
		h.logger.Error("Failed to get median price", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to calculate recommended price", nil)
	}

	if medianPrice == 0 {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "No price data available for this product and area", nil)
	}

	suggestedPrice := medianPrice * (1 + marginPct/100)

	recommended := models.RecommendedPrice{
		ProductID:      productID,
		MarketPrice:    medianPrice,
		SuggestedPrice: suggestedPrice,
		Margin:         marginPct,
	}

	return utils.SuccessResponse(c, fiber.StatusOK, recommended, nil)
}

// CreateAlert creates a new price alert.
// POST /prices/alerts
func (h *PriceHandler) CreateAlert(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	var body struct {
		ProductID   string  `json:"product_id"`
		ProductName string  `json:"product_name"`
		Area        string  `json:"area"`
		Threshold   float64 `json:"threshold"`
		Direction   string  `json:"direction"`
	}

	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.ProductID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "product_id is required", nil)
	}
	if body.Area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area is required", nil)
	}
	if body.Threshold <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "threshold must be greater than 0", nil)
	}
	if body.Direction == "" {
		body.Direction = "both"
	}
	if body.Direction != "up" && body.Direction != "down" && body.Direction != "both" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "direction must be one of: up, down, both", nil)
	}

	alert := &models.PriceAlert{
		UserID:      userID,
		ProductID:   body.ProductID,
		ProductName: body.ProductName,
		Area:        body.Area,
		Threshold:   body.Threshold,
		Direction:   body.Direction,
	}

	if err := h.service.CreateAlert(c.Context(), alert); err != nil {
		h.logger.Error("Failed to create alert", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to create price alert", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, alert, nil)
}

// GetAlerts returns the authenticated user's price alerts.
// GET /prices/alerts
func (h *PriceHandler) GetAlerts(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	alerts, err := h.service.GetAlertsByUser(c.Context(), userID)
	if err != nil {
		h.logger.Error("Failed to get alerts", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get alerts", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, alerts, nil)
}

// DeleteAlert deletes a price alert.
// DELETE /prices/alerts/:id
func (h *PriceHandler) DeleteAlert(c *fiber.Ctx) error {
	alertID := c.Params("id")
	if alertID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Alert ID is required", nil)
	}

	if err := h.service.DeleteAlert(c.Context(), alertID); err != nil {
		if err == repository.ErrAlertNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Alert not found", nil)
		}
		h.logger.Error("Failed to delete alert", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to delete alert", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Alert deleted successfully",
	}, nil)
}

// GetAreaStats returns price statistics for an area.
// GET /prices/stats/area?area=jakarta_selatan&date=2026-07-16
func (h *PriceHandler) GetAreaStats(c *fiber.Ctx) error {
	area := c.Query("area", "")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	date := c.Query("date", time.Now().Format("2006-01-02"))

	stats, err := h.service.GetAreaStats(c.Context(), area, date)
	if err != nil {
		h.logger.Error("Failed to get area stats", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get area statistics", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, stats, nil)
}

// GetTopMovers returns products with the biggest price changes.
// GET /prices/top-movers?area=jakarta_selatan&limit=10
func (h *PriceHandler) GetTopMovers(c *fiber.Ctx) error {
	area := c.Query("area", "")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	date := c.Query("date", time.Now().Format("2006-01-02"))
	limit := services.ParseLimit(c.Query("limit", "10"), 10)

	movers, err := h.service.GetTopMovers(c.Context(), area, date, limit)
	if err != nil {
		h.logger.Error("Failed to get top movers", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get top movers", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, movers, nil)
}
