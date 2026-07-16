package services

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

const (
	significantChangeThreshold = 15.0 // percentage
	anomalyWindowDays          = 3
	movingAverageWindow        = 7
)

// TrendPoint represents a single data point in a moving average series.
type TrendPoint struct {
	Date           string  `json:"date"`
	Price          float64 `json:"price"`
	MovingAverage  float64 `json:"moving_average"`
	AboveMovingAvg bool    `json:"above_moving_avg"`
}

// PriceChange represents a detected price anomaly.
type PriceChange struct {
	ProductID    string  `json:"product_id"`
	ProductName  string  `json:"product_name"`
	OldPrice     float64 `json:"old_price"`
	NewPrice     float64 `json:"new_price"`
	ChangePct    float64 `json:"change_pct"`
	Direction    string  `json:"direction"` // "up" or "down"
	DaysAnalyzed int     `json:"days_analyzed"`
}

// AnomalyResult holds the result of an anomaly check for a single product.
type AnomalyResult struct {
	ProductID   string  `json:"product_id"`
	ProductName string  `json:"product_name"`
	Area        string  `json:"area"`
	Current     float64 `json:"current_price"`
	Previous    float64 `json:"previous_price"`
	ChangePct   float64 `json:"change_pct"`
	IsAnomaly   bool    `json:"is_anomaly"`
}

// PriceAnomalyDetector detects significant price movements and outliers.
type PriceAnomalyDetector struct {
	priceRepo *repository.PriceRepository
	logger    *zap.Logger
}

// NewPriceAnomalyDetector creates a new PriceAnomalyDetector.
func NewPriceAnomalyDetector(priceRepo *repository.PriceRepository, logger *zap.Logger) *PriceAnomalyDetector {
	return &PriceAnomalyDetector{
		priceRepo: priceRepo,
		logger:    logger.Named("anomaly_detector"),
	}
}

// DetectSignificantChanges finds products with >15% price change in 3 days
// for the given area. Returns changes that exceed the threshold.
func (d *PriceAnomalyDetector) DetectSignificantChanges(ctx context.Context, area string) ([]PriceChange, error) {
	today := time.Now().Format("2006-01-02")
	threeDaysAgo := time.Now().AddDate(0, 0, -anomalyWindowDays).Format("2006-01-02")

	productIDs, err := d.priceRepo.GetDistinctProductIDs(ctx, area)
	if err != nil {
		return nil, fmt.Errorf("get product ids: %w", err)
	}

	var changes []PriceChange

	for _, productID := range productIDs {
		currentMedian, err := d.priceRepo.GetMedianPrice(ctx, productID, area, today)
		if err != nil || currentMedian == 0 {
			continue
		}

		oldMedian, err := d.priceRepo.GetMedianPrice(ctx, productID, area, threeDaysAgo)
		if err != nil || oldMedian == 0 {
			// Try earliest available price in the window
			subs, err := d.priceRepo.GetPricesForProductArea(ctx, productID, area, threeDaysAgo)
			if err != nil || len(subs) == 0 {
				continue
			}
			oldMedian = subs[len(subs)-1].Price
			if oldMedian == 0 {
				continue
			}
		}

		changePct := ((currentMedian - oldMedian) / oldMedian) * 100
		changePct = math.Round(changePct*100) / 100

		if math.Abs(changePct) >= significantChangeThreshold {
			direction := "up"
			if changePct < 0 {
				direction = "down"
			}

			productName, _ := d.priceRepo.GetProductName(ctx, productID)

			changes = append(changes, PriceChange{
				ProductID:    productID,
				ProductName:  productName,
				OldPrice:     oldMedian,
				NewPrice:     currentMedian,
				ChangePct:    changePct,
				Direction:    direction,
				DaysAnalyzed: anomalyWindowDays,
			})
		}
	}

	return changes, nil
}

// DetectAnomalies scans today's aggregated prices and flags those that moved
// more than the threshold percentage compared to the previous day.
func (d *PriceAnomalyDetector) DetectAnomalies(ctx context.Context, area string, thresholdPct float64) ([]AnomalyResult, error) {
	today := time.Now().Format("2006-01-02")

	prices, err := d.priceRepo.GetCurrentPrices(ctx, area, today)
	if err != nil {
		return nil, err
	}

	var anomalies []AnomalyResult
	for _, p := range prices {
		if p.ChangePct > thresholdPct || p.ChangePct < -thresholdPct {
			anomalies = append(anomalies, AnomalyResult{
				ProductID:   p.ProductID,
				ProductName: p.ProductName,
				Area:        p.Area,
				Current:     p.MedianPrice,
				Previous:    p.MedianPrice / (1 + p.ChangePct/100),
				ChangePct:   p.ChangePct,
				IsAnomaly:   true,
			})
		}
	}

	if anomalies == nil {
		anomalies = []AnomalyResult{}
	}

	d.logger.Info("anomaly detection completed",
		zap.String("area", area),
		zap.Int("total_products", len(prices)),
		zap.Int("anomalies", len(anomalies)),
	)

	return anomalies, nil
}

