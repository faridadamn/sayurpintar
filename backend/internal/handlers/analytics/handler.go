package analytics

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// AnalyticsHandler handles analytics-related HTTP requests.
type AnalyticsHandler struct {
	analyticsService *services.AnalyticsService
}

// NewAnalyticsHandler creates a new AnalyticsHandler.
func NewAnalyticsHandler(svc *services.AnalyticsService) *AnalyticsHandler {
	return &AnalyticsHandler{analyticsService: svc}
}

// GetDailySummary handles GET /analytics/daily-summary
// Query: date (default today, format YYYY-MM-DD)
func (h *AnalyticsHandler) GetDailySummary(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	date := c.Query("date", "")

	summary, err := h.analyticsService.GetDailySummary(c.Context(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get daily summary", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, summary, nil)
}

// GetWeeklyComparison handles GET /analytics/weekly-comparison
func (h *AnalyticsHandler) GetWeeklyComparison(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	comparison, err := h.analyticsService.GetWeeklyComparison(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get weekly comparison", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, comparison, nil)
}

// GetMonthlyOverview handles GET /analytics/monthly-overview
// Query: month (YYYY-MM, default current month)
func (h *AnalyticsHandler) GetMonthlyOverview(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	month := c.Query("month", "")

	overview, err := h.analyticsService.GetMonthlyOverview(c.Context(), pedagangID, month)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get monthly overview", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, overview, nil)
}

// GetTopItems handles GET /analytics/top-items
// Query: days (7/30/90, default 7), limit (default 10)
func (h *AnalyticsHandler) GetTopItems(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	days, err := strconv.Atoi(c.Query("days", "7"))
	if err != nil || days <= 0 {
		days = 7
	}

	limit, err := strconv.Atoi(c.Query("limit", "10"))
	if err != nil || limit <= 0 {
		limit = 10
	}

	items, err := h.analyticsService.GetTopSellingItems(c.Context(), pedagangID, days, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get top items", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, items, nil)
}

// GetCustomerAnalytics handles GET /analytics/customers
func (h *AnalyticsHandler) GetCustomerAnalytics(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	analytics, err := h.analyticsService.GetCustomerAnalytics(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get customer analytics", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, analytics, nil)
}

// GetRouteAnalytics handles GET /analytics/routes
// Query: days (default 7)
func (h *AnalyticsHandler) GetRouteAnalytics(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	days, err := strconv.Atoi(c.Query("days", "7"))
	if err != nil || days <= 0 {
		days = 7
	}

	analytics, err := h.analyticsService.GetRouteAnalytics(c.Context(), pedagangID, days)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get route analytics", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, analytics, nil)
}

// GetOverview handles GET /analytics/overview — combined dashboard overview.
func (h *AnalyticsHandler) GetOverview(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	ctx := c.Context()

	daily, err := h.analyticsService.GetDailySummary(ctx, pedagangID, "")
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get overview", nil)
	}

	topItems, err := h.analyticsService.GetTopSellingItems(ctx, pedagangID, 7, 5)
	if err != nil {
		topItems = []services.TopItem{}
	}

	customers, err := h.analyticsService.GetCustomerAnalytics(ctx, pedagangID)
	if err != nil {
		customers = &services.CustomerAnalytics{}
	}

	routes, err := h.analyticsService.GetRouteAnalytics(ctx, pedagangID, 7)
	if err != nil {
		routes = &services.RouteAnalytics{}
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"daily_summary":   daily,
		"top_items":       topItems,
		"customers":       customers,
		"route_analytics": routes,
	}, nil)
}
