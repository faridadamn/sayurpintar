package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// AnalyticsService provides unified analytics across all business domains.
type AnalyticsService struct {
	pool      *pgxpool.Pool
	orderRepo repository.OrderRepository
	subRepo   repository.SubscriptionRepository
	routeRepo repository.RouteRepository
	visitRepo repository.VisitRepository
	priceRepo *repository.PriceRepository
	userRepo  repository.UserRepository
	redis     *redis.Client
	logger    *zap.Logger
}

// NewAnalyticsService creates a new AnalyticsService.
func NewAnalyticsService(
	pool *pgxpool.Pool,
	orderRepo repository.OrderRepository,
	subRepo repository.SubscriptionRepository,
	routeRepo repository.RouteRepository,
	visitRepo repository.VisitRepository,
	priceRepo *repository.PriceRepository,
	userRepo repository.UserRepository,
	redis *redis.Client,
	logger *zap.Logger,
) *AnalyticsService {
	return &AnalyticsService{
		pool:      pool,
		orderRepo: orderRepo,
		subRepo:   subRepo,
		routeRepo: routeRepo,
		visitRepo: visitRepo,
		priceRepo: priceRepo,
		userRepo:  userRepo,
		redis:     redis,
		logger:    logger.Named("analytics"),
	}
}

// ── Response Types ──

// DailySummary contains comprehensive daily statistics for a pedagang.
type DailySummary struct {
	Date                string  `json:"date"`
	TotalRevenue        float64 `json:"total_revenue"`
	CashRevenue         float64 `json:"cash_revenue"`
	QRISRevenue         float64 `json:"qris_revenue"`
	TransferRevenue     float64 `json:"transfer_revenue"`
	TotalExpenses       float64 `json:"total_expenses"`
	GrossProfit         float64 `json:"gross_profit"`
	ProfitMargin        float64 `json:"profit_margin"`
	TotalOrders         int     `json:"total_orders"`
	DeliveredOrders     int     `json:"delivered_orders"`
	CancelledOrders     int     `json:"cancelled_orders"`
	PendingOrders       int     `json:"pending_orders"`
	ActiveSubscriptions int     `json:"active_subscriptions"`
	TodayDeliveries     int     `json:"today_deliveries"`
	RouteDistanceKm     float64 `json:"route_distance_km"`
	RouteDurationMin    int     `json:"route_duration_min"`
	VisitsCompleted     int     `json:"visits_completed"`
	VisitsSkipped       int     `json:"visits_skipped"`
	TotalPiutang        float64 `json:"total_piutang"`
	PiutangCount        int     `json:"piutang_count"`
	RevenueVsYesterday  float64 `json:"revenue_vs_yesterday"`
	OrdersVsYesterday   float64 `json:"orders_vs_yesterday"`
}

// WeeklyComparison compares this week vs last week.
type WeeklyComparison struct {
ThisWeek WeekStats   `json:"this_week"`
	LastWeek WeekStats   `json:"last_week"`
	Changes  WeekChanges `json:"changes"`
}

// WeekStats holds aggregated statistics for a week.
type WeekStats struct {
	StartDate       string  `json:"start_date"`
	EndDate         string  `json:"end_date"`
	TotalRevenue    float64 `json:"total_revenue"`
	TotalOrders     int     `json:"total_orders"`
	AvgDailyRevenue float64 `json:"avg_daily_revenue"`
	BestDay         string  `json:"best_day"`
	WorstDay        string  `json:"worst_day"`
}

// WeekChanges holds percentage changes between weeks.
type WeekChanges struct {
	RevenueChangePct float64 `json:"revenue_change_pct"`
	OrdersChangePct  float64 `json:"orders_change_pct"`
	Trend            string  `json:"trend"`
}

// MonthlyOverview holds monthly aggregated statistics.
type MonthlyOverview struct {
	Month             string  `json:"month"`
	TotalRevenue      float64 `json:"total_revenue"`
	TotalExpenses     float64 `json:"total_expenses"`
	NetProfit         float64 `json:"net_profit"`
	TotalOrders       int     `json:"total_orders"`
	UniqueCustomers   int     `json:"unique_customers"`
	AvgOrderValue     float64 `json:"avg_order_value"`
	BestProduct       string  `json:"best_product"`
	GrowthVsLastMonth float64 `json:"growth_vs_last_month"`
}

