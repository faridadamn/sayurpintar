package debt

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler handles debt (piutang) HTTP requests.
type Handler struct {
	debtService *services.DebtService
}

// NewHandler creates a new debt Handler.
func NewHandler(debtService *services.DebtService) *Handler {
	return &Handler{
		debtService: debtService,
	}
}

// RegisterRoutes registers all debt-related endpoints on the Fiber router.
func RegisterRoutes(app fiber.Router, handler *Handler, authMiddleware fiber.Handler) {
	debts := app.Group("/debts", authMiddleware)

	// Summary
	debts.Get("/summary", middleware.RequireRole("pedagang"), handler.GetSummary)

	// List debts
	debts.Get("/", middleware.RequireRole("pedagang"), handler.ListDebts)

	// Create debt
	debts.Post("/", middleware.RequireRole("pedagang"), handler.CreateDebt)

	// Single debt
	debts.Get("/:id", handler.GetDebt)

	// Record payment
	debts.Put("/:id/pay", middleware.RequireRole("pedagang"), handler.RecordPayment)

	// Send reminder
	debts.Post("/:id/remind", middleware.RequireRole("pedagang"), handler.SendReminder)

	// Write off
	debts.Put("/:id/write-off", middleware.RequireRole("pedagang"), handler.WriteOff)
}

// GetSummary returns piutang summary for the authenticated pedagang.
// GET /debts/summary
func (h *Handler) GetSummary(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	summary, err := h.debtService.GetSummary(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get piutang summary", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, summary, nil)
}

// ListDebts returns debts for the authenticated pedagang.
// GET /debts?status=outstanding
func (h *Handler) ListDebts(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	status := c.Query("status", "")

	debts, err := h.debtService.ListDebts(c.Context(), pedagangID, status)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list debts", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, debts, nil)
}

// CreateDebt records a new debt.
// POST /debts
func (h *Handler) CreateDebt(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	var body struct {
		PelangganID string  `json:"pelanggan_id"`
		OrderID     string  `json:"order_id,omitempty"`
		Amount      float64 `json:"amount"`
		DueDate     string  `json:"due_date,omitempty"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.PelangganID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "pelanggan_id is required", nil)
	}
	if body.Amount <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "amount must be greater than 0", nil)
	}

	var dueDate *time.Time
	if body.DueDate != "" {
		t, err := time.Parse("2006-01-02", body.DueDate)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid due_date format (use YYYY-MM-DD)", err.Error())
		}
		dueDate = &t
	}

	debt, err := h.debtService.CreateDebt(c.Context(), pedagangID, body.PelangganID, body.OrderID, body.Amount, dueDate)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to create debt", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, debt, nil)
}

// GetDebt returns a single debt by ID.
// GET /debts/:id
func (h *Handler) GetDebt(c *fiber.Ctx) error {
	debtID := c.Params("id")
	if debtID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Debt ID is required", nil)
	}

	debt, err := h.debtService.GetDebt(c.Context(), debtID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusNotFound, "Debt not found", err.Error())
	}

	// Authorization: only pedagang (owner) can view
	userID := middleware.GetUserID(c)
	role := middleware.GetUserRole(c)
	if role == "pedagang" && debt.PedagangID.String() != userID {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Access denied", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, debt, nil)
}

// RecordPayment records a payment against a debt.
// PUT /debts/:id/pay
func (h *Handler) RecordPayment(c *fiber.Ctx) error {
	debtID := c.Params("id")
	if debtID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Debt ID is required", nil)
	}

	var body struct {
		Amount float64 `json:"amount"`
		Method string  `json:"method"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Amount <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "amount must be greater than 0", nil)
	}
	if body.Method == "" {
		body.Method = "cash"
	}

	if err := h.debtService.RecordPayment(c.Context(), debtID, body.Amount, body.Method); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to record payment", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Payment recorded successfully",
	}, nil)
}

// SendReminder sends a WhatsApp reminder for a debt.
// POST /debts/:id/remind
func (h *Handler) SendReminder(c *fiber.Ctx) error {
	debtID := c.Params("id")
	if debtID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Debt ID is required", nil)
	}

	if err := h.debtService.SendReminder(c.Context(), debtID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to send reminder", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Reminder sent successfully",
	}, nil)
}

// WriteOff marks a debt as uncollectable.
// PUT /debts/:id/write-off
func (h *Handler) WriteOff(c *fiber.Ctx) error {
	debtID := c.Params("id")
	if debtID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Debt ID is required", nil)
	}

	var body struct {
		Reason string `json:"reason"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Reason == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "reason is required", nil)
	}

	if err := h.debtService.WriteOff(c.Context(), debtID, body.Reason); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to write off debt", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Debt written off successfully",
	}, nil)
}
