package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// Point values for different actions.
const (
	PointsPriceSubmission  = 1  // per price submission
	PointsOrderCompleted   = 2  // per order delivered
	PointsRouteOptimized   = 5  // per route optimization
	PointsProfileComplete  = 10 // one-time
	PointsSubscriberGained = 15 // when a customer subscribes
	Points7DayStreak       = 20 // 7 days of price submissions
)

// Badge represents a user's reward badge level.
type Badge struct {
	Level        string `json:"level"`
	Name         string `json:"name"`
	Icon         string `json:"icon"`
	MinPoints    int    `json:"min_points"`
	MaxPoints    int    `json:"max_points"`
	NextLevel    string `json:"next_level,omitempty"`
	PointsToNext int    `json:"points_to_next,omitempty"`
}

// BadgeLevels defines all badge tiers.
var BadgeLevels = []Badge{
	{Level: "pemula", Name: "Pemula", Icon: "🌱", MinPoints: 0, MaxPoints: 49},
	{Level: "aktif", Name: "Aktif", Icon: "🌿", MinPoints: 50, MaxPoints: 149},
	{Level: "rajin", Name: "Rajin", Icon: "🌳", MinPoints: 150, MaxPoints: 499},
	{Level: "master", Name: "Master Sayur", Icon: "🏆", MinPoints: 500, MaxPoints: 999},
	{Level: "legend", Name: "Legend Pasar", Icon: "👑", MinPoints: 1000, MaxPoints: 999999},
}