// TopItem represents a best-selling product.
type TopItem struct {
	ProductID    string  `json:"product_id"`
	ProductName  string  `json:"product_name"`
	TotalQty     float64 `json:"total_qty"`
	TotalRevenue float64 `json:"total_revenue"`
	OrderCount   int     `json:"order_count"`
	AvgPrice     float64 `json:"avg_price"`
	Unit         string  `json:"unit"`
}

// CustomerAnalytics holds customer behavior data.
type CustomerAnalytics struct {
	TotalCustomers      int            `json:"total_customers"`
	ActiveCustomers     int            `json:"active_customers"`
	SubscriberCustomers int            `json:"subscriber_customers"`
	AvgOrderFrequency   float64        `json:"avg_order_frequency"`
	TopCustomers        []CustomerStat `json:"top_customers"`
	AtRiskCustomers     []CustomerStat `json:"at_risk_customers"`
}

// CustomerStat holds per-customer order statistics.
type CustomerStat struct {
	CustomerID    string  `json:"customer_id"`
	CustomerName  string  `json:"customer_name"`
	TotalOrders   int     `json:"total_orders"`
	TotalSpent    float64 `json:"total_spent"`
	LastOrderDate string  `json:"last_order_date"`
	IsSubscriber  bool    `json:"is_subscriber"`
}

// RouteAnalytics holds route efficiency data.
type RouteAnalytics struct {
	AvgDailyDistance  float64 `json:"avg_daily_distance_km"`
	AvgDailyDuration float64 `json:"avg_daily_duration_min"`
	AvgVisitsPerDay  float64 `json:"avg_visits_per_day"`
	CompletionRate   float64 `json:"completion_rate"`
	EfficiencyScore  float64 `json:"efficiency_score"`
	BestRouteDay     string  `json:"best_route_day"`
	FuelCostEstimate float64 `json:"fuel_cost_estimate"`
}

// ── Methods ──

// GetDailySummary returns comprehensive daily stats for a pedagang.
func (s *AnalyticsService) GetDailySummary(ctx context.Context, pedagangID string, date string) (*DailySummary, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	summary := &DailySummary{Date: date}

	// 1. Order summary
	orderSummary, err := s.orderRepo.GetOrderSummary(ctx, pedagangID, date)
	if err != nil {
		s.logger.Warn("get order summary", zap.Error(err))
	} else {
		summary.TotalOrders = orderSummary.TotalOrders
		summary.DeliveredOrders = orderSummary.Delivered
		summary.CancelledOrders = orderSummary.Cancelled
		summary.PendingOrders = orderSummary.Pending
		summary.TotalRevenue = orderSummary.TotalRevenue
	}

	// 2. Revenue by payment method
	if err := s.revenueByPaymentMethod(ctx, pedagangID, date, summary); err != nil {
		s.logger.Warn("revenue by payment method", zap.Error(err))
	}

	// 3. Expenses
	expenses, err := s.dailyExpenses(ctx, pedagangID, date)
	if err != nil {
		s.logger.Warn("daily expenses", zap.Error(err))
	}
	summary.TotalExpenses = expenses

	// 4. Profit
	summary.GrossProfit = summary.TotalRevenue - summary.TotalExpenses
	if summary.TotalRevenue > 0 {
		summary.ProfitMargin = math.Round((summary.GrossProfit/summary.TotalRevenue)*10000) / 100
	}

	// 5. Active subscriptions
	activeSubs, err := s.subRepo.ListByPedagang(ctx, pedagangID, "active")
	if err != nil {
		s.logger.Warn("list active subscriptions", zap.Error(err))
	}
	summary.ActiveSubscriptions = len(activeSubs)

	// 6. Today deliveries
	summary.TodayDeliveries = summary.TotalOrders

	// 7. Route data
	route, err := s.routeRepo.GetByPedagangAndDate(ctx, pedagangID, date)
	if err == nil && route != nil {
		if route.ActualDistanceKm != nil {
			summary.RouteDistanceKm = *route.ActualDistanceKm
		} else {
			summary.RouteDistanceKm = route.TotalDistanceKm
		}
		if route.ActualDurationMin != nil {
			summary.RouteDurationMin = *route.ActualDurationMin
		} else {
			summary.RouteDurationMin = route.EstimatedDurationMin
		}
	}

	// 8. Visit stats
	visitStats, err := s.visitRepo.GetStatsByPedagang(ctx, pedagangID, date, date)
	if err == nil && visitStats != nil {
		summary.VisitsCompleted = visitStats.Completed
		summary.VisitsSkipped = visitStats.Skipped
	}

	// 9. Piutang
	if err := s.piutangStats(ctx, pedagangID, summary); err != nil {
		s.logger.Warn("piutang stats", zap.Error(err))
	}

	// 10. Yesterday comparison
	if err := s.yesterdayComparison(ctx, pedagangID, date, summary); err != nil {
		s.logger.Warn("yesterday comparison", zap.Error(err))
	}

	return summary, nil
}

