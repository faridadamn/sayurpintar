package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.uber.org/zap"
)

var (
	ErrPriceNotFound       = errors.New("price submission not found")
	ErrDuplicateSubmission = errors.New("duplicate price submission")
	ErrSpamLimitReached    = errors.New("spam limit reached: max 3 submissions per product per day")
	ErrAlertNotFound       = errors.New("price alert not found")
)

const (
	maxSubmissionsPerDay = 3
	pricesCollection     = "price_submissions"
	alertsCollection     = "price_alerts"
)

// PriceRepository handles price data in MongoDB.
type PriceRepository struct {
	col    *mongo.Collection
	alerts *mongo.Collection
	logger *zap.Logger
}

// NewPriceRepository creates a new PriceRepository.
func NewPriceRepository(db *mongo.Database, logger *zap.Logger) *PriceRepository {
	return &PriceRepository{
		col:    db.Collection(pricesCollection),
		alerts: db.Collection(alertsCollection),
		logger: logger.Named("price_repo"),
	}
}

// CreateIndexes creates MongoDB indexes for the prices and alerts collections.
func (r *PriceRepository) CreateIndexes(ctx context.Context) error {
	priceIndexes := []mongo.IndexModel{
		{
			Keys: bson.D{
				{Key: "product_id", Value: 1},
				{Key: "area", Value: 1},
				{Key: "date", Value: 1},
			},
		},
		{
			Keys: bson.D{
				{Key: "submitted_by", Value: 1},
				{Key: "product_id", Value: 1},
				{Key: "date", Value: 1},
			},
		},
		{
			Keys: bson.D{
				{Key: "area", Value: 1},
				{Key: "date", Value: 1},
			},
		},
		{
			Keys: bson.D{
				{Key: "product_id", Value: 1},
				{Key: "area", Value: 1},
				{Key: "created_at", Value: -1},
			},
		},
	}

	alertIndexes := []mongo.IndexModel{
		{
			Keys: bson.D{
				{Key: "user_id", Value: 1},
			},
		},
		{
			Keys: bson.D{
				{Key: "is_active", Value: 1},
				{Key: "product_id", Value: 1},
				{Key: "area", Value: 1},
			},
		},
	}

	if _, err := r.col.Indexes().CreateMany(ctx, priceIndexes); err != nil {
		return fmt.Errorf("create price indexes: %w", err)
	}

	if _, err := r.alerts.Indexes().CreateMany(ctx, alertIndexes); err != nil {
		return fmt.Errorf("create alert indexes: %w", err)
	}

	r.logger.Info("MongoDB price indexes created")
	return nil
}

// SubmitPrice adds a new price submission with anti-spam check.
// Anti-spam: max 3 submissions per product per user per day.
func (r *PriceRepository) SubmitPrice(ctx context.Context, submission *models.PriceSubmission) error {
	count, err := r.GetSubmissionCount(ctx, submission.SubmittedBy, submission.ProductID, submission.Date)
	if err != nil {
		return fmt.Errorf("check submission count: %w", err)
	}
	if count >= maxSubmissionsPerDay {
		return ErrSpamLimitReached
	}

	submission.CreatedAt = time.Now()
	submission.IsVerified = false

	result, err := r.col.InsertOne(ctx, submission)
	if err != nil {
		return fmt.Errorf("insert price submission: %w", err)
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		submission.ID = oid.Hex()
	}

	r.logger.Info("Price submitted",
		zap.String("product_id", submission.ProductID),
		zap.String("area", submission.Area),
		zap.Float64("price", submission.Price),
		zap.String("user_id", submission.SubmittedBy),
	)

	return nil
}

// GetSubmissionCount returns how many times a user submitted a product on a given date.
func (r *PriceRepository) GetSubmissionCount(ctx context.Context, userID, productID, date string) (int, error) {
	filter := bson.M{
		"submitted_by": userID,
		"product_id":   productID,
		"date":         date,
	}

	count, err := r.col.CountDocuments(ctx, filter)
	if err != nil {
		return 0, fmt.Errorf("count submissions: %w", err)
	}

	return int(count), nil
}

