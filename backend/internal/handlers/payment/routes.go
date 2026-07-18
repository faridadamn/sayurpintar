package payment

import "github.com/gofiber/fiber/v2"

// RegisterRoutes registers payment endpoints.
// Midtrans webhook is public; all user-facing endpoints require authentication.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	payments := app.Group("/payments")
	payments.Post("/webhook/midtrans", handler.HandleMidtransWebhook)

	protected := payments.Group("", authMiddleware)
	protected.Post("/create", handler.CreatePayment)
	protected.Get("/:id/status", handler.GetPaymentStatus)
	protected.Get("/:id/invoice", handler.GetInvoice)
}
