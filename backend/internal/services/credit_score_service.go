package services

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// CreditScoreService computes credit scores for pedagang based on business data.
type CreditScoreService struct {
	orderRepo repository.OrderRepository
	transRepo repository.TransactionRepository
	debtRepo  repository.DebtRepository
	routeRepo repository.RouteRepository
	subRepo   repository.SubscriptionRepository
	userRepo  repository.UserRepository
	logger    *zap.Logger
}

// NewCreditScoreService creates a new CreditScoreService.
func NewCreditScoreService(
	orderRepo repository.OrderRepository,
	transRepo repository.TransactionRepository,
	debtRepo repository.DebtRepository,
	routeRepo repository.RouteRepository,
	subRepo repository.SubscriptionRepository,
	userRepo repository.UserRepository,
	logger *zap.Logger,
) *CreditScoreService {
	return &CreditScoreService{
		orderRepo: orderRepo,
		transRepo: transRepo,
		debtRepo:  debtRepo,
		routeRepo: routeRepo,
		subRepo:   subRepo,
		userRepo:  userRepo,
		logger:    logger.Named("credit_score"),
	}
}

// CreditScore represents a computed credit score for a pedagang.
type CreditScore struct {
	Score          int           `json:"score"`           // 0-100
	Level          string        `json:"level"`           // "poor", "fair", "good", "excellent"
	Badge          string        `json:"badge"`           // emoji badge
	Factors        ScoreFactors  `json:"factors"`
	EligibleLoan   float64       `json:"eligible_loan_amount"`
	Recommendations []string    `json:"recommendations"`
}

// ScoreFactors holds the individual scoring components.
type ScoreFactors struct {
	OrderConsistency float64 `json:"order_consistency"` // 0-100
	RevenueStability float64 `json:"revenue_stability"` // 0-100
	PiutangHealth    float64 `json:"piutang_health"`    // 0-100
	RouteDiscipline  float64 `json:"route_discipline"`  // 0-100
	AccountAge       float64 `json:"account_age"`       // 0-100
}

// ScoreSnapshot represents a historical credit score data point.
type ScoreSnapshot struct {
	Date  string `json:"date"`
	Score int    `json:"score"`
}

// CalculateCreditScore computes a credit score from the pedagang's business data.
// Score 0-100, weighted factors:
//   - Order consistency (30%): orders per week over last 90 days
//   - Revenue stability (25%): coefficient of variation of weekly revenue
//   - Piutang health (20%): ratio of settled vs outstanding debts
//   - Route discipline (15%): route completion rate
//   - Account age (10%): months since registration
func (s *CreditScoreService) CalculateCreditScore(ctx context.Context, pedagangID string) (*CreditScore, error) {
	s.logger.Info("calculating credit score", zap.String("pedagang_id", pedagangID))

	factors := ScoreFactors{}
	recommendations := []string{}

	// 1. Order consistency (30%) — orders per week over last 90 days
	consistency, err := s.orderConsistency(ctx, pedagangID)
	if err != nil {
		s.logger.Warn("order consistency calc", zap.Error(err))
	}
	factors.OrderConsistency = consistency

	// 2. Revenue stability (25%) — coefficient of variation of weekly revenue
	stability, err := s.revenueStability(ctx, pedagangID)
	if err != nil {
		s.logger.Warn("revenue stability calc", zap.Error(err))
	}
	factors.RevenueStability = stability

	// 3. Piutang health (20%) — ratio of settled vs outstanding debts
	piutang, err := s.piutangHealth(ctx, pedagangID)
	if err != nil {
		s.logger.Warn("piutang health calc", zap.Error(err))
	}
	factors.PiutangHealth = piutang

	// 4. Route discipline (15%) — route completion rate
	discipline, err := s.routeDiscipline(ctx, pedagangID)
	if err != nil {
		s.logger.Warn("route discipline calc", zap.Error(err))
	}
	factors.RouteDiscipline = discipline

	// 5. Account age (10%) — months since registration
	age, err := s.accountAge(ctx, pedagangID)
	if err != nil {
		s.logger.Warn("account age calc", zap.Error(err))
	}
	factors.AccountAge = age

	// Weighted sum
	rawScore := (factors.OrderConsistency * 0.30) +
		(factors.RevenueStability * 0.25) +
		(factors.PiutangHealth * 0.20) +
		(factors.RouteDiscipline * 0.15) +
		(factors.AccountAge * 0.10)

	score := int(math.Round(rawScore))
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}

	// Determine level and badge
	level, badge := scoreLevel(score)

	// Eligible loan amount (simple formula: score * 50000 IDR)
	eligibleLoan := float64(score) * 50000.0

	// Generate recommendations
	if factors.OrderConsistency < 60 {
		recommendations = append(recommendations, "Tingkatkan konsistensi pesanan — usahakan minimal 3 pesanan per minggu")
	}
	if factors.RevenueStability < 60 {
		recommendations = append(recommendations, "Stabilkan pemasukan — variasi revenue mingguan masih tinggi")
	}
	if factors.PiutangHealth < 60 {
		recommendations = append(recommendations, "Selesaikan piutang yang tertagih untuk meningkatkan skor kredit")
	}
	if factors.RouteDiscipline < 60 {
		recommendations = append(recommendations, "Selesaikan rute harian yang sudah direncanakan")
	}
	if factors.AccountAge < 40 {
		recommendations = append(recommendations, "Terus gunakan SayurPintar — skor meningkat seiring waktu")
	}
	if len(recommendations) == 0 {
		recommendations = append(recommendations, "Pertahankan performa bisnis Anda! 🎉")
	}

	return &CreditScore{
		Score:           score,
		Level:           level,
		Badge:           badge,
		Factors:         factors,
		EligibleLoan:    eligibleLoan,
		Recommendations: recommendations,
	}, nil
}

