package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

const (
	topMoversCachePrefix = "top_movers:"
	topMoversCacheTTL    = 30 * time.Minute
	priceCacheKeyFmt     = "prices:current:%s:%s" // area:date
	topMoversKeyFmt      = "prices:topmovers:%s:%s"
)

// AggregationResult holds the outcome of a daily aggregation run.
type AggregationResult struct {
	Date            string `json:"date"`
	ProductsUpdated int    `json:"products_updated"`
	AreasUpdated    int    `json:"areas_updated"`
	AnomaliesFound  int    `json:"anomalies_found"`
	AlertsSent      int    `json:"alerts_sent"`
}

// PriceAggregator runs scheduled aggregation jobs and caches price summaries.
type PriceAggregator struct {
	priceRepo *repository.PriceRepository
	redis     *redis.Client
	logger    *zap.Logger
}

// NewPriceAggregator creates a new PriceAggregator.
func NewPriceAggregator(priceRepo *repository.PriceRepository, redis *redis.Client, logger *zap.Logger) *PriceAggregator {
	return &PriceAggregator{
		priceRepo: priceRepo,
		redis:     redis,
		logger:    logger.Named("price_aggregator"),
	}
}

// AggregateDaily runs at midnight to aggregate daily prices.
// Calculates median, min, max for each product/area combination.
// Stores results in Redis cache and detects anomalies.
func (a *PriceAggregator) AggregateDaily(ctx context.Context) (*AggregationResult, error) {
	today := time.Now().Format("2006-01-02")
	result := &AggregationResult{Date: today}

	a.logger.Info("starting daily price aggregation", zap.String("date", today))

	areas, err := a.priceRepo.GetDistinctAreas(ctx)
	if err != nil {
		return nil, fmt.Errorf("get distinct areas: %w", err)
	}
	result.AreasUpdated = len(areas)

	productSet := make(map[string]bool)

	for _, area := range areas {
		count, err := a.AggregateArea(ctx, area, today)
		if err != nil {
			a.logger.Error("failed to aggregate area",
				zap.String("area", area), zap.Error(err))
			continue
		}

		// Track unique products for this area
		productIDs, _ := a.priceRepo.GetDistinctProductIDs(ctx, area)
		for _, pid := range productIDs {
			productSet[pid] = true
		}

		a.logger.Debug("aggregated area",
			zap.String("area", area),
			zap.Int("products", count))
	}

	result.ProductsUpdated = len(productSet)

	// Detect anomalies
	anomalyDetector := NewPriceAnomalyDetector(a.priceRepo, a.logger)
	anomalyCount := 0
	alertsSent := 0

	for _, area := range areas {
		changes, err := anomalyDetector.DetectSignificantChanges(ctx, area)
		if err != nil {
			a.logger.Error("anomaly detection failed",
				zap.String("area", area), zap.Error(err))
			continue
		}

		for _, change := range changes {
			anomalyCount++
			direction := "naik"
			if change.Direction == "down" {
				direction = "turun"
			}
			a.logger.Info("price anomaly detected",
				zap.String("product", change.ProductName),
				zap.String("area", area),
				zap.String("direction", direction),
				zap.Float64("change_pct", change.ChangePct),
				zap.Float64("old_price", change.OldPrice),
				zap.Float64("new_price", change.NewPrice))
			alertsSent++
		}
	}

	result.AnomaliesFound = anomalyCount
	result.AlertsSent = alertsSent

	a.logger.Info("daily aggregation complete",
		zap.String("date", today),
		zap.Int("products_updated", result.ProductsUpdated),
		zap.Int("areas_updated", result.AreasUpdated),
		zap.Int("anomalies_found", result.AnomaliesFound),
		zap.Int("alerts_sent", result.AlertsSent))

	return result, nil
}

