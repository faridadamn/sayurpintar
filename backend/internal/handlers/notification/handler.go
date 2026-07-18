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

// List handles GET /notifications.
func (h *Handler) List(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	limit, err := strconv.Atoi(c.Query("limit", "20"))
	if err != nil || limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	unreadOnly := c.Query("unread", "false") == "true"
	notifs, err := h.notifRepo.ListByUser(c.Context(), userID, unreadOnly, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list notifications", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, notifs, nil)
}

// MarkAsRead handles PUT /notifications/:id/read.
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

// MarkAllAsRead handles PUT /notifications/read-all.
func (h *Handler) MarkAllAsRead(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	if err := h.notifRepo.MarkAllAsRead(c.Context(), userID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to mark all as read", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "All notifications marked as read",
	}, nil)
}

// GetUnreadCount handles GET /notifications/unread-count.
func (h *Handler) GetUnreadCount(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	count, err := h.notifRepo.GetUnreadCount(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get unread count", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"unread_count": count}, nil)
}

// Delete handles DELETE /notifications/:id.
func (h *Handler) Delete(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	notifID := c.Params("id")

	if notifID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Notification ID required", nil)
	}

	notif, err := h.notifRepo.GetByID(c.Context(), notifID)
	if err != nil {
		if err == repository.ErrNotificationNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Notification not found", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to delete notification", nil)
	}
	if notif.UserID != userID {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Notification not found", nil)
	}

	if err := h.notifRepo.Delete(c.Context(), notifID); err != nil {
		if err == repository.ErrNotificationNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Notification not found", nil)
		}
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to delete notification", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Notification deleted"}, nil)
}
