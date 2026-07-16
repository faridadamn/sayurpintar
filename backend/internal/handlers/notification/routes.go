package notification

import (
	"github.com/gofiber/fiber/v2"
)

// RegisterRoutes registers all notification-related endpoints on the Fiber router.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	notif := app.Group("/notifications", authMiddleware)

	// List notifications
	notif.Get("/", handler.List)

	// Get unread count (must be before /:id to avoid conflict)
	notif.Get("/unread-count", handler.GetUnreadCount)

	// Mark all as read (must be before /:id to avoid conflict)
	notif.Put("/read-all", handler.MarkAllAsRead)

	// Mark single notification as read
	notif.Put("/:id/read", handler.MarkAsRead)

	// Delete notification
	notif.Delete("/:id", handler.Delete)
}
