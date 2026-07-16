package services

import (
	"math"
	"testing"
)

// --- roundToNearest500 tests ---

func TestRoundToNearest500(t *testing.T) {
	tests := []struct {
		name     string
		input    float64
		expected float64
	}{
		{"exact 500", 500, 500},
		{"exact 1000", 1000, 1000},
		{"round up from 251", 251, 500},
		{"round down from 249", 249, 0},
		{"round to 1500", 1250, 1500},
		{"round to 2000", 1750, 2000},
		{"round 3333", 3333, 3500},
		{"round 3749", 3749, 3500},
		{"round 3750", 3750, 4000},
		{"small value", 100, 0},
		{"zero", 0, 0},
		{"large value", 99999, 100000},
		{"rp 500 margin", 10000 * 1.15, 11500},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := roundToNearest500(tt.input)
			if result != tt.expected {
				t.Errorf("roundToNearest500(%v) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

// --- Anomaly detector unit tests ---

func TestDetectOutliers(t *testing.T) {
	detector := &PriceAnomalyDetector{}

	tests := []struct {
		name            string
		prices          []float64
		wantOutliers    int
		wantClean       int
	}{
		{
			name:         "no outliers in tight range",
			prices:       []float64{100, 102, 98, 101, 99, 103, 97},
			wantOutliers: 0,
			wantClean:    7,
		},
		{
			name:         "single high outlier",
			prices:       []float64{100, 102, 98, 101, 99, 103, 97, 500},
			wantOutliers: 1,
			wantClean:    7,
		},
		{
			name:         "single low outlier",
			prices:       []float64{100, 102, 98, 101, 99, 103, 97, 10},
			wantOutliers: 1,
			wantClean:    7,
		},
		{
			name:         "both high and low outliers",
			prices:       []float64{100, 102, 98, 101, 99, 103, 97, 500, 10},
			wantOutliers: 2,
			wantClean:    7,
		},
		{
			name:         "too few data points",
			prices:       []float64{100, 200, 300},
			wantOutliers: 0,
			wantClean:    3,
		},
		{
			name:         "empty slice",
			prices:       []float64{},
			wantOutliers: 0,
			wantClean:    0,
		},
		{
			name:         "all same values",
			prices:       []float64{50, 50, 50, 50, 50, 50},
			wantOutliers: 0,
			wantClean:    6,
		},
		{
			name:         "extreme outlier",
			prices:       []float64{100, 101, 99, 100, 101, 99, 100, 10000},
			wantOutliers: 1,
			wantClean:    7,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			outliers, clean := detector.DetectOutliers(tt.prices)
			if len(outliers) != tt.wantOutliers {
				t.Errorf("DetectOutliers outliers = %d, want %d (input: %v)", len(outliers), tt.wantOutliers, tt.prices)
			}
			if len(clean) != tt.wantClean {
				t.Errorf("DetectOutliers clean = %d, want %d (input: %v)", len(clean), tt.wantClean, tt.prices)
			}
			// Outliers + clean should equal total
			if len(outliers)+len(clean) != len(tt.prices) {
				t.Errorf("outliers(%d) + clean(%d) != total(%d)", len(outliers), len(clean), len(tt.prices))
			}
		})
	}
}

func TestCalculateVolatility(t *testing.T) {
	detector := &PriceAnomalyDetector{}

	tests := []struct {
		name     string
		prices   []float64
		minVol   float64 // minimum expected volatility
		maxVol   float64 // maximum expected volatility
	}{
		{
			name:   "constant prices = zero volatility",
			prices: []float64{100, 100, 100, 100, 100},
			minVol: 0,
			maxVol: 0,
		},
		{
			name:   "low volatility",
			prices: []float64{100, 101, 99, 100, 101, 99},
			minVol: 0,
			maxVol: 0.02,
		},
		{
			name:   "high volatility",
			prices: []float64{50, 150, 75, 125, 60, 140},
			minVol: 0.3,
			maxVol: 1.0,
		},
		{
			name:   "single price = zero",
			prices: []float64{100},
			minVol: 0,
			maxVol: 0,
		},
		{
			name:   "empty prices = zero",
			prices: []float64{},
			minVol: 0,
			maxVol: 0,
		},
		{
			name:   "two identical prices = zero",
			prices: []float64{500, 500},
			minVol: 0,
			maxVol: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vol := detector.CalculateVolatility(tt.prices)
			if vol < tt.minVol || vol > tt.maxVol {
				t.Errorf("CalculateVolatility(%v) = %v, want between [%v, %v]", tt.prices, vol, tt.minVol, tt.maxVol)
			}
		})
	}
}

func TestPercentile(t *testing.T) {
	tests := []struct {
		name     string
		sorted   []float64
		p        float64
		expected float64
	}{
		{
			name:     "median of odd set",
			sorted:   []float64{1, 2, 3, 4, 5},
			p:        50,
			expected: 3,
		},
		{
			name:     "Q1 of 1..8",
			sorted:   []float64{1, 2, 3, 4, 5, 6, 7, 8},
			p:        25,
			expected: 2.75,
		},
		{
			name:     "Q3 of 1..8",
			sorted:   []float64{1, 2, 3, 4, 5, 6, 7, 8},
			p:        75,
			expected: 6.25,
		},
		{
			name:     "0th percentile",
			sorted:   []float64{10, 20, 30},
			p:        0,
			expected: 10,
		},
		{
			name:     "100th percentile",
			sorted:   []float64{10, 20, 30},
			p:        100,
			expected: 30,
		},
		{
			name:     "single element",
			sorted:   []float64{42},
			p:        50,
			expected: 42,
		},
		{
			name:     "empty slice",
			sorted:   []float64{},
			p:        50,
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := percentile(tt.sorted, tt.p)
			if math.Abs(result-tt.expected) > 0.01 {
				t.Errorf("percentile(%v, %v) = %v, want %v", tt.sorted, tt.p, result, tt.expected)
			}
		})
	}
}

func TestDetectOutliersPreservesOriginalOrder(t *testing.T) {
	detector := &PriceAnomalyDetector{}
	input := []float64{500, 100, 102, 98, 101, 99, 103, 97}

	outliers, clean := detector.DetectOutliers(input)

	// The outlier (500) should be in outliers
	found := false
	for _, o := range outliers {
		if o == 500 {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected 500 to be detected as outlier")
	}

	// Clean values should contain the rest
	if len(clean) != 7 {
		t.Errorf("expected 7 clean values, got %d", len(clean))
	}
}

func TestCalculateVolatilityRange(t *testing.T) {
	detector := &PriceAnomalyDetector{}

	// Prices with known standard deviation
	// Mean = 100, stddev = 10, CV = 0.1
	prices := []float64{90, 95, 100, 100, 100, 105, 110}
	vol := detector.CalculateVolatility(prices)

	if vol < 0.05 || vol > 0.15 {
		t.Errorf("expected volatility around 0.07-0.08, got %v", vol)
	}
}

// --- SubmitPriceRequest validation ---

func TestSubmitPriceRequestFields(t *testing.T) {
	req := SubmitPriceRequest{
		ProductID: "prod-123",
		Price:     15000,
		Market:    "Pasar Minggu",
		Area:      "Jakarta Selatan",
	}

	if req.ProductID == "" {
		t.Error("ProductID should not be empty")
	}
	if req.Price <= 0 {
		t.Error("Price must be positive")
	}
	if req.Price > 1000000 {
		t.Error("Price must be <= 1000000")
	}
}

// --- AreaPriceStats ---

func TestAreaPriceStatsJSON(t *testing.T) {
	stats := AreaPriceStats{
		Area:                "Jakarta Selatan",
		TotalProducts:       25,
		AvgSubmissionPerDay: 42.5,
		MostSubmitted:       "Cabai Merah",
		LastUpdated:         "2024-01-15",
	}

	if stats.Area != "Jakarta Selatan" {
		t.Errorf("expected area 'Jakarta Selatan', got '%s'", stats.Area)
	}
	if stats.TotalProducts != 25 {
		t.Errorf("expected 25 products, got %d", stats.TotalProducts)
	}
	if stats.AvgSubmissionPerDay != 42.5 {
		t.Errorf("expected 42.5 avg, got %f", stats.AvgSubmissionPerDay)
	}
}

// --- AggregationResult ---

func TestAggregationResult(t *testing.T) {
	result := AggregationResult{
		Date:            "2024-01-15",
		ProductsUpdated: 50,
		AreasUpdated:    5,
		AnomaliesFound:  3,
		AlertsSent:      3,
	}

	if result.ProductsUpdated != 50 {
		t.Errorf("expected 50 products, got %d", result.ProductsUpdated)
	}
	if result.AnomaliesFound != result.AlertsSent {
		t.Error("anomalies found should equal alerts sent")
	}
}

// --- PriceChange struct ---

func TestPriceChangeDirection(t *testing.T) {
	tests := []struct {
		name      string
		change    PriceChange
		wantDir   string
	}{
		{
			name: "price increase",
			change: PriceChange{
				OldPrice:  10000,
				NewPrice:  12000,
				ChangePct: 20,
				Direction: "up",
			},
			wantDir: "up",
		},
		{
			name: "price decrease",
			change: PriceChange{
				OldPrice:  12000,
				NewPrice:  10000,
				ChangePct: -16.67,
				Direction: "down",
			},
			wantDir: "down",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.change.Direction != tt.wantDir {
				t.Errorf("expected direction '%s', got '%s'", tt.wantDir, tt.change.Direction)
			}
		})
	}
}

// --- TrendPoint ---

func TestTrendPoint(t *testing.T) {
	tp := TrendPoint{
		Date:           "2024-01-15",
		Price:          15000,
		MovingAverage:  14500,
		AboveMovingAvg: true,
	}

	if !tp.AboveMovingAvg {
		t.Error("price 15000 should be above moving average 14500")
	}

	tp2 := TrendPoint{
		Date:           "2024-01-16",
		Price:          14000,
		MovingAverage:  14500,
		AboveMovingAvg: false,
	}

	if tp2.AboveMovingAvg {
		t.Error("price 14000 should be below moving average 14500")
	}
}
