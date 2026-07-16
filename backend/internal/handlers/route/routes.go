package route

import (
	"github.com/gofiber/fiber/v2"
)

// RegisterRoutes registers all route-related endpoints on the Fiber router.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	routes := app.Group("/routes", authMiddleware)

	// Route optimization
	routes.Post("/optimize", handler.OptimizeRoute)

	// Today's route
	routes.Get("/today", handler.GetTodayRoute)
	routes.Post("/today/start", handler.StartRoute)
	routes.Post("/today/complete", handler.CompleteRoute)

	// Today's route waypoints
	routes.Post("/today/waypoints", handler.AddToTodayRoute)
	routes.Delete("/today/waypoints/:id", handler.RemoveFromTodayRoute)

	// History & stats
	routes.Get("/history", handler.GetRouteHistory)
	routes.Get("/stats", handler.GetRouteStats)

	// Legacy CRUD endpoints (kept for backward compatibility)
	routes.Get("/", handler.GetRoutes)
	routes.Post("/", handler.CreateRoute)
	routes.Get("/:id", handler.GetRoute)
	routes.Put("/:id", handler.UpdateRoute)
	routes.Delete("/:id", handler.DeleteRoute)
	routes.Post("/:id/visits", handler.CompleteVisit)
}