// CheckAlerts evaluates all active alerts against current prices and returns
// alerts that should fire.
func (d *PriceAnomalyDetector) CheckAlerts(ctx context.Context) ([]models.PriceAlert, error) {
	alerts, err := d.priceRepo.GetActiveAlerts(ctx)
	if err != nil {
		return nil, err
	}

	today := time.Now().Format("2006-01-02")
	var triggered []models.PriceAlert

	areaAlerts := make(map[string][]models.PriceAlert)
	for _, a := range alerts {
		areaAlerts[a.Area] = append(areaAlerts[a.Area], a)
	}

	for area, areaAlertList := range areaAlerts {
		prices, err := d.priceRepo.GetCurrentPrices(ctx, area, today)
		if err != nil {
			d.logger.Warn("failed to get prices for alert check", zap.String("area", area), zap.Error(err))
			continue
		}

		priceMap := make(map[string]models.AggregatedPrice)
		for _, p := range prices {
			priceMap[p.ProductID] = p
		}

		for _, alert := range areaAlertList {
			price, ok := priceMap[alert.ProductID]
			if !ok {
				continue
			}

			shouldTrigger := false
			switch alert.Direction {
			case "up":
				shouldTrigger = price.ChangePct >= alert.Threshold
			case "down":
				shouldTrigger = price.ChangePct <= -alert.Threshold
			case "both":
				shouldTrigger = price.ChangePct >= alert.Threshold || price.ChangePct <= -alert.Threshold
			}

			if shouldTrigger {
				triggered = append(triggered, alert)
			}
		}
	}

	if triggered == nil {
		triggered = []models.PriceAlert{}
	}

	return triggered, nil
}

// CalculateMovingAverage calculates a moving average for a product over a window of days.
func (d *PriceAnomalyDetector) CalculateMovingAverage(ctx context.Context, productID, area string, window int) ([]TrendPoint, error) {
	if window <= 0 {
		window = movingAverageWindow
	}

	fetchDays := window * 2
	trend, err := d.priceRepo.GetPriceTrend(ctx, productID, area, fetchDays)
	if err != nil {
		return nil, fmt.Errorf("get price trend: %w", err)
	}

	if len(trend.DataPoints) == 0 {
		return []TrendPoint{}, nil
	}

	prices := make([]float64, len(trend.DataPoints))
	for i, dp := range trend.DataPoints {
		prices[i] = dp.Price
	}

	result := make([]TrendPoint, 0, len(trend.DataPoints))
	for i, dp := range trend.DataPoints {
		start := i - window + 1
		if start < 0 {
			start = 0
		}
		count := i - start + 1
		sum := 0.0
		for j := start; j <= i; j++ {
			sum += prices[j]
		}
		ma := sum / float64(count)

		result = append(result, TrendPoint{
			Date:           dp.Date,
			Price:          dp.Price,
			MovingAverage:  math.Round(ma*100) / 100,
			AboveMovingAvg: dp.Price > ma,
		})
	}

	return result, nil
}

// DetectOutliers uses the IQR method to identify outlier price submissions.
// Returns outlier values and clean (non-outlier) values.
func (d *PriceAnomalyDetector) DetectOutliers(prices []float64) (outliers []float64, clean []float64) {
	if len(prices) < 4 {
		return nil, prices
	}

	sorted := make([]float64, len(prices))
	copy(sorted, prices)
	sort.Float64s(sorted)

	q1 := percentile(sorted, 25)
	q3 := percentile(sorted, 75)
	iqr := q3 - q1

	lowerBound := q1 - 1.5*iqr
	upperBound := q3 + 1.5*iqr

	for _, p := range prices {
		if p < lowerBound || p > upperBound {
			outliers = append(outliers, p)
		} else {
			clean = append(clean, p)
		}
	}

	return outliers, clean
}

// CalculateVolatility returns price volatility (coefficient of variation: stddev / mean).
// Returns 0 if mean is 0 or fewer than 2 data points.
func (d *PriceAnomalyDetector) CalculateVolatility(prices []float64) float64 {
	if len(prices) < 2 {
		return 0
	}

	mean := 0.0
	for _, p := range prices {
		mean += p
	}
	mean /= float64(len(prices))

	if mean == 0 {
		return 0
	}

	sumSqDiff := 0.0
	for _, p := range prices {
		diff := p - mean
		sumSqDiff += diff * diff
	}

	stddev := math.Sqrt(sumSqDiff / float64(len(prices)-1))
	return math.Round((stddev/mean)*10000) / 10000
}

// percentile calculates the p-th percentile of a sorted slice using linear interpolation.
func percentile(sorted []float64, p float64) float64 {
	if len(sorted) == 0 {
		return 0
	}
	if len(sorted) == 1 {
		return sorted[0]
	}

	rank := (p / 100) * float64(len(sorted)-1)
	lower := int(rank)
	upper := lower + 1
	if upper >= len(sorted) {
		return sorted[len(sorted)-1]
	}
	fraction := rank - float64(lower)
	return sorted[lower] + fraction*(sorted[upper]-sorted[lower])
}