// PointTransaction represents a single point transaction.
type PointTransaction struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Amount    int       `json:"amount"`
	Balance   int       `json:"balance"`
	Reason    string    `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

// RewardService handles gamification and reward points.
type RewardService struct {
	userRepo repository.UserRepository
	redis    *redis.Client
	logger   *zap.Logger
}

// NewRewardService creates a new RewardService.
func NewRewardService(userRepo repository.UserRepository, redis *redis.Client, logger *zap.Logger) *RewardService {
	return &RewardService{
		userRepo: userRepo,
		redis:    redis,
		logger:   logger.Named("reward"),
	}
}

// Redis key helpers.
func rewardBalanceKey(userID string) string {
	return fmt.Sprintf("reward:balance:%s", userID)
}

func rewardHistoryKey(userID string) string {
	return fmt.Sprintf("reward:history:%s", userID)
}

func rewardStreakKey(userID string) string {
	return fmt.Sprintf("reward:streak:%s", userID)
}

// AddPoints adds points to a user's balance and records the transaction.
func (s *RewardService) AddPoints(ctx context.Context, userID string, amount int, reason string) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}

	balanceKey := rewardBalanceKey(userID)
	historyKey := rewardHistoryKey(userID)

	// Increment balance atomically
	newBalance, err := s.redis.IncrBy(ctx, balanceKey, int64(amount)).Result()
	if err != nil {
		return fmt.Errorf("increment balance: %w", err)
	}

	// Record transaction in a sorted set (score = timestamp for ordering)
	now := time.Now()
	txn := fmt.Sprintf(`{"user_id":"%s","amount":%d,"balance":%d,"reason":"%s","created_at":"%s"}`,
		userID, amount, newBalance, reason, now.Format(time.RFC3339))

	member := redis.Z{
		Score:  float64(now.UnixMilli()),
		Member: txn,
	}

	if err := s.redis.ZAdd(ctx, historyKey, member).Err(); err != nil {
		s.logger.Warn("failed to record point transaction",
			zap.String("user_id", userID),
			zap.Error(err),
		)
	}

	// Trim history to last 500 entries
	s.redis.ZRemRangeByRank(ctx, historyKey, 0, -501)

	s.logger.Info("points added",
		zap.String("user_id", userID),
		zap.Int("amount", amount),
		zap.Int64("new_balance", newBalance),
		zap.String("reason", reason),
	)

	return nil
}

// GetBalance returns the current point balance for a user.
func (s *RewardService) GetBalance(ctx context.Context, userID string) (int, error) {
	val, err := s.redis.Get(ctx, rewardBalanceKey(userID)).Result()
	if err != nil {
		if err == redis.Nil {
			return 0, nil
		}
		return 0, fmt.Errorf("get balance: %w", err)
	}

	balance, err := strconv.Atoi(val)
	if err != nil {
		return 0, fmt.Errorf("parse balance: %w", err)
	}

	return balance, nil
}

// GetHistory returns point transaction history for a user, most recent first.
func (s *RewardService) GetHistory(ctx context.Context, userID string, limit int) ([]PointTransaction, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	historyKey := rewardHistoryKey(userID)

	// Get latest entries (highest score = most recent)
	results, err := s.redis.ZRevRange(ctx, historyKey, 0, int64(limit-1)).Result()
	if err != nil {
		return nil, fmt.Errorf("get history: %w", err)
	}

	transactions := make([]PointTransaction, 0, len(results))
	for _, raw := range results {
		txn, err := parsePointTransaction(raw, userID)
		if err != nil {
			s.logger.Warn("failed to parse point transaction", zap.String("raw", raw), zap.Error(err))
			continue
		}
		transactions = append(transactions, txn)
	}

	return transactions, nil
}

// GetBadge returns the user's current badge level based on their points.
func (s *RewardService) GetBadge(ctx context.Context, userID string) (*Badge, error) {
	balance, err := s.GetBalance(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get balance for badge: %w", err)
	}

	badge := findBadgeForPoints(balance)

	// Set next level info
	if badge.Level != "legend" {
		for i, b := range BadgeLevels {
			if b.Level == badge.Level && i+1 < len(BadgeLevels) {
				next := BadgeLevels[i+1]
				badge.NextLevel = next.Name
				badge.PointsToNext = next.MinPoints - balance
				break
			}
		}
	}

	return badge, nil
}

// CheckStreak checks if user has a consecutive daily submission streak.
// Returns the current streak count (number of consecutive days with submissions).
func (s *RewardService) CheckStreak(ctx context.Context, userID string) (int, error) {
	streakKey := rewardStreakKey(userID)

	// Get all streak entries (date → 1)
	members, err := s.redis.ZRangeByScore(ctx, streakKey, &redis.ZRangeByScore{
		Min: "-inf",
		Max: "+inf",
	}).Result()
	if err != nil {
		return 0, fmt.Errorf("get streak: %w", err)
	}

	if len(members) == 0 {
		return 0, nil
	}

	// Parse dates and count consecutive days ending today or yesterday
	dates := make([]time.Time, 0, len(members))
	for _, m := range members {
		d, err := time.Parse("2006-01-02", m)
		if err != nil {
			continue
		}
		dates = append(dates, d)
	}

	if len(dates) == 0 {
		return 0, nil
	}

	// Sort descending
	sortDatesDesc(dates)

	today := time.Now().Truncate(24 * time.Hour)
	yesterday := today.AddDate(0, 0, -1)

	// Streak must include today or yesterday
	if !dates[0].Equal(today) && !dates[0].Equal(yesterday) {
		return 0, nil
	}

	streak := 1
	for i := 1; i < len(dates); i++ {
		expected := dates[i-1].AddDate(0, 0, -1)
		if dates[i].Equal(expected) {
			streak++
		} else {
			break
		}
	}

	return streak, nil
}

// RecordStreakDay records that a user submitted a price today (for streak tracking).
func (s *RewardService) RecordStreakDay(ctx context.Context, userID string) error {
	streakKey := rewardStreakKey(userID)
	today := time.Now().Format("2006-01-02")

	member := redis.Z{
		Score:  float64(time.Now().UnixMilli()),
		Member: today,
	}

	if err := s.redis.ZAdd(ctx, streakKey, member).Err(); err != nil {
		return fmt.Errorf("record streak day: %w", err)
	}

	// Check if streak hit 7 days
	streak, err := s.CheckStreak(ctx, userID)
	if err != nil {
		return fmt.Errorf("check streak: %w", err)
	}

	if streak == 7 {
		// Award streak bonus (idempotent: check if already awarded)
		bonusKey := fmt.Sprintf("reward:streak_bonus:%s:%s", userID, today)
		set, err := s.redis.SetNX(ctx, bonusKey, "1", 24*time.Hour).Result()
		if err != nil {
			return fmt.Errorf("check streak bonus: %w", err)
		}
		if set {
			if err := s.AddPoints(ctx, userID, Points7DayStreak, "Streak 7 hari! 🔥"); err != nil {
				s.logger.Warn("failed to add streak bonus", zap.String("user_id", userID), zap.Error(err))
			}
		}
	}

	return nil
}

// ── Helpers ────────────────────────────────────────────────────────────────

// findBadgeForPoints returns the appropriate badge for the given point balance.
func findBadgeForPoints(points int) *Badge {
	for i := len(BadgeLevels) - 1; i >= 0; i-- {
		if points >= BadgeLevels[i].MinPoints {
			b := BadgeLevels[i]
			return &Badge{
				Level:     b.Level,
				Name:      b.Name,
				Icon:      b.Icon,
				MinPoints: b.MinPoints,
				MaxPoints: b.MaxPoints,
			}
		}
	}
	b := BadgeLevels[0]
	return &Badge{
		Level:     b.Level,
		Name:      b.Name,
		Icon:      b.Icon,
		MinPoints: b.MinPoints,
		MaxPoints: b.MaxPoints,
	}
}

// parsePointTransaction parses a JSON string into a PointTransaction.
func parsePointTransaction(raw string, userID string) (PointTransaction, error) {
	var txn PointTransaction
	type rawTxn struct {
		UserID    string `json:"user_id"`
		Amount    int    `json:"amount"`
		Balance   int    `json:"balance"`
		Reason    string `json:"reason"`
		CreatedAt string `json:"created_at"`
	}
	var rt rawTxn
	if err := json.Unmarshal([]byte(raw), &rt); err != nil {
		return txn, fmt.Errorf("parse transaction: %w", err)
	}
	txn.UserID = rt.UserID
	txn.Amount = rt.Amount
	txn.Balance = rt.Balance
	txn.Reason = rt.Reason
	txn.CreatedAt, _ = time.Parse(time.RFC3339, rt.CreatedAt)
	txn.ID = fmt.Sprintf("txn_%s_%d", rt.UserID, txn.CreatedAt.UnixMilli())
	return txn, nil
}

// sortDatesDesc sorts dates in descending order (most recent first) using insertion sort.
func sortDatesDesc(dates []time.Time) {
	for i := 1; i < len(dates); i++ {
		key := dates[i]
		j := i - 1
		for j >= 0 && dates[j].Before(key) {
			dates[j+1] = dates[j]
			j--
		}
		dates[j+1] = key
	}
}
