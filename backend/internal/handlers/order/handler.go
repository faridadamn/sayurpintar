package order

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler handles order HTTP requests.
type Handler struct {
	orderService *services.OrderService
}

// NewHandler creates a new order Handler.
func NewHandler(orderService *services.OrderService) *Handler {
	return &Handler{
		orderService: orderService,
	}
}

// GetTodayOrders returns today's orders for the authenticated pedagang.
// GET /orders/today
func (h *Handler) GetTodayOrders(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	orders, err := h.orderService.GetTodayOrders(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get today's orders", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, orders, nil)
}

// GetOrder returns a single order by ID.
// GET /orders/:id
func (h *Handler) GetOrder(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	order, err := h.orderService.GetOrderDetail(c.Context(), orderID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Order not found", err.Error())
	}

	// Authorization: only pedagang (owner) or pelanggan (customer) can view
	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)
	if role == "pedagang" && order.PedagangID != userID {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Access denied", nil)
	}
	if role == "pelanggan" && order.PelangganID != userID {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Access denied", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, order, nil)
}

// UpdateOrderStatus updates the status of an order.
// PATCH /orders/:id/status
func (h *Handler) UpdateOrderStatus(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	var body struct {
		Status string `json:"status"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Status == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Status is required", nil)
	}

	if err := h.orderService.UpdateOrderStatus(c.Context(), orderID, body.Status); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to update order status", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Order status updated",
	}, nil)
}

// MarkDelivered marks an order as delivered.
// POST /orders/:id/deliver
func (h *Handler) MarkDelivered(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	if err := h.orderService.MarkDelivered(c.Context(), orderID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to mark delivered", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Order marked as delivered",
	}, nil)
}

// CancelOrder cancels an order with a reason.
// POST /orders/:id/cancel
func (h *Handler) CancelOrder(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	var body struct {
		Reason string `json:"reason"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if err := h.orderService.CancelOrder(c.Context(), orderID, body.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to cancel order", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Order cancelled",
	}, nil)
}

// AddRating adds a customer rating to a delivered order.
// POST /orders/:id/rate
func (h *Handler) AddRating(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	var body struct {
		Rating  int    `json:"rating"`
		Comment string `json:"comment"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Rating < 1 || body.Rating > 5 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Rating must be between 1 and 5", nil)
	}

	// Only pelanggan can rate
	role := middleware.GetUserRole(c)
	if role != "pelanggan" {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Only customers can rate orders", nil)
	}

	if err := h.orderService.AddRating(c.Context(), orderID, body.Rating, body.Comment); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to add rating", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Rating submitted",
	}, nil)
}

// GetOrderSummary returns daily order summary for a pedagang.
// GET /orders/summary?date=2026-07-16
func (h *Handler) GetOrderSummary(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	date := c.Query("date", "")

	summary, err := h.orderService.GetOrderSummary(c.Context(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get order summary", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, summary, nil)
}

// CreateOneTimeOrder creates a non-subscription order.
// POST /orders/one-time
func (h *Handler) CreateOneTimeOrder(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	var body struct {
		PelangganID  string            `json:"pelanggan_id"`
		Items        []models.OrderItem `json:"items"`
		DeliveryDate string            `json:"delivery_date"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.PelangganID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "pelanggan_id is required", nil)
	}
	if len(body.Items) == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "At least one item is required", nil)
	}

	order, err := h.orderService.CreateOneTimeOrder(
		c.Context(), pedagangID, body.PelangganID, body.Items, body.DeliveryDate,
	)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to create order", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, order, nil)
}

// ListByPedagangAndDate returns orders for a pedagang on a date.
// GET /orders?date=2026-07-16
func (h *Handler) ListByPedagangAndDate(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	date := c.Query("date", "")

	orders, err := h.orderService.ListByPedagangAndDate(c.Context(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list orders", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, orders, nil)
}

// ListByPelanggan returns recent orders for the authenticated pelanggan.
// GET /orders/my?limit=20
func (h *Handler) ListByPelanggan(c *fiber.Ctx) error {
	pelangganID := middleware.GetUserID(c)
	limitStr := c.Query("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 20
	}

	orders, err := h.orderService.ListByPelanggan(c.Context(), pelangganID, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list orders", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, orders, nil)
}

// UpdatePayment updates the payment status of an order.
// PATCH /orders/:id/payment
func (h *Handler) UpdatePayment(c *fiber.Ctx) error {
	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order ID is required", nil)
	}

	var body struct {
		PaymentStatus string `json:"payment_status"`
		PaymentMethod string `json:"payment_method"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.PaymentStatus == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "payment_status is required", nil)
	}

	if err := h.orderService.UpdatePayment(c.Context(), orderID, body.PaymentStatus, body.PaymentMethod); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to update payment", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Payment updated",
	}, nil)
}

// ── Legacy stubs (kept for backward compatibility) ──

// GetOrders is a legacy endpoint — redirects to ListByPedagangAndDate.
func (h *Handler) GetOrders(c *fiber.Ctx) error {
	return h.ListByPedagangAndDate(c)
}

// RateOrder is a legacy endpoint — redirects to AddRating.
func (h *Handler) RateOrder(c *fiber.Ctx) error {
	return h.AddRating(c)
}
