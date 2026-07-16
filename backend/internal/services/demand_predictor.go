package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// DemandPredictor predicts what items a pedagang will need based on historical data.
type DemandPredictor struct {
	pool      *pgxpool.Pool
	orderRepo repository.OrderRepository
	subRepo   repository.SubscriptionRepository
	logger    *zap.Logger
}

// NewDemandPredictor creates a new DemandPredictor.
func NewDemandPredictor(
	pool *pgxpool.Pool,
	orderRepo repository.OrderRepository,
	subRepo repository.SubscriptionRepository,
	logger *zap.Logger,
) *DemandPredictor {
	return &DemandPredictor{
		pool:      pool,
		orderRepo: orderRepo,
		subRepo:   subRepo,
		logger:    logger.Named("demand_predictor"),
	}
}

// DemandPrediction represents a predicted demand for a product.
type DemandPrediction struct {
	ProductID    string  `json:"product_id"`
	ProductName  string  `json:"product_name"`
	PredictedQty float64 `json:"predicted_qty"`
	Unit         string  `json:"unit"`
	Confidence   float64 `json:"confidence"` // 0-1
	BasedOn      string  `json:"based_on"`   // "weekly_avg", "trending", "subscription"
}

// PredictDemand predicts what items will be needed on the given date.
// Uses three signals:
//   - Historical weekly average over the last 60 days
//   - Day-of-week patterns (e.g., Monday vs Saturday)
//   - Active subscription items for that day
func (p *DemandPredictor) PredictDemand(ctx context.Context, pedagangID string, date time.Time) ([]DemandPrediction, error) {
	p.logger.Info("predicting demand",
		zap.String("pedagang_id", pedagangID),
		zap.String("date", date.Format("2006-01-02")),
	)

	// Accumulate predictions from multiple sources
	predictions := make(map[string]*DemandPrediction)

	// 1. Historical weekly average (last 60 days)
	if err := p.historicalAverage(ctx, pedagangID, predictions); err != nil {
		p.logger.Warn("historical average", zap.Error(err))
	}

	// 2. Day-of-week pattern boost
	if err := p.dayOfWeekPattern(ctx, pedagangID, date, predictions); err != nil {
		p.logger.Warn("day of week pattern", zap.Error(err))
	}

	// 3. Subscription-based predictions
	if err := p.subscriptionDemand(ctx, pedagangID, date, predictions); err != nil {
		p.logger.Warn("subscription demand", zap.Error(err))
	}

	// Convert to slice and sort by predicted quantity
	result := make([]DemandPrediction, 0, len(predictions))
	for _, pred := range predictions {
		if pred.PredictedQty > 0 {
			result = append(result, *pred)
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].PredictedQty > result[j].PredictedQty
	})

	if result == nil {
		result = []DemandPrediction{}
	}

	return result, nil
}

// demandOrderItem represents an item parsed from order JSON.
type demandOrderItem struct {
	ProductID string  `json:"product_id"`
	Name      string  `json:"nama"`
	Qty       float64 `json:"qty"`
	Unit      string  `json:"satuan"`
}

func parseDemandItems(data []byte) []demandOrderItem {
	if len(data) == 0 {
		return nil
	}
	var items []demandOrderItem
	if err := json.Unmarshal(data, &items); err != nil {
		return nil
	}
	return items
}

