package payment

import (
	"io"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler exposes the payment HTTP endpoints. Dependencies are accepted
// variadically to keep a single constructor while the legacy payment flows are
// consolidated. Known payment services are detected by type.
type Handler struct {
	gateway *services.PaymentGateway
	service *services.PaymentService
}

func NewHandler(deps ...interface{}) *Handler {
	h := &Handler{}
	for _, dep := range deps {
		switch v := dep.(type) {
		case *services.PaymentGateway:
			h.gateway = v
		case *services.PaymentService:
			h.service = v
		}
	}
	return h
}

func (h *Handler) HandleMidtransWebhook(c *fiber.Ctx) error {
	if h.gateway == nil {
		return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "Payment gateway is not configured", nil)
	}

	payload := c.Body()
	if len(payload) == 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Webhook payload is required", nil)
	}

	result, err := h.gateway.HandleNotification(c.UserContext(), payload)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid payment notification", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, result, nil)
}

func (h *Handler) CreatePayment(c *fiber.Ctx) error {
	if h.gateway == nil {
		return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "Payment gateway is not configured", nil)
	}

	var req services.TransactionRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid payment request", nil)
	}
	if req.OrderID == "" || req.GrossAmount <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "order_id and positive gross_amount are required", nil)
	}

	result, err := h.gateway.CreateTransaction(c.UserContext(), req)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadGateway, "Unable to create payment", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusCreated, result, nil)
}

func (h *Handler) ConfirmPayment(c *fiber.Ctx) error {
	if h.service == nil {
		return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Manual payment confirmation is not available on this payment flow", nil)
	}
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Use the debt payment endpoint for manual confirmation", nil)
}

func (h *Handler) GetPaymentStatus(c *fiber.Ctx) error {
	if h.gateway == nil {
		return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "Payment gateway is not configured", nil)
	}

	id := c.Params("id")
	if id == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Payment id is required", nil)
	}
	result, err := h.gateway.GetTransactionStatus(c.UserContext(), id)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadGateway, "Unable to retrieve payment status", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusOK, result, nil)
}

func (h *Handler) GetInvoice(c *fiber.Ctx) error {
	// Invoice generation needs the order ownership-aware service to be exposed
	// through a stable interface. Do not return a fake PDF.
	c.Set(fiber.HeaderContentType, fiber.MIMETextPlainCharsetUTF8)
	c.Status(fiber.StatusNotImplemented)
	_, _ = io.WriteString(c, "Invoice generation is not available yet")
	return nil
}