// GetWeeklyComparison returns this week vs last week.
func (s *AnalyticsService) GetWeeklyComparison(ctx context.Context, pedagangID string) (*WeeklyComparison, error) {
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	thisWeekStart := now.AddDate(0, 0, -(weekday - 1)).Format("2006-01-02")
	lastWeekStart := now.AddDate(0, 0, -(weekday + 6)).Format("2006-01-02")
	lastWeekEnd := now.AddDate(0, 0, -weekday).Format("2006-01-02")
	today := now.Format("2006-01-02")

	thisWeek, err := s.weekStats(ctx, pedagangID, thisWeekStart, today)
	if err != nil {
		return nil, fmt.Errorf("this week stats: %w", err)
	}

	lastWeek, err := s.weekStats(ctx, pedagangID, lastWeekStart, lastWeekEnd)
	if err != nil {
		return nil, fmt.Errorf("last week stats: %w", err)
	}

	changes := WeekChanges{}
	if lastWeek.TotalRevenue > 0 {
		changes.RevenueChangePct = math.Round(((thisWeek.TotalRevenue-lastWeek.TotalRevenue)/lastWeek.TotalRevenue)*10000) / 100
	}
	if lastWeek.TotalOrders > 0 {
		changes.OrdersChangePct = math.Round(((float64(thisWeek.TotalOrders)-float64(lastWeek.TotalOrders))/float64(lastWeek.TotalOrders))*10000) / 100
	}

	switch {
	case changes.RevenueChangePct > 2:
		changes.Trend = "up"
	case changes.RevenueChangePct < -2:
		changes.Trend = "down"
	default:
		changes.Trend = "stable"
	}

	return &WeeklyComparison{
		ThisWeek: *thisWeek,
		LastWeek: *lastWeek,
		Changes:  changes,
	}, nil
}

// GetMonthlyOverview returns monthly aggregated stats.
func (s *AnalyticsService) GetMonthlyOverview(ctx context.Context, pedagangID string, month string) (*MonthlyOverview, error) {
	if month == "" {
		month = time.Now().Format("2006-01")
	}

	overview := &MonthlyOverview{Month: month}

	monthStart, err := time.Parse("2006-01", month)
	if err != nil {
		return nil, fmt.Errorf("parse month: %w", err)
	}
	fromDate := monthStart.Format("2006-01-02")
	toDate := monthStart.AddDate(0, 1, -1).Format("2006-01-02")

	orderQuery := `
		SELECT
			COUNT(*) AS total_orders,
			COALESCE(SUM(total_price), 0) AS total_revenue,
			COALESCE(AVG(total_price), 0) AS avg_order_value,
			COUNT(DISTINCT pelanggan_id) AS unique_customers
		FROM orders
		WHERE pedagang_id = $1
		  AND delivery_date >= $2
		  AND delivery_date <= $3
		  AND status != 'cancelled'`

	err = s.pool.QueryRow(ctx, orderQuery, pedagangID, fromDate, toDate).Scan(
		&overview.TotalOrders,
		&overview.TotalRevenue,
		&overview.AvgOrderValue,
		&overview.UniqueCustomers,
	)
	if err != nil {
		return nil, fmt.Errorf("monthly order aggregate: %w", err)
	}
	overview.AvgOrderValue = math.Round(overview.AvgOrderValue*100) / 100

	expenses, err := s.monthlyExpenses(ctx, pedagangID, month)
	if err != nil {
		s.logger.Warn("monthly expenses", zap.Error(err))
	}
	overview.TotalExpenses = expenses
	overview.NetProfit = overview.TotalRevenue - overview.TotalExpenses

	bestProduct, err := s.bestProductOfMonth(ctx, pedagangID, fromDate, toDate)
	if err == nil {
		overview.BestProduct = bestProduct
	}

	// Growth vs last month
	monthStart2, _ := time.Parse("2006-01", month)
	lastMonthStart := monthStart2.AddDate(0, -1, 0).Format("2006-01-02")
	lastMonthEnd := monthStart2.AddDate(0, 0, -1).Format("2006-01-02")

	var lastMonthRevenue float64
	lastMonthQuery := `
		SELECT COALESCE(SUM(total_price), 0)
		FROM orders
		WHERE pedagang_id = $1
		  AND delivery_date >= $2
		  AND delivery_date <= $3
		  AND status != 'cancelled'`

	_ = s.pool.QueryRow(ctx, lastMonthQuery, pedagangID, lastMonthStart, lastMonthEnd).Scan(&lastMonthRevenue)

	if lastMonthRevenue > 0 {
		overview.GrowthVsLastMonth = math.Round(((overview.TotalRevenue-lastMonthRevenue)/lastMonthRevenue)*10000) / 100
	}

	return overview, nil
}

