package payment

import (
	"github.com/gofiber/fiber/v2"
)

// RegisterRoutes registers all payment-related endpoints on the Fiber router.
// Webhook endpoints are registered WITHOUT auth (Midtrans calls them).
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	payments := app.Group("/payments")

	// ── Webhook (no auth — called by Midtrans) ──
	payments.Post("/webhook/midtrans", handler.HandleMidtransWebhook)

	// ── Protected endpoints ──
	protected := payments.Group("", authMiddleware)

	// Create payment transaction
	protected.Post("/create", handler.CreatePayment)

	// Manual payment confirmation (cash)
	protected.Post("/confirm", handler.ConfirmPayment)

	// Check payment status
	protected.Get("/:id/status", handler.GetPaymentStatus)

	// Download PDF invoice
	protected.Get("/:id/invoice", handler.GetInvoice)
}
