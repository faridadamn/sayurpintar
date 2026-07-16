package models

import "time"

// PriceSubmission represents a crowdsourced price data point submitted by a user.
type PriceSubmission struct {
	ID          string    `json:"id" bson:"_id,omitempty"`
	ProductID   string    `json:"product_id" bson:"product_id"`
	ProductName string    `json:"product_name" bson:"product_name"`
	Area        string    `json:"area" bson:"area"`
	Market      string    `json:"market" bson:"market"`
	Price       float64   `json:"price" bson:"price"`
	Unit        string    `json:"unit" bson:"unit"`
	SubmittedBy string    `json:"submitted_by" bson:"submitted_by"`
	IsVerified  bool      `json:"is_verified" bson:"is_verified"`
	Date        string    `json:"date" bson:"date"` // YYYY-MM-DD
	CreatedAt   time.Time `json:"created_at" bson:"created_at"`
}

// AggregatedPrice holds aggregated price statistics for a product in an area on a date.
type AggregatedPrice struct {
	ProductID   string  `json:"product_id"`
	ProductName string  `json:"product_name"`
	Area        string  `json:"area"`
	MedianPrice float64 `json:"median_price"`
	MinPrice    float64 `json:"min_price"`
	MaxPrice    float64 `json:"max_price"`
	SampleSize  int     `json:"sample_size"`
	Unit        string  `json:"unit"`
	Trend       string  `json:"trend"` // "up", "down", "stable"
	ChangePct   float64 `json:"change_pct"`
	Date        string  `json:"date"`
}

// PriceTrend holds price trend data for a product over a range of dates.
type PriceTrend struct {
	ProductID   string           `json:"product_id"`
	ProductName string           `json:"product_name"`
	Area        string           `json:"area"`
	DataPoints  []TrendDataPoint `json:"data_points"`
}

// TrendDataPoint is a single data point in a price trend series.
type TrendDataPoint struct {
	Date    string  `json:"date"`
	Price   float64 `json:"price"`
	Samples int     `json:"samples"`
}

// PriceAlert represents a user-configured price alert threshold.
type PriceAlert struct {
	ID            string     `json:"id" bson:"_id,omitempty"`
	UserID        string     `json:"user_id" bson:"user_id"`
	ProductID     string     `json:"product_id" bson:"product_id"`
	ProductName   string     `json:"product_name" bson:"product_name"`
	Area          string     `json:"area" bson:"area"`
	Threshold     float64    `json:"threshold" bson:"threshold"` // % change threshold
	Direction     string     `json:"direction" bson:"direction"` // "up", "down", "both"
	IsActive      bool       `json:"is_active" bson:"is_active"`
	LastTriggered *time.Time `json:"last_triggered,omitempty" bson:"last_triggered"`
	CreatedAt     time.Time  `json:"created_at" bson:"created_at"`
}

// RecommendedPrice holds the suggested selling price for a product.
type RecommendedPrice struct {
	ProductID      string  `json:"product_id"`
	ProductName    string  `json:"product_name"`
	MarketPrice    float64 `json:"market_price"`
	SuggestedPrice float64 `json:"suggested_price"`
	Margin         float64 `json:"margin_pct"`
	Unit           string  `json:"unit"`
}