// GetTopSellingItems returns best-selling products over a period.
func (s *AnalyticsService) GetTopSellingItems(ctx context.Context, pedagangID string, days int, limit int) ([]TopItem, error) {
	if days <= 0 {
		days = 7
	}
	if limit <= 0 {
		limit = 10
	}

	startDate := time.Now().AddDate(0, 0, -days).Format("2006-01-02")

	query := `
		SELECT items
		FROM orders
		WHERE pedagang_id = $1
		  AND delivery_date >= $2
		  AND status IN ('delivered', 'pending', 'preparing', 'delivering')`

	rows, err := s.pool.Query(ctx, query, pedagangID, startDate)
	if err != nil {
		return nil, fmt.Errorf("query order items: %w", err)
	}
	defer rows.Close()

	type itemAccum struct {
		ProductName  string
		TotalQty     float64
		TotalRevenue float64
		OrderCount   int
		Unit         string
	}
	accum := make(map[string]*itemAccum)

	for rows.Next() {
		var itemsJSON []byte
		if err := rows.Scan(&itemsJSON); err != nil {
			continue
		}
		items := parseOrderItems(itemsJSON)
		seenInOrder := make(map[string]bool)
		for _, item := range items {
			key := item.ProductID
			if accum[key] == nil {
				accum[key] = &itemAccum{
					ProductName: item.Name,
					Unit:        item.Unit,
				}
			}
			accum[key].TotalQty += item.Qty
			accum[key].TotalRevenue += item.Subtotal
			if !seenInOrder[key] {
				accum[key].OrderCount++
				seenInOrder[key] = true
			}
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate order items: %w", err)
	}

	result := make([]TopItem, 0, len(accum))
	for id, a := range accum {
		avgPrice := float64(0)
		if a.TotalQty > 0 {
			avgPrice = math.Round((a.TotalRevenue/a.TotalQty)*100) / 100
		}
		result = append(result, TopItem{
			ProductID:    id,
			ProductName:  a.ProductName,
			TotalQty:     a.TotalQty,
			TotalRevenue: math.Round(a.TotalRevenue*100) / 100,
			OrderCount:   a.OrderCount,
			AvgPrice:     avgPrice,
			Unit:         a.Unit,
		})
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].TotalRevenue > result[j].TotalRevenue
	})

	if len(result) > limit {
		result = result[:limit]
	}
	if result == nil {
		result = []TopItem{}
	}

	return result, nil
}