// GetCurrentPrices returns aggregated prices for an area on a given date.
// Uses MongoDB aggregation pipeline to calculate median.
func (r *PriceRepository) GetCurrentPrices(ctx context.Context, area string, date string) ([]models.AggregatedPrice, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"area": area,
			"date": date,
		}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: "$product_id"},
			{Key: "product_name", Value: bson.M{"$first": "$product_name"}},
			{Key: "unit", Value: bson.M{"$first": "$unit"}},
			{Key: "prices", Value: bson.M{"$push": "$price"}},
			{Key: "count", Value: bson.M{"$sum": 1}},
		}}},
		{{Key: "$project", Value: bson.D{
			{Key: "product_id", Value: "$_id"},
			{Key: "product_name", Value: 1},
			{Key: "unit", Value: 1},
			{Key: "sortedPrices", Value: bson.M{
				"$sortArray": bson.M{
					"input":  "$prices",
					"sortBy": 1,
				},
			}},
			{Key: "count", Value: 1},
		}}},
		{{Key: "$project", Value: bson.D{
			{Key: "product_id", Value: 1},
			{Key: "product_name", Value: 1},
			{Key: "unit", Value: 1},
			{Key: "median", Value: bson.M{
				"$arrayElemAt": bson.A{"$sortedPrices", bson.M{
					"$floor": bson.M{"$divide": bson.A{"$count", 2}},
				}},
			}},
			{Key: "min", Value: bson.M{"$min": "$sortedPrices"}},
			{Key: "max", Value: bson.M{"$max": "$sortedPrices"}},
			{Key: "count", Value: 1},
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, fmt.Errorf("aggregate prices: %w", err)
	}
	defer cursor.Close(ctx)

	var raw []bson.M
	if err := cursor.All(ctx, &raw); err != nil {
		return nil, fmt.Errorf("decode aggregated prices: %w", err)
	}

	prices := make([]models.AggregatedPrice, 0, len(raw))
	for _, doc := range raw {
		medianPrice := getFloat64(doc, "median")
		ap := models.AggregatedPrice{
			ProductID:   getString(doc, "product_id"),
			ProductName: getString(doc, "product_name"),
			Area:        area,
			Unit:        getString(doc, "unit"),
			MedianPrice: medianPrice,
			MinPrice:    getFloat64(doc, "min"),
			MaxPrice:    getFloat64(doc, "max"),
			SampleSize:  getInt(doc, "count"),
			Trend:       "stable",
			Date:        date,
		}

		// Calculate trend: compare with previous day
		prevDate := parsePrevDate(date)
		prevMedian, err := r.GetMedianPrice(ctx, ap.ProductID, area, prevDate)
		if err == nil && prevMedian > 0 {
			changePct := ((medianPrice - prevMedian) / prevMedian) * 100
			ap.ChangePct = changePct
			if changePct > 2 {
				ap.Trend = "up"
			} else if changePct < -2 {
				ap.Trend = "down"
			} else {
				ap.Trend = "stable"
			}
		}

		prices = append(prices, ap)
	}

	if prices == nil {
		prices = []models.AggregatedPrice{}
	}

	return prices, nil
}

// GetMedianPrice calculates median price for a product in an area on a date.
// Uses MongoDB aggregation with $sortArray for efficient median calculation.
func (r *PriceRepository) GetMedianPrice(ctx context.Context, productID, area, date string) (float64, error) {
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"product_id": productID,
			"area":       area,
			"date":       date,
		}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "prices", Value: bson.M{"$push": "$price"}},
			{Key: "count", Value: bson.M{"$sum": 1}},
		}}},
		{{Key: "$project", Value: bson.D{
			{Key: "sortedPrices", Value: bson.M{
				"$sortArray": bson.M{
					"input":  "$prices",
					"sortBy": 1,
				},
			}},
			{Key: "count", Value: 1},
		}}},
		{{Key: "$project", Value: bson.D{
			{Key: "median", Value: bson.M{
				"$arrayElemAt": bson.A{"$sortedPrices", bson.M{
					"$floor": bson.M{"$divide": bson.A{"$count", 2}},
				}},
			}},
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return 0, fmt.Errorf("aggregate median price: %w", err)
	}
	defer cursor.Close(ctx)

	var results []bson.M
	if err := cursor.All(ctx, &results); err != nil {
		return 0, fmt.Errorf("decode median price: %w", err)
	}

	if len(results) == 0 {
		return 0, nil
	}

	return getFloat64(results[0], "median"), nil
}

// GetPriceTrend returns price trend for a product over N days.
func (r *PriceRepository) GetPriceTrend(ctx context.Context, productID, area string, days int) (*models.PriceTrend, error) {
	if days <= 0 {
		days = 7
	}

	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -days)

	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"product_id": productID,
			"area":       area,
			"date": bson.M{
				"$gte": startDate.Format("2006-01-02"),
				"$lte": endDate.Format("2006-01-02"),
			},
		}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: "$date"},
			{Key: "prices", Value: bson.M{"$push": "$price"}},
			{Key: "count", Value: bson.M{"$sum": 1}},
			{Key: "product_name", Value: bson.M{"$first": "$product_name"}},
		}}},
		{{Key: "$sort", Value: bson.D{{Key: "_id", Value: 1}}}},
		{{Key: "$project", Value: bson.D{
			{Key: "date", Value: "$_id"},
			{Key: "sortedPrices", Value: bson.M{
				"$sortArray": bson.M{
					"input":  "$prices",
					"sortBy": 1,
				},
			}},
			{Key: "samples", Value: "$count"},
			{Key: "product_name", Value: 1},
		}}},
		{{Key: "$project", Value: bson.D{
			{Key: "date", Value: 1},
			{Key: "price", Value: bson.M{
				"$arrayElemAt": bson.A{"$sortedPrices", bson.M{
					"$floor": bson.M{"$divide": bson.A{"$samples", 2}},
				}},
			}},
			{Key: "samples", Value: 1},
			{Key: "product_name", Value: 1},
		}}},
	}

	cursor, err := r.col.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, fmt.Errorf("aggregate price trend: %w", err)
	}
	defer cursor.Close(ctx)

	var results []bson.M
	if err := cursor.All(ctx, &results); err != nil {
		return nil, fmt.Errorf("decode price trend: %w", err)
	}

	trend := &models.PriceTrend{
		ProductID:  productID,
		Area:       area,
		DataPoints: make([]models.TrendDataPoint, 0, len(results)),
	}

	if len(results) > 0 {
		trend.ProductName = getString(results[0], "product_name")
	}

	for _, doc := range results {
		trend.DataPoints = append(trend.DataPoints, models.TrendDataPoint{
			Date:    getString(doc, "date"),
			Price:   getFloat64(doc, "price"),
			Samples: getInt(doc, "samples"),
		})
	}

	return trend, nil
}

