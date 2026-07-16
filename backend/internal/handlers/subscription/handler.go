package subscription

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler handles subscription-related HTTP requests.
type Handler struct {
	subService *services.SubscriptionService
}

// NewHandler creates a subscription Handler.
func NewHandler(subService *services.SubscriptionService) *Handler {
	return &Handler{subService: subService}
}

// --- Package endpoints (stubs — implemented by the package-management agent) ---

// GetPackages lists all subscription packages.
func (h *Handler) GetPackages(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, []interface{}{}, nil)
}

// CreatePackage creates a new subscription package.
func (h *Handler) CreatePackage(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusCreated, fiber.Map{"message": "Package created"}, nil)
}

// GetPackage returns a single subscription package.
func (h *Handler) GetPackage(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Package detail"}, nil)
}

// UpdatePackage updates a subscription package.
func (h *Handler) UpdatePackage(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Package updated"}, nil)
}

// DeletePackage deletes a subscription package.
func (h *Handler) DeletePackage(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Package deleted"}, nil)
}

// --- Subscription lifecycle endpoints ---

// Subscribe creates a new subscription for the authenticated pelanggan.
func (h *Handler) Subscribe(c *fiber.Ctx) error {
	pelangganID, ok := c.Locals("user_id").(string)
	if !ok || pelangganID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	var req services.SubscribeRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", nil)
	}

	sub, err := h.subService.Subscribe(c.Context(), pelangganID, req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, sub, nil)
}

// GetActiveSubscriptions returns all active subscriptions for the authenticated user.
func (h *Handler) GetActiveSubscriptions(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	role, _ := c.Locals("role").(string)
	if role == "" {
		role = "pelanggan"
	}

	subs, err := h.subService.GetActiveSubscriptions(c.Context(), userID, role)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, subs, nil)
}

// GetMySubscriptions returns all active subscriptions for the authenticated user (alias).
func (h *Handler) GetMySubscriptions(c *fiber.Ctx) error {
	return h.GetActiveSubscriptions(c)
}

// GetSubscription returns subscription detail.
func (h *Handler) GetSubscription(c *fiber.Ctx) error {
	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	detail, err := h.subService.GetSubscriptionDetail(c.Context(), subscriptionID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, detail, nil)
}

// GetSubscriptionDetail returns subscription detail with package info and delivery history.
func (h *Handler) GetSubscriptionDetail(c *fiber.Ctx) error {
	return h.GetSubscription(c)
}

// PauseSubscription pauses an active subscription.
func (h *Handler) PauseSubscription(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.BodyParser(&body)

	if err := h.subService.PauseSubscription(c.Context(), subscriptionID, userID, body.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Subscription paused"}, nil)
}

// ResumeSubscription resumes a paused subscription.
func (h *Handler) ResumeSubscription(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	if err := h.subService.ResumeSubscription(c.Context(), subscriptionID, userID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Subscription resumed"}, nil)
}

// CancelSubscription cancels a subscription.
func (h *Handler) CancelSubscription(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	var body struct {
		Reason string `json:"reason"`
	}
	_ = c.BodyParser(&body)

	if err := h.subService.CancelSubscription(c.Context(), subscriptionID, userID, body.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Subscription cancelled"}, nil)
}

// --- Modification endpoints ---

// ModifyDelivery modifies items for the next delivery.
func (h *Handler) ModifyDelivery(c *fiber.Ctx) error {
	userID, ok := c.Locals("user_id").(string)
	if !ok || userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	var req services.ModifyRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", nil)
	}

	if err := h.subService.ModifyNextDelivery(c.Context(), subscriptionID, userID, req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Next delivery modified"}, nil)
}

// ModifyNextDelivery modifies items for the next delivery (alias).
func (h *Handler) ModifyNextDelivery(c *fiber.Ctx) error {
	return h.ModifyDelivery(c)
}

// ListModifications lists recent modifications for a subscription.
func (h *Handler) ListModifications(c *fiber.Ctx) error {
	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	detail, err := h.subService.GetSubscriptionDetail(c.Context(), subscriptionID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, detail.Modifications, nil)
}

// DeleteModification deletes a subscription modification (not yet implemented).
func (h *Handler) DeleteModification(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Not implemented", nil)
}

// --- Additional endpoints ---

// GetUpcomingDeliveries returns upcoming delivery dates for a subscription.
func (h *Handler) GetUpcomingDeliveries(c *fiber.Ctx) error {
	subscriptionID := c.Params("id")
	if subscriptionID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Subscription ID required", nil)
	}

	count := c.QueryInt("count", 5)

	dates, err := h.subService.GetUpcomingDeliveries(c.Context(), subscriptionID, count)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, dates, nil)
}

// GetSubscriberStats returns subscription stats for the authenticated pedagang.
func (h *Handler) GetSubscriberStats(c *fiber.Ctx) error {
	pedagangID, ok := c.Locals("user_id").(string)
	if !ok || pedagangID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Unauthorized", nil)
	}

	stats, err := h.subService.GetSubscriberStats(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, stats, nil)
}

// --- Order endpoints (stubs) ---

// GetTodayOrders returns orders for today.
func (h *Handler) GetTodayOrders(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, []interface{}{}, nil)
}

// UpdateOrderStatus updates an order's status.
func (h *Handler) UpdateOrderStatus(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{"message": "Order status updated"}, nil)
}
