package payment

import (
	"fmt"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler exposes Midtrans payment and invoice endpoints.
type Handler struct {
	gateway *services.PaymentGateway
	invoice *services.InvoiceService
}

// NewHandler creates a payment handler with explicit required dependencies.
func NewHandler(gateway *services.PaymentGateway, invoice *services.InvoiceService) *Handler {
	return &Handler{
		gateway: gateway,
		invoice: invoice,
	}
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
	if h.invoice == nil {
		return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "Invoice service is not configured", nil)
	}

	orderID := c.Params("id")
	if orderID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Order id is required", nil)
	}

	pdf, err := h.invoice.GenerateInvoice(c.UserContext(), orderID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Invoice could not be generated", nil)
	}

	c.Set(fiber.HeaderContentType, "application/pdf")
	c.Set(fiber.HeaderContentDisposition, fmt.Sprintf(`attachment; filename="invoice-%s.pdf"`, orderID))
	return c.Send(pdf)
}
