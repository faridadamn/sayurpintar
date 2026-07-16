package subscription

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
)

// RegisterRoutes registers all subscription-related routes on the Fiber app.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	sub := app.Group("/subscriptions", authMiddleware)

	// Package endpoints (pedagang manages packages)
	sub.Post("/packages", middleware.RequireRole("pedagang"), handler.CreatePackage)
	sub.Get("/packages", handler.GetPackages)
	sub.Get("/packages/:id", handler.GetPackage)
	sub.Put("/packages/:id", middleware.RequireRole("pedagang"), handler.UpdatePackage)
	sub.Delete("/packages/:id", middleware.RequireRole("pedagang"), handler.DeletePackage)

	// Subscription endpoints
	sub.Post("/subscribe", middleware.RequireRole("pelanggan"), handler.Subscribe)
	sub.Get("/active", handler.GetActiveSubscriptions)
	sub.Get("/:id", handler.GetSubscription)
	sub.Put("/:id/pause", handler.PauseSubscription)
	sub.Put("/:id/resume", handler.ResumeSubscription)
	sub.Delete("/:id", handler.CancelSubscription)

	// Modification endpoints
	sub.Post("/:id/modify", handler.ModifyDelivery)
	sub.Get("/:id/modifications", handler.ListModifications)
	sub.Delete("/:id/modify/:mod_id", handler.DeleteModification)

	// Additional endpoints
	sub.Get("/:id/detail", handler.GetSubscriptionDetail)
	sub.Get("/:id/upcoming", handler.GetUpcomingDeliveries)
	sub.Get("/stats", middleware.RequireRole("pedagang"), handler.GetSubscriberStats)
}
