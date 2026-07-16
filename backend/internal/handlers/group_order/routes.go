package group_order

import (
	"github.com/gofiber/fiber/v2"
)

// RegisterRoutes registers all group order (GrosirKu) routes on the Fiber app.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	// ── Group order routes (all authenticated) ──
	groups := app.Group("/groups", authMiddleware)

	groups.Post("/", handler.CreateGroup)
	groups.Get("/", handler.ListGroups)
	groups.Get("/:id", handler.GetGroup)
	groups.Post("/:id/join", handler.JoinGroup)
	groups.Delete("/:id/leave", handler.LeaveGroup)
	groups.Get("/:id/participants", handler.ListParticipants)
	groups.Post("/:id/finalize", handler.FinalizeGroup)

	// ── Supplier routes (all authenticated) ──
	suppliers := app.Group("/suppliers", authMiddleware)

	suppliers.Get("/", handler.ListSuppliers)
	suppliers.Post("/", handler.CreateSupplier)
	suppliers.Post("/:id/rate", handler.RateSupplier)
}