// GetPriceHistory returns raw price data for analysis within a date range.
func (r *PriceRepository) GetPriceHistory(ctx context.Context, productID, area string, from, to string) ([]models.PriceSubmission, error) {
	filter := bson.M{
		"product_id": productID,
		"area":       area,
	}

	if from != "" || to != "" {
		dateFilter := bson.M{}
		if from != "" {
			dateFilter["$gte"] = from
		}
		if to != "" {
			dateFilter["$lte"] = to
		}
		filter["date"] = dateFilter
	}

	opts := options.Find().
		SetSort(bson.D{{Key: "date", Value: 1}, {Key: "created_at", Value: 1}}).
		SetLimit(1000)

	cursor, err := r.col.Find(ctx, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("find price history: %w", err)
	}
	defer cursor.Close(ctx)

	var submissions []models.PriceSubmission
	if err := cursor.All(ctx, &submissions); err != nil {
		return nil, fmt.Errorf("decode price history: %w", err)
	}

	if submissions == nil {
		submissions = []models.PriceSubmission{}
	}

	return submissions, nil
}

// GetDistinctAreas returns all distinct areas that have price submissions.
func (r *PriceRepository) GetDistinctAreas(ctx context.Context) ([]string, error) {
	results, err := r.col.Distinct(ctx, "area", bson.M{})
	if err != nil {
		return nil, fmt.Errorf("distinct areas: %w", err)
	}
	areas := make([]string, 0, len(results))
	for _, v := range results {
		if s, ok := v.(string); ok {
			areas = append(areas, s)
		}
	}
	return areas, nil
}

