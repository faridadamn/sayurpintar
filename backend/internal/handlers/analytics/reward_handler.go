package analytics

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// RewardHandler handles reward/gamification HTTP requests.
type RewardHandler struct {
	rewardService *services.RewardService
}

// NewRewardHandler creates a new RewardHandler.
func NewRewardHandler(rewardService *services.RewardService) *RewardHandler {
	return &RewardHandler{
		rewardService: rewardService,
	}
}

// GetBalance returns the authenticated user's point balance.
// GET /rewards/balance
func (h *RewardHandler) GetBalance(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	balance, err := h.rewardService.GetBalance(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get reward balance", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"user_id": userID,
		"balance": balance,
	}, nil)
}

// GetHistory returns the user's point transaction history.
// GET /rewards/history?limit=20
func (h *RewardHandler) GetHistory(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	limit := 20
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	history, err := h.rewardService.GetHistory(c.Context(), userID, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get reward history", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, history, nil)
}

// GetBadge returns the user's badge/achievement info.
// GET /rewards/badge
func (h *RewardHandler) GetBadge(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	badge, err := h.rewardService.GetBadge(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get badge info", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, badge, nil)
}

// GetStreak returns the user's submission streak.
// GET /rewards/streak
func (h *RewardHandler) GetStreak(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)

	streak, err := h.rewardService.CheckStreak(c.Context(), userID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get streak info", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"user_id":         userID,
		"current_streak":  streak,
		"next_reward_at":  7,
	}, nil)
}

// RegisterRewardRoutes registers reward endpoints on the given router.
func RegisterRewardRoutes(app fiber.Router, rewardHandler *RewardHandler, authMiddleware fiber.Handler) {
	rewards := app.Group("/rewards", authMiddleware)

	rewards.Get("/balance", rewardHandler.GetBalance)
	rewards.Get("/history", rewardHandler.GetHistory)
	rewards.Get("/badge", rewardHandler.GetBadge)
	rewards.Get("/streak", rewardHandler.GetStreak)
}
