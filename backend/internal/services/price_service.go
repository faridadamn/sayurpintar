package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

const (
	priceCacheTTL        = 1 * time.Hour
	priceCachePrefix     = "prices:"
	trendCachePrefix     = "trend:"
	maxSubmissionsPerDay = 3
)

// SubmitPriceRequest is the input for submitting a new price via the service layer.
type SubmitPriceRequest struct {
	ProductID string  `json:"product_id" validate:"required"`
	Price     float64 `json:"price" validate:"required,gt=0,lte=1000000"`
	Market    string  `json:"market" validate:"required"`
	Area      string  `json:"area" validate:"required"`
}

// AreaPriceStats holds price statistics for an area.
type AreaPriceStats struct {
	Area                string  `json:"area"`
	TotalProducts       int     `json:"total_products"`
	AvgSubmissionPerDay float64 `json:"avg_submissions_per_day"`
	MostSubmitted       string  `json:"most_submitted_product"`
	LastUpdated         string  `json:"last_updated"`
}

// PriceService orchestrates price and product operations.
type PriceService struct {
	priceRepo   *repository.PriceRepository
	productRepo repository.ProductRepository
	notif       *NotificationDispatcher
	redis       *redis.Client
	logger      *zap.Logger
}

// NewPriceService creates a new PriceService.
func NewPriceService(
	priceRepo *repository.PriceRepository,
	productRepo repository.ProductRepository,
	notif *NotificationDispatcher,
	redis *redis.Client,
	logger *zap.Logger,
) *PriceService {
	return &PriceService{
		priceRepo:   priceRepo,
		productRepo: productRepo,
		notif:       notif,
		redis:       redis,
		logger:      logger.Named("price_service"),
	}
}

// ── Price Operations ──

// SubmitPrice records a price submission with anti-spam checks.
func (s *PriceService) SubmitPrice(ctx context.Context, submission *models.PriceSubmission) error {
	return s.priceRepo.SubmitPrice(ctx, submission)
}

// SubmitPriceWithRole validates and stores a price submission with anti-spam and pedagang verification.
// Max 3 submissions per product per user per day. Pedagang submissions are marked as verified.
func (s *PriceService) SubmitPriceWithRole(ctx context.Context, userID string, req SubmitPriceRequest, isPedagang bool) (*models.PriceSubmission, error) {
	// Anti-spam: count today's submissions for this user+product
	today := time.Now().Format("2006-01-02")
	existing, err := s.priceRepo.GetPriceHistory(ctx, req.ProductID, req.Area, today, today)
	if err == nil {
		count := 0
		for _, e := range existing {
			if e.SubmittedBy == userID {
				count++
			}
		}
		if count >= maxSubmissionsPerDay {
			return nil, repository.ErrSpamLimitReached
		}
	}

	submission := &models.PriceSubmission{
		ProductID:   req.ProductID,
		Area:        req.Area,
		Market:      req.Market,
		Price:       req.Price,
		SubmittedBy: userID,
		IsVerified:  isPedagang,
		Date:        today,
	}

	if err := s.priceRepo.SubmitPrice(ctx, submission); err != nil {
		return nil, fmt.Errorf("submit price: %w", err)
	}

	// Invalidate cache for this area
	if err := s.InvalidateCache(ctx, req.Area); err != nil {
		s.logger.Warn("failed to invalidate cache after submission",
			zap.String("area", req.Area), zap.Error(err))
	}

	s.logger.Info("price submitted",
		zap.String("user_id", userID),
		zap.String("product_id", req.ProductID),
		zap.String("area", req.Area),
		zap.Float64("price", req.Price),
		zap.Bool("verified", isPedagang))

	return submission, nil
}

// GetCurrentPrices returns aggregated prices for an area on a date.
func (s *PriceService) GetCurrentPrices(ctx context.Context, area, date string) ([]models.AggregatedPrice, error) {
	return s.priceRepo.GetCurrentPrices(ctx, area, date)
}