// GetCustomerAnalytics returns customer behavior data.
func (s *AnalyticsService) GetCustomerAnalytics(ctx context.Context, pedagangID string) (*CustomerAnalytics, error) {
	analytics := &CustomerAnalytics{}

	totalQuery := `SELECT COUNT(DISTINCT pelanggan_id) FROM orders WHERE pedagang_id = $1`
	_ = s.pool.QueryRow(ctx, totalQuery, pedagangID).Scan(&analytics.TotalCustomers)

	activeQuery := `SELECT COUNT(DISTINCT pelanggan_id) FROM orders WHERE pedagang_id = $1 AND created_at >= NOW() - INTERVAL '30 days'`
	_ = s.pool.QueryRow(ctx, activeQuery, pedagangID).Scan(&analytics.ActiveCustomers)

	subs, err := s.subRepo.ListByPedagang(ctx, pedagangID, "active")
	if err == nil {
		analytics.SubscriberCustomers = len(subs)
	}

	freqQuery := `
		SELECT
			CASE WHEN COUNT(DISTINCT pelanggan_id) > 0
				THEN ROUND(COUNT(*)::decimal / NULLIF(COUNT(DISTINCT pelanggan_id), 0) /
					NULLIF(GREATEST(EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 86400 / 30, 1), 0), 2)
				ELSE 0
			END AS avg_freq
		FROM orders
		WHERE pedagang_id = $1 AND status != 'cancelled'`
	_ = s.pool.QueryRow(ctx, freqQuery, pedagangID).Scan(&analytics.AvgOrderFrequency)

	topQuery := `
		SELECT
			o.pelanggan_id,
			COALESCE(u.name, '') AS customer_name,
			COUNT(*) AS total_orders,
			COALESCE(SUM(o.total_price), 0) AS total_spent,
			MAX(o.delivery_date) AS last_order_date,
			EXISTS(SELECT 1 FROM subscriptions s WHERE s.pelanggan_id = o.pelanggan_id AND s.pedagang_id = $1 AND s.status = 'active') AS is_subscriber
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.pedagang_id = $1 AND o.status != 'cancelled'
		GROUP BY o.pelanggan_id, u.name
		ORDER BY total_spent DESC
		LIMIT 10`

	topRows, err := s.pool.Query(ctx, topQuery, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("top customers query: %w", err)
	}
	defer topRows.Close()

	analytics.TopCustomers = []CustomerStat{}
	for topRows.Next() {
		var cs CustomerStat
		if err := topRows.Scan(&cs.CustomerID, &cs.CustomerName, &cs.TotalOrders, &cs.TotalSpent, &cs.LastOrderDate, &cs.IsSubscriber); err != nil {
			return nil, fmt.Errorf("scan top customer: %w", err)
		}
		cs.TotalSpent = math.Round(cs.TotalSpent*100) / 100
		analytics.TopCustomers = append(analytics.TopCustomers, cs)
	}
	if err := topRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate top customers: %w", err)
	}

	atRiskQuery := `
		SELECT
			o.pelanggan_id,
			COALESCE(u.name, '') AS customer_name,
			COUNT(*) AS total_orders,
			COALESCE(SUM(o.total_price), 0) AS total_spent,
			MAX(o.delivery_date) AS last_order_date,
			EXISTS(SELECT 1 FROM subscriptions s WHERE s.pelanggan_id = o.pelanggan_id AND s.pedagang_id = $1 AND s.status = 'active') AS is_subscriber
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.pedagang_id = $1 AND o.status != 'cancelled'
		GROUP BY o.pelanggan_id, u.name
		HAVING MAX(o.delivery_date) < (CURRENT_DATE - INTERVAL '14 days')::text
		ORDER BY MAX(o.delivery_date) DESC
		LIMIT 10`

	atRiskRows, err := s.pool.Query(ctx, atRiskQuery, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("at-risk customers query: %w", err)
	}
	defer atRiskRows.Close()

	analytics.AtRiskCustomers = []CustomerStat{}
	for atRiskRows.Next() {
		var cs CustomerStat
		if err := atRiskRows.Scan(&cs.CustomerID, &cs.CustomerName, &cs.TotalOrders, &cs.TotalSpent, &cs.LastOrderDate, &cs.IsSubscriber); err != nil {
			return nil, fmt.Errorf("scan at-risk customer: %w", err)
		}
		cs.TotalSpent = math.Round(cs.TotalSpent*100) / 100
		analytics.AtRiskCustomers = append(analytics.AtRiskCustomers, cs)
	}
	if err := atRiskRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate at-risk customers: %w", err)
	}

	return analytics, nil
}