// historicalAverage computes average item quantities from the last 60 days.
func (p *DemandPredictor) historicalAverage(ctx context.Context, pedagangID string, predictions map[string]*DemandPrediction) error {
	startDate := time.Now().AddDate(0, 0, -60).Format("2006-01-02")

	query := `
		SELECT delivery_date, items
		FROM orders
		WHERE pedagang_id = $1
		  AND delivery_date >= $2
		  AND status IN ('delivered', 'pending', 'preparing', 'delivering')
		ORDER BY delivery_date`

	rows, err := p.pool.Query(ctx, query, pedagangID, startDate)
	if err != nil {
		return fmt.Errorf("query orders for demand: %w", err)
	}
	defer rows.Close()

	type productAccum struct {
		Name     string
		TotalQty float64
		Unit     string
	}
	products := make(map[string]*productAccum)
	weeksWithOrders := make(map[int]bool)

	for rows.Next() {
		var deliveryDate string
		var itemsJSON []byte
		if err := rows.Scan(&deliveryDate, &itemsJSON); err != nil {
			continue
		}

		// Track weeks
		t, err := time.Parse("2006-01-02", deliveryDate)
		if err == nil {
			_, week := t.ISOWeek()
			weeksWithOrders[week] = true
		}

		items := parseDemandItems(itemsJSON)
		for _, item := range items {
			if products[item.ProductID] == nil {
				products[item.ProductID] = &productAccum{
					Name: item.Name,
					Unit: item.Unit,
				}
			}
			products[item.ProductID].TotalQty += item.Qty
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate orders: %w", err)
	}

	totalWeeks := len(weeksWithOrders)
	if totalWeeks == 0 {
		totalWeeks = 1
	}

	// 60 days ≈ 8.57 weeks
	expectedWeeks := 8.57

	for id, acc := range products {
		weeklyAvg := acc.TotalQty / float64(totalWeeks)

		// Confidence based on data completeness
		dataCompleteness := float64(totalWeeks) / expectedWeeks
		confidence := math.Min(dataCompleteness, 1.0) * 0.7 // max 0.7 for historical

		predictions[id] = &DemandPrediction{
			ProductID:    id,
			ProductName:  acc.Name,
			PredictedQty: weeklyAvg,
			Unit:         acc.Unit,
			Confidence:   confidence,
			BasedOn:      "weekly_avg",
		}
	}

	return nil
}

// dayOfWeekPattern adjusts predictions based on the target day's historical pattern.
func (p *DemandPredictor) dayOfWeekPattern(ctx context.Context, pedagangID string, date time.Time, predictions map[string]*DemandPrediction) error {
	targetDOW := int(date.Weekday())

	startDate := time.Now().AddDate(0, 0, -60).Format("2006-01-02")

	query := `
		SELECT delivery_date, items
		FROM orders
		WHERE pedagang_id = $1
		  AND delivery_date >= $2
		  AND status IN ('delivered', 'pending', 'preparing', 'delivering')
		ORDER BY delivery_date`

	rows, err := p.pool.Query(ctx, query, pedagangID, startDate)
	if err != nil {
		return fmt.Errorf("query orders for dow: %w", err)
	}
	defer rows.Close()

	type productDOW struct {
		Name     string
		TotalQty float64
		Unit     string
		Count    int
	}
	dowProducts := make(map[string]*productDOW)

	for rows.Next() {
		var deliveryDate string
		var itemsJSON []byte
		if err := rows.Scan(&deliveryDate, &itemsJSON); err != nil {
			continue
		}

		t, err := time.Parse("2006-01-02", deliveryDate)
		if err != nil {
			continue
		}

		if int(t.Weekday()) != targetDOW {
			continue
		}

		items := parseDemandItems(itemsJSON)
		for _, item := range items {
			if dowProducts[item.ProductID] == nil {
				dowProducts[item.ProductID] = &productDOW{
					Name: item.Name,
					Unit: item.Unit,
				}
			}
			dowProducts[item.ProductID].TotalQty += item.Qty
			dowProducts[item.ProductID].Count++
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate dow orders: %w", err)
	}

	// Boost predictions for items that are popular on this day of week
	for id, acc := range dowProducts {
		if acc.Count == 0 {
			continue
		}
		avgQty := acc.TotalQty / float64(acc.Count)

		if existing, ok := predictions[id]; ok {
			// Blend: 60% historical + 40% DOW-specific
			existing.PredictedQty = existing.PredictedQty*0.6 + avgQty*0.4
			existing.Confidence = math.Min(existing.Confidence+0.15, 0.95)
		} else {
			if acc.Count >= 3 {
				predictions[id] = &DemandPrediction{
					ProductID:    id,
					ProductName:  acc.Name,
					PredictedQty: avgQty,
					Unit:         acc.Unit,
					Confidence:   0.5,
					BasedOn:      "weekly_avg",
				}
			}
		}
	}

	return nil
}

// subscriptionDemand adds predictions based on active subscriptions that deliver on the target date.
func (p *DemandPredictor) subscriptionDemand(ctx context.Context, pedagangID string, date time.Time, predictions map[string]*DemandPrediction) error {
	subs, err := p.subRepo.GetActiveSubscriptionsForDate(ctx, date)
	if err != nil {
		return fmt.Errorf("get active subscriptions: %w", err)
	}

	// For each subscription belonging to this pedagang, look at recent orders
	// to determine what items are typically delivered
	type subItem struct {
		ProductID string
		Name      string
		TotalQty  float64
		Unit      string
		Count     int
	}
	subItems := make(map[string]*subItem)

	for _, sub := range subs {
		if sub.PedagangID != pedagangID {
			continue
		}

		// Query recent delivered orders for this subscription
		query := `
			SELECT items
			FROM orders
			WHERE subscription_id = $1 AND status = 'delivered'
			ORDER BY delivery_date DESC
			LIMIT 10`

		rows, err := p.pool.Query(ctx, query, sub.ID)
		if err != nil {
			continue
		}

		for rows.Next() {
			var itemsJSON []byte
			if err := rows.Scan(&itemsJSON); err != nil {
				continue
			}
			items := parseDemandItems(itemsJSON)
			for _, item := range items {
				if subItems[item.ProductID] == nil {
					subItems[item.ProductID] = &subItem{
						Name: item.Name,
						Unit: item.Unit,
					}
				}
				subItems[item.ProductID].TotalQty += item.Qty
				subItems[item.ProductID].Count++
			}
		}
		rows.Close()
	}

	// Merge subscription predictions
	for id, si := range subItems {
		if si.Count == 0 {
			continue
		}
		avgQty := si.TotalQty / float64(si.Count)

		if existing, ok := predictions[id]; ok {
			// Subscription data is very reliable — boost confidence significantly
			existing.PredictedQty = (existing.PredictedQty + avgQty) / 2
			existing.Confidence = math.Min(existing.Confidence+0.25, 0.99)
			existing.BasedOn = "subscription"
		} else {
			predictions[id] = &DemandPrediction{
				ProductID:    id,
				ProductName:  si.Name,
				PredictedQty: avgQty,
				Unit:         si.Unit,
				Confidence:   0.85,
				BasedOn:      "subscription",
			}
		}
	}

	return nil
}