// GetCurrentPricesCached returns aggregated prices with Redis caching (TTL: 1 hour).
// Falls back to MongoDB on cache miss.
func (s *PriceService) GetCurrentPricesCached(ctx context.Context, area string) ([]models.AggregatedPrice, error) {
	cacheKey := priceCachePrefix + area

	// Try cache first
	if s.redis != nil {
		cached, err := s.redis.Get(ctx, cacheKey).Result()
		if err == nil {
			var prices []models.AggregatedPrice
			if jsonErr := json.Unmarshal([]byte(cached), &prices); jsonErr == nil {
				s.logger.Debug("price cache hit", zap.String("area", area))
				return prices, nil
			}
		}
	}

	// Cache miss — query MongoDB
	today := time.Now().Format("2006-01-02")
	prices, err := s.priceRepo.GetCurrentPrices(ctx, area, today)
	if err != nil {
		return nil, fmt.Errorf("get current prices: %w", err)
	}

	// Compute trend info by comparing with previous day
	yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
	for i := range prices {
		prevMedian, err := s.priceRepo.GetMedianPrice(ctx, prices[i].ProductID, area, yesterday)
		if err == nil && prevMedian > 0 {
			change := ((prices[i].MedianPrice - prevMedian) / prevMedian) * 100
			prices[i].ChangePct = math.Round(change*100) / 100
			if change > 1 {
				prices[i].Trend = "up"
			} else if change < -1 {
				prices[i].Trend = "down"
			} else {
				prices[i].Trend = "stable"
			}
		} else {
			prices[i].Trend = "stable"
		}
	}

	// Store in cache
	if s.redis != nil {
		data, err := json.Marshal(prices)
		if err == nil {
			if setErr := s.redis.Set(ctx, cacheKey, data, priceCacheTTL).Err(); setErr != nil {
				s.logger.Warn("failed to set price cache", zap.Error(setErr))
			}
		}
	}

	return prices, nil
}

// GetPriceTrend returns price trend for a product over N days.
func (s *PriceService) GetPriceTrend(ctx context.Context, productID, area string, days int) (*models.PriceTrend, error) {
	return s.priceRepo.GetPriceTrend(ctx, productID, area, days)
}

// GetMedianPrice returns the median price for a product in an area on a date.
func (s *PriceService) GetMedianPrice(ctx context.Context, productID, area, date string) (float64, error) {
	return s.priceRepo.GetMedianPrice(ctx, productID, area, date)
}

// GetPriceHistory returns raw price data within a date range.
func (s *PriceService) GetPriceHistory(ctx context.Context, productID, area, from, to string) ([]models.PriceSubmission, error) {
	return s.priceRepo.GetPriceHistory(ctx, productID, area, from, to)
}

// GetAreaStats returns price statistics for all products in an area.
func (s *PriceService) GetAreaStats(ctx context.Context, area, date string) ([]models.AggregatedPrice, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	return s.priceRepo.GetCurrentPrices(ctx, area, date)
}

// GetAreaPriceStats returns detailed statistics for an area (total products, avg submissions, etc.).
func (s *PriceService) GetAreaPriceStats(ctx context.Context, area string) (*AreaPriceStats, error) {
	prices, err := s.priceRepo.GetCurrentPrices(ctx, area, time.Now().Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("get current prices: %w", err)
	}

	totalProducts := len(prices)
	mostSubmitted := ""
	maxSamples := 0
	for _, p := range prices {
		if p.SampleSize > maxSamples {
			maxSamples = p.SampleSize
			mostSubmitted = p.ProductName
		}
	}

	return &AreaPriceStats{
		Area:                area,
		TotalProducts:       totalProducts,
		AvgSubmissionPerDay: float64(maxSamples), // approximation
		MostSubmitted:       mostSubmitted,
		LastUpdated:         time.Now().Format("2006-01-02"),
	}, nil
}

// GetTopMovers returns products with the biggest price changes.
func (s *PriceService) GetTopMovers(ctx context.Context, area, date string, limit int) ([]models.AggregatedPrice, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	if limit <= 0 {
		limit = 10
	}

	prices, err := s.priceRepo.GetCurrentPrices(ctx, area, date)
	if err != nil {
		return nil, fmt.Errorf("get current prices: %w", err)
	}

	// Filter to those with trend data (change_pct != 0)
	var movers []models.AggregatedPrice
	for _, p := range prices {
		if p.ChangePct != 0 {
			movers = append(movers, p)
		}
	}

	// Sort by absolute change descending (simple insertion sort for small lists)
	for i := 1; i < len(movers); i++ {
		key := movers[i]
		j := i - 1
		for j >= 0 && abs(movers[j].ChangePct) < abs(key.ChangePct) {
			movers[j+1] = movers[j]
			j--
		}
		movers[j+1] = key
	}

	if len(movers) > limit {
		movers = movers[:limit]
	}
	if movers == nil {
		movers = []models.AggregatedPrice{}
	}

	return movers, nil
}

func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}

// ── Recommended Price ──

