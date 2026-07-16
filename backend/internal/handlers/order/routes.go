package order

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
)

// RegisterRoutes registers all order-related endpoints on the Fiber router.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	orders := app.Group("/orders", authMiddleware)

	// Pedagang: today's orders and summary
	orders.Get("/today", middleware.RequireRole("pedagang"), handler.GetTodayOrders)
	orders.Get("/summary", middleware.RequireRole("pedagang"), handler.GetOrderSummary)

	// Pedagang: list orders by date
	orders.Get("/", middleware.RequireRole("pedagang"), handler.ListByPedagangAndDate)

	// Pelanggan: list own orders
	orders.Get("/my", middleware.RequireRole("pelanggan"), handler.ListByPelanggan)

	// Pedagang: create one-time order
	orders.Post("/one-time", middleware.RequireRole("pedagang"), handler.CreateOneTimeOrder)

	// Order detail — accessible by both pedagang (owner) and pelanggan (customer)
	orders.Get("/:id", handler.GetOrder)

	// Pedagang: status management
	orders.Patch("/:id/status", middleware.RequireRole("pedagang"), handler.UpdateOrderStatus)
	orders.Post("/:id/deliver", middleware.RequireRole("pedagang"), handler.MarkDelivered)
	orders.Post("/:id/cancel", handler.CancelOrder) // both can cancel

	// Pedagang: payment update
	orders.Patch("/:id/payment", middleware.RequireRole("pedagang"), handler.UpdatePayment)

	// Pelanggan: rate delivered order
	orders.Post("/:id/rate", middleware.RequireRole("pelanggan"), handler.AddRating)
}
