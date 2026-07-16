package services

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

const (
	nominatimSearchURL  = "https://nominatim.openstreetmap.org/search"
	nominatimReverseURL = "https://nominatim.openstreetmap.org/reverse"
	geocodeCacheTTL     = 30 * 24 * time.Hour // 30 days
	geocodeCachePrefix  = "geocode:"
	userAgent           = "SayurPintar/1.0 (https://sayurpintar.id)"
	nominatimRateDelay  = 1100 * time.Millisecond // slightly over 1 req/sec to be safe
)

// GeoResult holds the result of a geocoding operation.
type GeoResult struct {
	Address   string  `json:"address"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	City      string  `json:"city"`
	Area      string  `json:"area"`
}

// GeocodingService handles address ↔ GPS coordinate conversion using Nominatim.
type GeocodingService struct {
	httpClient *http.Client
	cache      *redis.Client
	logger     *zap.Logger
	lastReqAt  time.Time
}

// NewGeocodingService creates a new GeocodingService.
func NewGeocodingService(redis *redis.Client, logger *zap.Logger) *GeocodingService {
	return &GeocodingService{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		cache:  redis,
		logger: logger,
	}
}

// cacheKey generates a Redis cache key from the input string.
func cacheKey(prefix, input string) string {
	h := sha256.Sum256([]byte(input))
	return fmt.Sprintf("%s%x", prefix, h[:8])
}

// rateLimit blocks until at least 1.1 seconds have passed since the last Nominatim request.
func (s *GeocodingService) rateLimit() {
	if !s.lastReqAt.IsZero() {
		elapsed := time.Since(s.lastReqAt)
		if elapsed < nominatimRateDelay {
			time.Sleep(nominatimRateDelay - elapsed)
		}
	}
	s.lastReqAt = time.Now()
}

// Geocode converts an address string to GPS coordinates using Nominatim.
// Results are cached in Redis for 30 days.
func (s *GeocodingService) Geocode(ctx context.Context, address string) (*GeoResult, error) {
	if address == "" {
		return nil, fmt.Errorf("address is required")
	}

	// Check cache
	key := cacheKey(geocodeCachePrefix, "fwd:"+address)
	cached, err := s.cache.Get(ctx, key).Result()
	if err == nil {
		var result GeoResult
		if json.Unmarshal([]byte(cached), &result) == nil {
			return &result, nil
		}
	}

	// Rate limit
	s.rateLimit()

	// Build request
	params := url.Values{
		"q":              {address},
		"format":         {"json"},
		"countrycodes":   {"id"},
		"limit":          {"1"},
		"addressdetails": {"1"},
	}

	reqURL := nominatimSearchURL + "?" + params.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create geocode request: %w", err)
	}
	req.Header.Set("User-Agent", userAgent)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("geocode request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read geocode response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		s.logger.Warn("nominatim search error",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(body)),
		)
		return nil, fmt.Errorf("nominatim returned status %d", resp.StatusCode)
	}

	var results []nominatimSearchResult
	if err := json.Unmarshal(body, &results); err != nil {
		return nil, fmt.Errorf("parse geocode response: %w", err)
	}

	if len(results) == 0 {
		return nil, fmt.Errorf("no results found for address: %s", address)
	}

	r := results[0]
	result := &GeoResult{
		Address:   r.DisplayName,
		Latitude:  parseFloat(r.Lat),
		Longitude: parseFloat(r.Lon),
		City:      extractAddressPart(r.Address, "city", "town", "village", "municipality"),
		Area:      extractAddressPart(r.Address, "suburb", "neighbourhood", "quarter", "district"),
	}

	// Cache result
	if data, err := json.Marshal(result); err == nil {
		s.cache.Set(ctx, key, data, geocodeCacheTTL)
	}

	return result, nil
}

// ReverseGeocode converts GPS coordinates to an address string using Nominatim.
// Results are cached in Redis for 30 days.
func (s *GeocodingService) ReverseGeocode(ctx context.Context, lat, lng float64) (*GeoResult, error) {
	// Check cache
	cacheInput := fmt.Sprintf("rev:%.6f,%.6f", lat, lng)
	key := cacheKey(geocodeCachePrefix, cacheInput)
	cached, err := s.cache.Get(ctx, key).Result()
	if err == nil {
		var result GeoResult
		if json.Unmarshal([]byte(cached), &result) == nil {
			return &result, nil
		}
	}

	// Rate limit
	s.rateLimit()

	// Build request
	params := url.Values{
		"lat":            {fmt.Sprintf("%.6f", lat)},
		"lon":            {fmt.Sprintf("%.6f", lng)},
		"format":         {"json"},
		"addressdetails": {"1"},
	}

	reqURL := nominatimReverseURL + "?" + params.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create reverse geocode request: %w", err)
	}
	req.Header.Set("User-Agent", userAgent)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("reverse geocode request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read reverse geocode response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		s.logger.Warn("nominatim reverse error",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(body)),
		)
		return nil, fmt.Errorf("nominatim returned status %d", resp.StatusCode)
	}

	var r nominatimReverseResult
	if err := json.Unmarshal(body, &r); err != nil {
		return nil, fmt.Errorf("parse reverse geocode response: %w", err)
	}

	if r.DisplayName == "" {
		return nil, fmt.Errorf("no address found for coordinates: %.6f, %.6f", lat, lng)
	}

	result := &GeoResult{
		Address:   r.DisplayName,
		Latitude:  parseFloat(r.Lat),
		Longitude: parseFloat(r.Lon),
		City:      extractAddressPart(r.Address, "city", "town", "village", "municipality"),
		Area:      extractAddressPart(r.Address, "suburb", "neighbourhood", "quarter", "district"),
	}

	// Cache result
	if data, err := json.Marshal(result); err == nil {
		s.cache.Set(ctx, key, data, geocodeCacheTTL)
	}

	return result, nil
}

// --- Nominatim response types ---

type nominatimSearchResult struct {
	DisplayName string            `json:"display_name"`
	Lat         string            `json:"lat"`
	Lon         string            `json:"lon"`
	Address     map[string]string `json:"address"`
}

type nominatimReverseResult struct {
	DisplayName string            `json:"display_name"`
	Lat         string            `json:"lat"`
	Lon         string            `json:"lon"`
	Address     map[string]string `json:"address"`
}

// parseFloat converts a string to float64, returning 0 on error.
func parseFloat(s string) float64 {
	var f float64
	fmt.Sscanf(s, "%f", &f)
	return f
}

// extractAddressPart tries multiple keys in the address map and returns the first non-empty value.
func extractAddressPart(addr map[string]string, keys ...string) string {
	if addr == nil {
		return ""
	}
	for _, k := range keys {
		if v, ok := addr[k]; ok && strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