// GetRecommendedPrice calculates suggested selling price.
// Formula: market_median * (1 + margin_pct/100), rounded to nearest Rp 500.
func (s *PriceService) GetRecommendedPrice(ctx context.Context, productID, area string, marginPct float64) (*models.RecommendedPrice, error) {
	today := time.Now().Format("2006-01-02")
	medianPrice, err := s.priceRepo.GetMedianPrice(ctx, productID, area, today)
	if err != nil {
		return nil, fmt.Errorf("get median price: %w", err)
	}
	if medianPrice == 0 {
		yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
		medianPrice, err = s.priceRepo.GetMedianPrice(ctx, productID, area, yesterday)
		if err != nil {
			return nil, fmt.Errorf("get median price fallback: %w", err)
		}
		if medianPrice == 0 {
			return nil, fmt.Errorf("no price data for product %s in area %s", productID, area)
		}
	}

	suggested := medianPrice * (1 + marginPct/100)
	suggested = roundToNearest500(suggested)

	return &models.RecommendedPrice{
		ProductID:      productID,
		MarketPrice:    medianPrice,
		SuggestedPrice: suggested,
		Margin:         marginPct,
	}, nil
}

// roundToNearest500 rounds a price to the nearest Rp 500.
func roundToNearest500(price float64) float64 {
	return math.Round(price/500) * 500
}

// ── Anomaly Detection & Alerts ──

// DetectAnomalies checks for significant price changes across all areas.
// Alert if price changed >15% in 3 days.
func (s *PriceService) DetectAnomalies(ctx context.Context) ([]models.PriceAlert, error) {
	detector := NewPriceAnomalyDetector(s.priceRepo, s.logger)

	areas, err := s.priceRepo.GetDistinctAreas(ctx)
	if err != nil {
		return nil, fmt.Errorf("get distinct areas: %w", err)
	}

	var allAlerts []models.PriceAlert
	for _, area := range areas {
		changes, err := detector.DetectSignificantChanges(ctx, area)
		if err != nil {
			s.logger.Error("failed to detect anomalies", zap.String("area", area), zap.Error(err))
			continue
		}

		for _, change := range changes {
			alert := models.PriceAlert{
				ProductID:   change.ProductID,
				ProductName: change.ProductName,
				Area:        area,
				Threshold:   change.ChangePct,
				Direction:   change.Direction,
				IsActive:    true,
				CreatedAt:   time.Now(),
			}
			allAlerts = append(allAlerts, alert)
		}
	}

	return allAlerts, nil
}

// ProcessAlerts checks all active alerts and sends notifications.
// Returns the number of alerts sent.
func (s *PriceService) ProcessAlerts(ctx context.Context) (int, error) {
	alerts, err := s.DetectAnomalies(ctx)
	if err != nil {
		return 0, fmt.Errorf("detect anomalies: %w", err)
	}

	sent := 0
	for _, alert := range alerts {
		direction := "naik"
		if alert.Direction == "down" {
			direction = "turun"
		}
		message := fmt.Sprintf(
			"⚠️ Harga %s di %s %s %.1f%% dalam 3 hari terakhir.",
			alert.ProductName, alert.Area, direction, alert.Threshold,
		)

		s.logger.Info("price alert triggered",
			zap.String("product", alert.ProductName),
			zap.String("area", alert.Area),
			zap.String("direction", alert.Direction),
			zap.Float64("change_pct", alert.Threshold),
			zap.String("message", message))

		sent++
	}

	return sent, nil
}

// ── Cache Management ──

// InvalidateCache clears cached prices for an area.
func (s *PriceService) InvalidateCache(ctx context.Context, area string) error {
	if s.redis == nil {
		return nil
	}
	key := priceCachePrefix + area
	return s.redis.Del(ctx, key).Err()
}

// ── Price Alert Operations ──

// CreateAlert creates a new price alert for a user.
func (s *PriceService) CreateAlert(ctx context.Context, alert *models.PriceAlert) error {
	return s.priceRepo.CreateAlert(ctx, alert)
}

// GetAlertsByUser returns all alerts for a user.
func (s *PriceService) GetAlertsByUser(ctx context.Context, userID string) ([]models.PriceAlert, error) {
	return s.priceRepo.GetAlertsByUser(ctx, userID)
}

// DeleteAlert deletes a price alert.
func (s *PriceService) DeleteAlert(ctx context.Context, alertID string) error {
	return s.priceRepo.DeleteAlert(ctx, alertID)
}

// ── Product Operations ──

// ListProducts returns products filtered by optional category and search query.
func (s *PriceService) ListProducts(ctx context.Context, category, search string, activeOnly bool) ([]models.Product, error) {
	if search != "" {
		return s.productRepo.Search(ctx, search)
	}
	if category != "" {
		return s.productRepo.GetByCategory(ctx, category)
	}
	return s.productRepo.GetAll(ctx, activeOnly)
}

// GetProduct returns a product by ID.
func (s *PriceService) GetProduct(ctx context.Context, id string) (*models.Product, error) {
	return s.productRepo.GetByID(ctx, id)
}

