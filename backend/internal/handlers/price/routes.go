package price

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
)

// RegisterRoutes registers all price and product routes on the Fiber app.
func RegisterRoutes(app fiber.Router, handler *PriceHandler, authMiddleware fiber.Handler) {
	// ── Price routes (all authenticated) ──
	prices := app.Group("/prices", authMiddleware)

	prices.Post("/submit", handler.SubmitPrice)
	prices.Get("/current", handler.GetCurrentPrices)
	prices.Get("/trend/:product_id", handler.GetPriceTrend)
	prices.Get("/recommend/:product_id", handler.GetRecommendedPrice)

	// Alerts
	prices.Post("/alerts", handler.CreateAlert)
	prices.Get("/alerts", handler.GetAlerts)
	prices.Delete("/alerts/:id", handler.DeleteAlert)

	// Stats
	prices.Get("/stats/area", handler.GetAreaStats)
	prices.Get("/top-movers", handler.GetTopMovers)

	// ── Product routes ──
	products := app.Group("/products", authMiddleware)

	// Public (authenticated) reads
	products.Get("/", handler.ListProducts)
	products.Get("/categories", handler.GetCategories)
	products.Get("/:id", handler.GetProduct)

	// Admin-only writes
	products.Post("/", middleware.RequireRole("admin"), handler.CreateProduct)
	products.Put("/:id", middleware.RequireRole("admin"), handler.UpdateProduct)
}