// AggregateArea computes and caches prices for a single area/date.
func (a *PriceAggregator) AggregateArea(ctx context.Context, area, date string) (int, error) {
	prices, err := a.priceRepo.GetCurrentPrices(ctx, area, date)
	if err != nil {
		return 0, fmt.Errorf("get current prices for %s: %w", area, err)
	}

	data, err := json.Marshal(prices)
	if err != nil {
		return 0, fmt.Errorf("marshal prices: %w", err)
	}

	key := fmt.Sprintf(priceCacheKeyFmt, area, date)
	if err := a.redis.Set(ctx, key, data, priceCacheTTL).Err(); err != nil {
		a.logger.Warn("failed to cache prices", zap.String("key", key), zap.Error(err))
	}

	topKey := fmt.Sprintf(topMoversKeyFmt, area, date)
	topData, err := json.Marshal(prices)
	if err == nil {
		if err := a.redis.Set(ctx, topKey, topData, priceCacheTTL).Err(); err != nil {
			a.logger.Warn("failed to cache top movers", zap.String("key", topKey), zap.Error(err))
		}
	}

	return len(prices), nil
}

// AggregateAll runs daily aggregation for all known areas and caches the results.
func (a *PriceAggregator) AggregateAll(ctx context.Context) error {
	today := time.Now().Format("2006-01-02")

	areas, err := a.priceRepo.GetDistinctAreas(ctx)
	if err != nil {
		return fmt.Errorf("get distinct areas: %w", err)
	}

	totalCached := 0
	for _, area := range areas {
		count, err := a.AggregateArea(ctx, area, today)
		if err != nil {
			a.logger.Warn("failed to aggregate area",
				zap.String("area", area), zap.Error(err))
			continue
		}
		totalCached += count
	}

	a.logger.Info("aggregation complete",
		zap.String("date", today),
		zap.Int("areas", len(areas)),
		zap.Int("products_cached", totalCached))

	return nil
}

// RefreshCache updates Redis cache for all active areas.
func (a *PriceAggregator) RefreshCache(ctx context.Context) error {
	areas, err := a.priceRepo.GetDistinctAreas(ctx)
	if err != nil {
		return fmt.Errorf("get distinct areas: %w", err)
	}

	today := time.Now().Format("2006-01-02")
	for _, area := range areas {
		count, err := a.AggregateArea(ctx, area, today)
		if err != nil {
			a.logger.Error("failed to refresh cache for area",
				zap.String("area", area), zap.Error(err))
			continue
		}
		a.logger.Debug("refreshed cache", zap.String("area", area), zap.Int("products", count))
	}

	a.logger.Info("cache refresh complete", zap.Int("areas", len(areas)))
	return nil
}

// GetCachedPrices retrieves cached prices from Redis if available.
func (a *PriceAggregator) GetCachedPrices(ctx context.Context, area, date string) (string, error) {
	key := fmt.Sprintf(priceCacheKeyFmt, area, date)
	return a.redis.Get(ctx, key).Result()
}

// GetTopMovers returns products with the biggest price changes today.
func (a *PriceAggregator) GetTopMovers(ctx context.Context, area string, limit int) ([]models.AggregatedPrice, error) {
	if limit <= 0 {
		limit = 10
	}

	// Try cache first
	cacheKey := fmt.Sprintf("%s%s:%d", topMoversCachePrefix, area, limit)
	if a.redis != nil {
		cached, err := a.redis.Get(ctx, cacheKey).Result()
		if err == nil {
			var movers []models.AggregatedPrice
			if jsonErr := json.Unmarshal([]byte(cached), &movers); jsonErr == nil {
				return movers, nil
			}
		}
	}

	// Get current prices with trend info
	prices, err := a.getCurrentPricesWithTrend(ctx, area)
	if err != nil {
		return nil, fmt.Errorf("get prices with trend: %w", err)
	}

	// Sort by absolute change percentage (descending)
	sort.Slice(prices, func(i, j int) bool {
		return math.Abs(prices[i].ChangePct) > math.Abs(prices[j].ChangePct)
	})

	if len(prices) > limit {
		prices = prices[:limit]
	}

	// Cache result
	if a.redis != nil && len(prices) > 0 {
		data, err := json.Marshal(prices)
		if err == nil {
			a.redis.Set(ctx, cacheKey, data, topMoversCacheTTL)
		}
	}

	return prices, nil
}

// getCurrentPricesWithTrend returns aggregated prices with trend comparison.
func (a *PriceAggregator) getCurrentPricesWithTrend(ctx context.Context, area string) ([]models.AggregatedPrice, error) {
	today := time.Now().Format("2006-01-02")
	return a.priceRepo.GetCurrentPrices(ctx, area, today)
}
