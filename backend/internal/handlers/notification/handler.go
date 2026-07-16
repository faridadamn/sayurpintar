package notification

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler handles notification-related HTTP requests.
type Handler struct {
	notifRepo repository.NotificationRepository
}

// NewNotificationHandler creates a new Handler.
func NewNotificationHandler(repo repository.NotificationRepository) *Handler {
	return &Handler{notifRepo: repo}
}

// List handles GET /notifications
// Query: limit (default 20), offset (default 0), unread (true/false)
func (h *Handler) List(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	limit, err := strconv.Atoi(c.Query("limit", "20"))
	if err != nil || limit <= 0 {
		limit = 20
	}

	offset, err := strconv.Atoi(c.Query("offset", "0"))
	if err != nil || offset < 0 {
		offset = 0
	}

	unreadOnly := c.Query("unread", "false") == "true"

	notifs, total, err := h.notifRepo.ListByUser(c.Context(), userID, limit, offset, unreadOnly)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list notifications", nil)
	}

	return utils.PaginatedResponse(c, notifs, (offset/limit)+1, limit, total)
}

// MarkAsRead handles PUT /notifications/:id/read
func (h *Handler) MarkAsRead(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	notifID := c.Params("id")

	if notifID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Notification ID required", nil)
	}

	if err := h.notifRepo.MarkAsRead(c.Context(), notifID, userID); err != nil {
		if err == repository.ErrNotificationNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Notification not found", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark as read", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Notification marked as read"}, nil)
}

// MarkAllAsRead handles PUT /notifications/read-all
func (h *Handler) MarkAllAsRead(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	count, err := h.notifRepo.MarkAllAsRead(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark all as read", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "All notifications marked as read",
		"count":   count,
	}, nil)
}

// GetUnreadCount handles GET /notifications/unread-count
func (h *Handler) GetUnreadCount(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	count, err := h.notifRepo.UnreadCount(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get unread count", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"unread_count": count}, nil)
}

// Delete handles DELETE /notifications/:id
func (h *Handler) Delete(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	notifID := c.Params("id")

	if notifID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Notification ID required", nil)
	}

	if err := h.notifRepo.Delete(c.Context(), notifID, userID); err != nil {
		if err == repository.ErrNotificationNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Notification not found", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to delete notification", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Notification deleted"}, nil)
}
