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
	PointsPriceSubmission  = 1
	PointsOrderCompleted   = 2
	PointsRouteOptimized   = 5
	PointsProfileComplete  = 10
	PointsSubscriberGained = 15
	Points7DayStreak       = 20
)

type Badge struct {
	Level        string `json:"level"`
	Name         string `json:"name"`
	Icon         string `json:"icon"`
	MinPoints    int    `json:"min_points"`
	MaxPoints    int    `json:"max_points"`
	NextLevel    string `json:"next_level,omitempty"`
	PointsToNext int    `json:"points_to_next,omitempty"`
}

var BadgeLevels = []Badge{
	{Level: "pemula", Name: "Pemula", Icon: "🌱", MinPoints: 0, MaxPoints: 49},
	{Level: "aktif", Name: "Aktif", Icon: "🌿", MinPoints: 50, MaxPoints: 149},
	{Level: "rajin", Name: "Rajin", Icon: "🌳", MinPoints: 150, MaxPoints: 499},
	{Level: "master", Name: "Master Sayur", Icon: "🏆", MinPoints: 500, MaxPoints: 999},
	{Level: "legend", Name: "Legend Pasar", Icon: "👑", MinPoints: 1000, MaxPoints: 999999},
}

type PointTransaction struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Amount    int       `json:"amount"`
	Balance   int       `json:"balance"`
	Reason    string    `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

type RewardService struct {
	userRepo repository.UserRepository
	redis    *redis.Client
	logger   *zap.Logger
}

func NewRewardService(userRepo repository.UserRepository, redisClient *redis.Client, logger *zap.Logger) *RewardService {
	return &RewardService{userRepo: userRepo, redis: redisClient, logger: logger.Named("reward")}
}

func rewardBalanceKey(userID string) string { return fmt.Sprintf("reward:balance:%s", userID) }
func rewardHistoryKey(userID string) string { return fmt.Sprintf("reward:history:%s", userID) }
func rewardStreakKey(userID string) string { return fmt.Sprintf("reward:streak:%s", userID) }

func (s *RewardService) AddPoints(ctx context.Context, userID string, amount int, reason string) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}
	balanceKey := rewardBalanceKey(userID)
	historyKey := rewardHistoryKey(userID)
	newBalance, err := s.redis.IncrBy(ctx, balanceKey, int64(amount)).Result()
	if err != nil {
		return fmt.Errorf("increment balance: %w", err)
	}
	now := time.Now()
	txn := fmt.Sprintf(`{"user_id":"%s","amount":%d,"balance":%d,"reason":"%s","created_at":"%s"}`,
		userID, amount, newBalance, reason, now.Format(time.RFC3339))
	if err := s.redis.ZAdd(ctx, historyKey, redis.Z{Score: float64(now.UnixMilli()), Member: txn}).Err(); err != nil {
		s.logger.Warn("failed to record point transaction", zap.String("user_id", userID), zap.Error(err))
	}
	s.redis.ZRemRangeByRank(ctx, historyKey, 0, -501)
	return nil
}

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

func (s *RewardService) GetHistory(ctx context.Context, userID string, limit int) ([]PointTransaction, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	results, err := s.redis.ZRevRange(ctx, rewardHistoryKey(userID), 0, int64(limit-1)).Result()
	if err != nil {
		return nil, fmt.Errorf("get history: %w", err)
	}
	transactions := make([]PointTransaction, 0, len(results))
	for _, raw := range results {
		txn, err := parsePointTransaction(raw, userID)
		if err == nil {
			transactions = append(transactions, txn)
		}
	}
	return transactions, nil
}

func (s *RewardService) GetBadge(ctx context.Context, userID string) (*Badge, error) {
	balance, err := s.GetBalance(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get balance for badge: %w", err)
	}
	badge := findBadgeForPoints(balance)
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

func (s *RewardService) CheckStreak(ctx context.Context, userID string) (int, error) {
	members, err := s.redis.ZRangeByScore(ctx, rewardStreakKey(userID), &redis.ZRangeBy{Min: "-inf", Max: "+inf"}).Result()
	if err != nil {
		return 0, fmt.Errorf("get streak: %w", err)
	}
	if len(members) == 0 {
		return 0, nil
	}
	dates := make([]time.Time, 0, len(members))
	for _, m := range members {
		if d, err := time.Parse("2006-01-02", m); err == nil {
			dates = append(dates, d)
		}
	}
	if len(dates) == 0 {
		return 0, nil
	}
	sortDatesDesc(dates)
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	yesterday := today.AddDate(0, 0, -1)
	if !dates[0].Equal(today) && !dates[0].Equal(yesterday) {
		return 0, nil
	}
	streak := 1
	for i := 1; i < len(dates); i++ {
		if dates[i].Equal(dates[i-1].AddDate(0, 0, -1)) {
			streak++
		} else {
			break
		}
	}
	return streak, nil
}

func (s *RewardService) RecordStreakDay(ctx context.Context, userID string) error {
	today := time.Now().Format("2006-01-02")
	if err := s.redis.ZAdd(ctx, rewardStreakKey(userID), redis.Z{Score: float64(time.Now().UnixMilli()), Member: today}).Err(); err != nil {
		return fmt.Errorf("record streak day: %w", err)
	}
	streak, err := s.CheckStreak(ctx, userID)
	if err != nil {
		return fmt.Errorf("check streak: %w", err)
	}
	if streak == 7 {
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

func findBadgeForPoints(points int) *Badge {
	for i := len(BadgeLevels) - 1; i >= 0; i-- {
		if points >= BadgeLevels[i].MinPoints {
			b := BadgeLevels[i]
			return &Badge{Level: b.Level, Name: b.Name, Icon: b.Icon, MinPoints: b.MinPoints, MaxPoints: b.MaxPoints}
		}
	}
	b := BadgeLevels[0]
	return &Badge{Level: b.Level, Name: b.Name, Icon: b.Icon, MinPoints: b.MinPoints, MaxPoints: b.MaxPoints}
}

func parsePointTransaction(raw string, userID string) (PointTransaction, error) {
	var txn PointTransaction
	var rt struct {
		UserID    string `json:"user_id"`
		Amount    int    `json:"amount"`
		Balance   int    `json:"balance"`
		Reason    string `json:"reason"`
		CreatedAt string `json:"created_at"`
	}
	if err := json.Unmarshal([]byte(raw), &rt); err != nil {
		return txn, fmt.Errorf("parse transaction: %w", err)
	}
	txn.UserID = rt.UserID
	if txn.UserID == "" {
		txn.UserID = userID
	}
	txn.Amount = rt.Amount
	txn.Balance = rt.Balance
	txn.Reason = rt.Reason
	txn.CreatedAt, _ = time.Parse(time.RFC3339, rt.CreatedAt)
	txn.ID = fmt.Sprintf("txn_%s_%d", txn.UserID, txn.CreatedAt.UnixMilli())
	return txn, nil
}

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