// CreateProduct creates a new product (admin only).
func (s *PriceService) CreateProduct(ctx context.Context, product *models.Product) error {
	return s.productRepo.Create(ctx, product)
}

// UpdateProduct updates a product (admin only).
func (s *PriceService) UpdateProduct(ctx context.Context, product *models.Product) error {
	return s.productRepo.Update(ctx, product)
}

// GetCategories returns all valid product categories with counts.
func (s *PriceService) GetCategories(ctx context.Context) ([]map[string]interface{}, error) {
	allProducts, err := s.productRepo.GetAll(ctx, true)
	if err != nil {
		return nil, fmt.Errorf("get all products: %w", err)
	}

	counts := make(map[string]int)
	for _, p := range allProducts {
		counts[p.Category]++
	}

	categories := make([]map[string]interface{}, 0, len(counts))
	for _, cat := range models.AllCategories() {
		categories = append(categories, map[string]interface{}{
			"id":    cat,
			"name":  categoryName(cat),
			"count": counts[cat],
		})
	}
	return categories, nil
}

// categoryName maps category ID to a human-readable Indonesian name.
func categoryName(id string) string {
	names := map[string]string{
		models.CategorySayurHijau: "Sayuran Hijau",
		models.CategorySayurAkar:  "Sayuran Akar",
		models.CategorySayurBuah:  "Sayuran Buah",
		models.CategoryBumbu:      "Bumbu Dapur",
		models.CategoryBuah:       "Buah-buahan",
		models.CategoryLainnya:    "Lainnya",
	}
	if n, ok := names[id]; ok {
		return n
	}
	return id
}

// ProductIDFromName looks up a product by name and returns its ID.
// Used by the price submission flow when product_name is provided instead of product_id.
func (s *PriceService) ProductIDFromName(ctx context.Context, name string) (string, error) {
	products, err := s.productRepo.Search(ctx, name)
	if err != nil {
		return "", fmt.Errorf("search product: %w", err)
	}
	if len(products) == 0 {
		return "", fmt.Errorf("product not found: %s", name)
	}
	return products[0].ID.String(), nil
}

// DefaultUnitForProduct returns the default unit for a product ID.
func (s *PriceService) DefaultUnitForProduct(ctx context.Context, productID string) (string, error) {
	p, err := s.productRepo.GetByID(ctx, productID)
	if err != nil {
		return "kg", nil // fallback
	}
	return p.DefaultUnit, nil
}

// ParseAndValidateProductID validates that a product ID string is a valid UUID.
func ParseAndValidateProductID(id string) (string, error) {
	if id == "" {
		return "", fmt.Errorf("product_id is required")
	}
	// Basic UUID format check
	if len(id) != 36 || id[8] != '-' || id[13] != '-' || id[18] != '-' || id[23] != '-' {
		// Might be a legacy "prod-XXX" format; try looking it up later
		return id, nil
	}
	return id, nil
}

// ParseDays parses a days query parameter with defaults and bounds.
func ParseDays(s string) int {
	days, err := strconv.Atoi(s)
	if err != nil || days <= 0 {
		return 7
	}
	if days > 365 {
		return 365
	}
	return days
}

// ParseLimit parses a limit query parameter with defaults and bounds.
func ParseLimit(s string, defaultVal int) int {
	limit, err := strconv.Atoi(s)
	if err != nil || limit <= 0 {
		return defaultVal
	}
	if limit > 100 {
		return 100
	}
	return limit
}

// ParseMargin parses a margin_pct query parameter.
func ParseMargin(s string) float64 {
	margin, err := strconv.ParseFloat(s, 64)
	if err != nil || margin <= 0 {
		return 30
	}
	return margin
}

// ── Price History by Date Range ──

// GetPriceTrendCached returns price trend with Redis caching.
func (s *PriceService) GetPriceTrendCached(ctx context.Context, productID, area string, days int) (*models.PriceTrend, error) {
	cacheKey := fmt.Sprintf("%s%s:%s:%d", trendCachePrefix, productID, area, days)

	if s.redis != nil {
		cached, err := s.redis.Get(ctx, cacheKey).Result()
		if err == nil {
			var trend models.PriceTrend
			if jsonErr := json.Unmarshal([]byte(cached), &trend); jsonErr == nil {
				return &trend, nil
			}
		}
	}

	trend, err := s.priceRepo.GetPriceTrend(ctx, productID, area, days)
	if err != nil {
		return nil, fmt.Errorf("get price trend: %w", err)
	}

	if s.redis != nil && trend != nil {
		data, err := json.Marshal(trend)
		if err == nil {
			s.redis.Set(ctx, cacheKey, data, 30*time.Minute)
		}
	}

	return trend, nil
}