// GetScoreHistory returns historical credit scores for the given number of months.
func (s *CreditScoreService) GetScoreHistory(ctx context.Context, pedagangID string, months int) ([]ScoreSnapshot, error) {
	if months <= 0 {
		months = 6
	}
	if months > 24 {
		months = 24
	}

	snapshots := make([]ScoreSnapshot, 0, months)
	now := time.Now()

	for i := months - 1; i >= 0; i-- {
		monthDate := now.AddDate(0, -i, 0)
		monthStart := time.Date(monthDate.Year(), monthDate.Month(), 1, 0, 0, 0, 0, time.Local)
		monthEnd := monthStart.AddDate(0, 1, -1)

		// Compute a simplified score for that month range
		score, err := s.scoreForPeriod(ctx, pedagangID, monthStart, monthEnd)
		if err != nil {
			s.logger.Warn("score for period", zap.Error(err), zap.String("month", monthStart.Format("2006-01")))
			score = 0
		}

		snapshots = append(snapshots, ScoreSnapshot{
			Date:  monthStart.Format("2006-01"),
			Score: score,
		})
	}

	return snapshots, nil
}

// scoreForPeriod computes a simplified score for a specific time period.
func (s *CreditScoreService) scoreForPeriod(ctx context.Context, pedagangID string, start, end time.Time) (int, error) {
	_ = end // future: constrain queries to period

	from := start.Format("2006-01-02")
	to := end.Format("2006-01-02")

	// Simplified: count orders in period, scale by expected (approx 4/week = 16/month)
	orders, err := s.orderRepo.ListByPedagangAndDate(ctx, pedagangID, from)
	if err != nil {
		orders = nil
	}
	// Use transaction list to approximate total order count for the month
	txns, err := s.transRepo.ListByPedagang(ctx, pedagangID, from, to)
	if err != nil {
		txns = nil
	}
	_ = orders

	orderCount := len(txns) // approximate
	expectedOrders := 16.0
	consistency := math.Min(float64(orderCount)/expectedOrders*100, 100)

	routes, err := s.routeRepo.ListByPedagang(ctx, pedagangID, from, to)
	if err != nil {
		routes = nil
	}
	completedRoutes := 0
	for _, r := range routes {
		if r.Status == "completed" {
			completedRoutes++
		}
	}
	discipline := 50.0
	if len(routes) > 0 {
		discipline = float64(completedRoutes) / float64(len(routes)) * 100
	}

	rawScore := (consistency * 0.50) + (discipline * 0.50)
	score := int(math.Round(rawScore))
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	return score, nil
}