// GetAllProductPrices returns all prices grouped by product for a given date across all areas.
func (r *PriceRepository) GetAllProductPrices(ctx context.Context, date string) (map[string]map[string][]float64, error) {
	filter := bson.M{"date": date}
	cursor, err := r.col.Find(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("find all prices: %w", err)
	}
	defer cursor.Close(ctx)

	var subs []models.PriceSubmission
	if err := cursor.All(ctx, &subs); err != nil {
		return nil, fmt.Errorf("decode all prices: %w", err)
	}

	result := make(map[string]map[string][]float64)
	for _, s := range subs {
		if result[s.ProductID] == nil {
			result[s.ProductID] = make(map[string][]float64)
		}
		result[s.ProductID][s.Area] = append(result[s.ProductID][s.Area], s.Price)
	}
	return result, nil
}

// ── Price Alert CRUD ──

// CreateAlert creates a new price alert.
func (r *PriceRepository) CreateAlert(ctx context.Context, alert *models.PriceAlert) error {
	alert.IsActive = true
	alert.CreatedAt = time.Now()

	result, err := r.alerts.InsertOne(ctx, alert)
	if err != nil {
		return fmt.Errorf("insert alert: %w", err)
	}

	if oid, ok := result.InsertedID.(primitive.ObjectID); ok {
		alert.ID = oid.Hex()
	}

	return nil
}

// GetAlertsByUser returns all price alerts for a user.
func (r *PriceRepository) GetAlertsByUser(ctx context.Context, userID string) ([]models.PriceAlert, error) {
	filter := bson.M{"user_id": userID}
	opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})

	cursor, err := r.alerts.Find(ctx, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("find alerts by user: %w", err)
	}
	defer cursor.Close(ctx)

	var alerts []models.PriceAlert
	if err := cursor.All(ctx, &alerts); err != nil {
		return nil, fmt.Errorf("decode alerts: %w", err)
	}

	if alerts == nil {
		alerts = []models.PriceAlert{}
	}

	return alerts, nil
}

// DeleteAlert deletes a price alert by ID.
func (r *PriceRepository) DeleteAlert(ctx context.Context, id string) error {
	oid, err := primitive.ObjectIDFromHex(id)
	if err != nil {
		return fmt.Errorf("invalid alert id: %w", err)
	}

	result, err := r.alerts.DeleteOne(ctx, bson.M{"_id": oid})
	if err != nil {
		return fmt.Errorf("delete alert: %w", err)
	}

	if result.DeletedCount == 0 {
		return ErrAlertNotFound
	}

	return nil
}

// GetActiveAlerts returns all active price alerts.
func (r *PriceRepository) GetActiveAlerts(ctx context.Context) ([]models.PriceAlert, error) {
	filter := bson.M{"is_active": true}

	cursor, err := r.alerts.Find(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("find active alerts: %w", err)
	}
	defer cursor.Close(ctx)

	var alerts []models.PriceAlert
	if err := cursor.All(ctx, &alerts); err != nil {
		return nil, fmt.Errorf("decode active alerts: %w", err)
	}

	if alerts == nil {
		alerts = []models.PriceAlert{}
	}

	return alerts, nil
}

// UpdateAlertTriggered updates the last_triggered timestamp of an alert.
func (r *PriceRepository) UpdateAlertTriggered(ctx context.Context, alertID string) error {
	oid, err := primitive.ObjectIDFromHex(alertID)
	if err != nil {
		return fmt.Errorf("invalid alert id: %w", err)
	}

	now := time.Now()
	result, err := r.alerts.UpdateOne(ctx, bson.M{"_id": oid}, bson.M{
		"$set": bson.M{"last_triggered": now},
	})
	if err != nil {
		return fmt.Errorf("update alert triggered: %w", err)
	}

	if result.MatchedCount == 0 {
		return ErrAlertNotFound
	}

	return nil
}

// ── Helper functions ──

func getString(m bson.M, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func getFloat64(m bson.M, key string) float64 {
	if v, ok := m[key]; ok {
		switch val := v.(type) {
		case float64:
			return val
		case int32:
			return float64(val)
		case int64:
			return float64(val)
		case primitive.Decimal128:
			f, _, _ := val.BigInt()
			return float64(f.Int64())
		}
	}
	return 0
}

func getInt(m bson.M, key string) int {
	if v, ok := m[key]; ok {
		switch val := v.(type) {
		case int32:
			return int(val)
		case int64:
			return int(val)
		case float64:
			return int(val)
		}
	}
	return 0
}

func parsePrevDate(date string) string {
	t, err := time.Parse("2006-01-02", date)
	if err != nil {
		return ""
	}
	return t.AddDate(0, 0, -1).Format("2006-01-02")
}
