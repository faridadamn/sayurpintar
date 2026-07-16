package analytics

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
)

// RegisterRoutes registers all analytics endpoints on the Fiber router.
// All analytics routes are pedagang-only.
func RegisterRoutes(app fiber.Router, handler *AnalyticsHandler, authMiddleware fiber.Handler) {
	analytics := app.Group("/analytics", authMiddleware, middleware.RequireRole("pedagang"))

	analytics.Get("/daily-summary", handler.GetDailySummary)
	analytics.Get("/weekly-comparison", handler.GetWeeklyComparison)
	analytics.Get("/monthly-overview", handler.GetMonthlyOverview)
	analytics.Get("/top-items", handler.GetTopItems)
	analytics.Get("/customers", handler.GetCustomerAnalytics)
	analytics.Get("/routes", handler.GetRouteAnalytics)
	analytics.Get("/overview", handler.GetOverview)
}

// RegisterAdvancedRoutes registers credit score and demand prediction endpoints.
func RegisterAdvancedRoutes(app fiber.Router, handler *AdvancedAnalyticsHandler, authMiddleware fiber.Handler) {
	analytics := app.Group("/analytics", authMiddleware, middleware.RequireRole("pedagang"))

	analytics.Get("/credit-score", handler.GetCreditScore)
	analytics.Get("/credit-score/history", handler.GetCreditScoreHistory)
	analytics.Get("/demand-prediction", handler.GetDemandPrediction)
}