// orderConsistency measures orders per week over the last 90 days.
func (s *CreditScoreService) orderConsistency(ctx context.Context, pedagangID string) (float64, error) {
	now := time.Now()
	startDate := now.AddDate(0, 0, -90).Format("2006-01-02")
	endDate := now.Format("2006-01-02")

	// Count orders via transactions (income = orders)
	txns, err := s.transRepo.ListByPedagang(ctx, pedagangID, startDate, endDate)
	if err != nil {
		return 0, fmt.Errorf("list transactions: %w", err)
	}

	orderCount := 0
	for _, t := range txns {
		if t.Type == "income" {
			orderCount++
		}
	}

	// 90 days ≈ 12.86 weeks
	weeks := 90.0 / 7.0
	ordersPerWeek := float64(orderCount) / weeks

	// Target: ~4 orders/week = 100%, scale linearly
	// 0 orders/week = 0, 4+ orders/week = 100
	score := math.Min(ordersPerWeek/4.0*100, 100)
	return score, nil
}

// revenueStability measures the coefficient of variation of weekly revenue.
func (s *CreditScoreService) revenueStability(ctx context.Context, pedagangID string) (float64, error) {
	now := time.Now()

	// Collect weekly revenue for the last 12 weeks
	weeklyRevenues := make([]float64, 0, 12)
	for i := 11; i >= 0; i-- {
		weekStart := now.AddDate(0, 0, -(i*7 + int(now.Weekday())))
		weekStartStr := weekStart.Format("2006-01-02")

		totals, err := s.transRepo.GetWeeklyTotals(ctx, pedagangID, weekStartStr)
		if err != nil {
			continue
		}

		var total float64
		for _, v := range totals {
			total += v
		}
		if total > 0 {
			weeklyRevenues = append(weeklyRevenues, total)
		}
	}

	if len(weeklyRevenues) < 2 {
		return 50.0, nil // insufficient data, neutral score
	}

	// Compute mean
	var sum float64
	for _, r := range weeklyRevenues {
		sum += r
	}
	mean := sum / float64(len(weeklyRevenues))

	if mean == 0 {
		return 0, nil
	}

	// Compute standard deviation
	var sumSq float64
	for _, r := range weeklyRevenues {
		diff := r - mean
		sumSq += diff * diff
	}
	stddev := math.Sqrt(sumSq / float64(len(weeklyRevenues)))

	// Coefficient of variation (lower = more stable = better)
	cv := stddev / mean

	// CV of 0 = perfect stability (100), CV of 1+ = very unstable (0)
	score := math.Max(0, 100-cv*100)
	return math.Min(score, 100), nil
}

// piutangHealth measures the ratio of settled vs outstanding debts.
func (s *CreditScoreService) piutangHealth(ctx context.Context, pedagangID string) (float64, error) {
	totalOutstanding, err := s.debtRepo.SumOutstanding(ctx, pedagangID)
	if err != nil {
		return 50.0, nil
	}

	totalSettled, err := s.debtRepo.SumSettled(ctx, pedagangID)
	if err != nil {
		return 50.0, nil
	}

	total := totalOutstanding + totalSettled
	if total == 0 {
		return 80.0, nil // no debts = healthy
	}

	// Higher settled ratio = better score
	ratio := totalSettled / total
	return math.Min(ratio*100, 100), nil
}

// routeDiscipline measures the route completion rate over the last 30 days.
func (s *CreditScoreService) routeDiscipline(ctx context.Context, pedagangID string) (float64, error) {
	stats, err := s.routeRepo.GetRouteStats(ctx, pedagangID, 30)
	if err != nil {
		return 50.0, nil
	}

	return stats.CompletionRate, nil
}

// accountAge measures months since registration, capped at 24 months.
func (s *CreditScoreService) accountAge(ctx context.Context, pedagangID string) (float64, error) {
	user, err := s.userRepo.GetByID(ctx, pedagangID)
	if err != nil {
		return 0, fmt.Errorf("get user: %w", err)
	}

	months := time.Since(user.CreatedAt).Hours() / 24 / 30
	// 24 months = 100%, scale linearly, cap at 100
	score := math.Min(months/24.0*100, 100)
	return score, nil
}

// scoreLevel maps a numeric score to a human-readable level and emoji badge.
func scoreLevel(score int) (string, string) {
	switch {
	case score >= 80:
		return "excellent", "🌟"
	case score >= 60:
		return "good", "👍"
	case score >= 40:
		return "fair", "⚠️"
	default:
		return "poor", "🔻"
	}
}