// GetRouteAnalytics returns route efficiency data.
func (s *AnalyticsService) GetRouteAnalytics(ctx context.Context, pedagangID string, days int) (*RouteAnalytics, error) {
	if days <= 0 {
		days = 7
	}

	stats, err := s.routeRepo.GetRouteStats(ctx, pedagangID, days)
	if err != nil {
		return nil, fmt.Errorf("get route stats: %w", err)
	}

	startDate := time.Now().AddDate(0, 0, -days).Format("2006-01-02")
	today := time.Now().Format("2006-01-02")

	visitStats, err := s.visitRepo.GetStatsByPedagang(ctx, pedagangID, startDate, today)
	if err != nil {
		s.logger.Warn("get visit stats for route analytics", zap.Error(err))
	}

	analytics := &RouteAnalytics{
		AvgDailyDistance:  stats.AvgDistanceKm,
		AvgDailyDuration: stats.AvgDurationMin,
		CompletionRate:   stats.CompletionRate,
		FuelCostEstimate: math.Round(stats.AvgFuelCost*float64(days)*100) / 100,
	}

	if visitStats != nil && stats.TotalRoutes > 0 {
		analytics.AvgVisitsPerDay = math.Round((float64(visitStats.TotalVisits)/float64(stats.TotalRoutes))*100) / 100
	}

	if analytics.AvgDailyDistance > 0 {
		analytics.EfficiencyScore = math.Round((analytics.AvgVisitsPerDay/analytics.AvgDailyDistance)*100) / 100
	}

	bestDayQuery := `
		SELECT date FROM routes
		WHERE pedagang_id = $1 AND status = 'completed' AND date >= $2
		ORDER BY total_distance_km DESC LIMIT 1`
	_ = s.pool.QueryRow(ctx, bestDayQuery, pedagangID, startDate).Scan(&analytics.BestRouteDay)

	return analytics, nil
}

// ── Internal helpers ──

type orderItem struct {
	ProductID string  `json:"product_id"`
	Name      string  `json:"nama"`
	Qty       float64 `json:"qty"`
	Unit      string  `json:"satuan"`
	Price     float64 `json:"harga"`
	Subtotal  float64 `json:"subtotal"`
}

