package transaction

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/utils"
)

type Handler struct{}

func NewHandler() *Handler {
	return &Handler{}
}

func (h *Handler) GetTransactions(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, []interface{}{}, nil)
}

func (h *Handler) CreateTransaction(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusCreated, fiber.Map{"message": "Transaction created"}, nil)
}

func (h *Handler) GetTransactionSummary(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"omset":  0,
		"modal":  0,
		"untung": 0,
		"margin": 0,
	}, nil)
}
