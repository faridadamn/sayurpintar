package transaction

import (
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/utils"
)

type Handler struct {
	repo repository.TransactionRepository
}

type createTransactionRequest struct {
	PelangganID   *uuid.UUID               `json:"pelanggan_id"`
	OrderID       *uuid.UUID               `json:"order_id"`
	DebtID        *uuid.UUID               `json:"debt_id"`
	Type          models.TransactionType   `json:"type"`
	Amount        float64                  `json:"amount"`
	PaymentMethod models.PaymentMethod     `json:"payment_method"`
	Status        models.TransactionStatus `json:"status"`
	Notes         *string                  `json:"notes"`
}

func NewHandler(repo repository.TransactionRepository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) GetTransactions(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	if _, err := uuid.Parse(pedagangID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authenticated user", nil)
	}

	from := strings.TrimSpace(c.Query("from"))
	to := strings.TrimSpace(c.Query("to"))
	if !validOptionalDate(from) || !validOptionalDate(to) {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "from and to must use YYYY-MM-DD format", nil)
	}
	if from != "" && to != "" && from > to {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "from must not be after to", nil)
	}

	txns, err := h.repo.ListByPedagang(c.UserContext(), pedagangID, from, to)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to load transactions", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusOK, txns, nil)
}

func (h *Handler) CreateTransaction(c *fiber.Ctx) error {
	pedagangID, err := uuid.Parse(middleware.GetUserID(c))
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authenticated user", nil)
	}

	var req createTransactionRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", nil)
	}
	if err := validateCreateRequest(req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}
	if req.Status == "" {
		req.Status = models.TxnStatusCompleted
	}

	txn := &models.Transaction{
		PedagangID:    pedagangID,
		PelangganID:   req.PelangganID,
		OrderID:       req.OrderID,
		DebtID:        req.DebtID,
		Type:          req.Type,
		Amount:        req.Amount,
		PaymentMethod: req.PaymentMethod,
		Status:        req.Status,
		Notes:         req.Notes,
	}
	if err := h.repo.Create(c.UserContext(), txn); err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to create transaction", nil)
	}
	return utils.SuccessResponse(c, fiber.StatusCreated, txn, nil)
}

func (h *Handler) GetTransactionSummary(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	if _, err := uuid.Parse(pedagangID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Invalid authenticated user", nil)
	}

	date := strings.TrimSpace(c.Query("date", time.Now().Format("2006-01-02")))
	if !validOptionalDate(date) {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "date must use YYYY-MM-DD format", nil)
	}

	omset, err := h.repo.GetDailyTotal(c.UserContext(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to calculate revenue", nil)
	}
	modal, err := h.repo.GetDailyExpenseTotal(c.UserContext(), pedagangID, date)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to calculate expenses", nil)
	}

	untung := omset - modal
	margin := 0.0
	if omset > 0 {
		margin = untung / omset * 100
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"date":   date,
		"omset":  omset,
		"modal":  modal,
		"untung": untung,
		"margin": margin,
	}, nil)
}

func validOptionalDate(value string) bool {
	if value == "" {
		return true
	}
	_, err := time.Parse("2006-01-02", value)
	return err == nil
}

func validateCreateRequest(req createTransactionRequest) error {
	validType := req.Type == models.TxnTypeSale || req.Type == models.TxnTypePurchase || req.Type == models.TxnTypeExpense || req.Type == models.TxnTypePayment || req.Type == models.TxnTypeRefund
	if !validType {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid transaction type")
	}
	if req.Amount <= 0 {
		return fiber.NewError(fiber.StatusBadRequest, "amount must be greater than zero")
	}
	validMethod := req.PaymentMethod == models.PayMethodCash || req.PaymentMethod == models.PayMethodQRIS || req.PaymentMethod == models.PayMethodTransfer || req.PaymentMethod == models.PayMethodEWallet
	if !validMethod {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid payment method")
	}
	if req.Status != "" && req.Status != models.TxnStatusCompleted && req.Status != models.TxnStatusPending && req.Status != models.TxnStatusFailed && req.Status != models.TxnStatusRefunded {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid transaction status")
	}
	return nil
}