func parseOrderItems(data []byte) []orderItem {
	if len(data) == 0 {
		return nil
	}
	var raw []struct {
		ProductID string  `json:"product_id"`
		Name      string  `json:"nama"`
		Qty       float64 `json:"qty"`
		Unit      string  `json:"satuan"`
		Price     float64 `json:"harga"`
		Subtotal  float64 `json:"subtotal"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil
	}
	items := make([]orderItem, len(raw))
	for i, r := range raw {
		items[i] = orderItem{
			ProductID: r.ProductID,
			Name:      r.Name,
			Qty:       r.Qty,
			Unit:      r.Unit,
			Price:     r.Price,
			Subtotal:  r.Subtotal,
		}
	}
	return items
}

func (s *AnalyticsService) revenueByPaymentMethod(ctx context.Context, pedagangID string, date string, summary *DailySummary) error {
	query := `
		SELECT COALESCE(payment_method, 'unknown'), COALESCE(SUM(total_price), 0)
		FROM orders
		WHERE pedagang_id = $1 AND delivery_date = $2 AND status != 'cancelled'
		GROUP BY payment_method`

	rows, err := s.pool.Query(ctx, query, pedagangID, date)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var method string
		var total float64
		if err := rows.Scan(&method, &total); err != nil {
			return err
		}
		switch method {
		case "cash":
			summary.CashRevenue = total
		case "qris":
			summary.QRISRevenue = total
		case "transfer":
			summary.TransferRevenue = total
		}
	}
	return rows.Err()
}

func (s *AnalyticsService) dailyExpenses(ctx context.Context, pedagangID string, date string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'expense' AND DATE(created_at) = $2::date`
	var total float64
	err := s.pool.QueryRow(ctx, query, pedagangID, date).Scan(&total)
	return total, err
}

func (s *AnalyticsService) monthlyExpenses(ctx context.Context, pedagangID string, month string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'expense' AND TO_CHAR(created_at, 'YYYY-MM') = $2`
	var total float64
	err := s.pool.QueryRow(ctx, query, pedagangID, month).Scan(&total)
	return total, err
}

func (s *AnalyticsService) piutangStats(ctx context.Context, pedagangID string, summary *DailySummary) error {
	query := `
		SELECT COALESCE(SUM(total_price), 0), COUNT(*)
		FROM orders
		WHERE pedagang_id = $1 AND payment_status != 'paid' AND status = 'delivered'`
	return s.pool.QueryRow(ctx, query, pedagangID).Scan(&summary.TotalPiutang, &summary.PiutangCount)
}

func (s *AnalyticsService) yesterdayComparison(ctx context.Context, pedagangID string, today string, summary *DailySummary) error {
	yesterday, err := time.Parse("2006-01-02", today)
	if err != nil {
		return err
	}
	yesterdayStr := yesterday.AddDate(0, 0, -1).Format("2006-01-02")

	yesterdaySummary, err := s.orderRepo.GetOrderSummary(ctx, pedagangID, yesterdayStr)
	if err != nil {
		return err
	}

	if yesterdaySummary.TotalRevenue > 0 {
		summary.RevenueVsYesterday = math.Round(((summary.TotalRevenue-yesterdaySummary.TotalRevenue)/yesterdaySummary.TotalRevenue)*10000) / 100
	}
	if yesterdaySummary.TotalOrders > 0 {
		summary.OrdersVsYesterday = math.Round(((float64(summary.TotalOrders)-float64(yesterdaySummary.TotalOrders))/float64(yesterdaySummary.TotalOrders))*10000) / 100
	}

	return nil
}

func (s *AnalyticsService) weekStats(ctx context.Context, pedagangID string, startDate, endDate string) (*WeekStats, error) {
	query := `
		SELECT COALESCE(SUM(total_price), 0), COUNT(*), delivery_date
		FROM orders
		WHERE pedagang_id = $1 AND delivery_date >= $2 AND delivery_date <= $3 AND status != 'cancelled'
		GROUP BY delivery_date ORDER BY delivery_date`

	rows, err := s.pool.Query(ctx, query, pedagangID, startDate, endDate)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	stats := &WeekStats{
		StartDate: startDate,
		EndDate:   endDate,
		BestDay:   startDate,
		WorstDay:  startDate,
	}

	var bestRevenue, worstRevenue float64
	daysWithData := 0

	for rows.Next() {
		var revenue float64
		var orderCount int
		var deliveryDate string
		if err := rows.Scan(&revenue, &orderCount, &deliveryDate); err != nil {
			return nil, err
		}
		stats.TotalRevenue += revenue
		stats.TotalOrders += orderCount
		daysWithData++

		if revenue > bestRevenue {
			bestRevenue = revenue
			stats.BestDay = deliveryDate
		}
		if worstRevenue == 0 || revenue < worstRevenue {
			worstRevenue = revenue
			stats.WorstDay = deliveryDate
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if daysWithData > 0 {
		stats.AvgDailyRevenue = math.Round((stats.TotalRevenue/float64(daysWithData))*100) / 100
	}

	return stats, nil
}

func (s *AnalyticsService) bestProductOfMonth(ctx context.Context, pedagangID string, from, to string) (string, error) {
	query := `
		SELECT items FROM orders
		WHERE pedagang_id = $1 AND delivery_date >= $2 AND delivery_date <= $3 AND status != 'cancelled'`

	rows, err := s.pool.Query(ctx, query, pedagangID, from, to)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	revenue := make(map[string]float64)
	names := make(map[string]string)

	for rows.Next() {
		var itemsJSON []byte
		if err := rows.Scan(&itemsJSON); err != nil {
			continue
		}
		items := parseOrderItems(itemsJSON)
		for _, item := range items {
			revenue[item.ProductID] += item.Subtotal
			names[item.ProductID] = item.Name
		}
	}
	if err := rows.Err(); err != nil {
		return "", err
	}

	var bestID string
	var bestRevenue float64
	for id, rev := range revenue {
		if rev > bestRevenue {
			bestRevenue = rev
			bestID = id
		}
	}

	if bestID != "" {
		return names[bestID], nil
	}
	return "", nil
}
