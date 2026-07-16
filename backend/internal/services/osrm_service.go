package services

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/config"
	"go.uber.org/zap"
)

// OSRMPoint is a geographic coordinate used by the OSRM service.
type OSRMPoint struct {
	Longitude float64
	Latitude  float64
}

// String formats the point as "lng,lat" for OSRM API calls.
func (p OSRMPoint) String() string {
	return fmt.Sprintf("%f,%f", p.Longitude, p.Latitude)
}

// DistanceMatrix holds NxN distance and duration matrices returned by OSRM.
type DistanceMatrix struct {
	Distances [][]float64 `json:"distances"` // km
	Durations [][]float64 `json:"durations"` // minutes
	NumPoints int         `json:"num_points"`
}

// RouteSegment represents the route between two points.
type RouteSegment struct {
	Distance float64 `json:"distance"` // km
	Duration float64 `json:"duration"` // minutes
	Geometry string  `json:"geometry"` // encoded polyline
}

// osrmTableResponse is the JSON structure returned by OSRM's table service.
type osrmTableResponse struct {
	Code         string      `json:"code"`
	Distances    [][]float64 `json:"distances"`
	Durations    [][]float64 `json:"durations"`
	Sources      interface{} `json:"sources"`
	Destinations interface{} `json:"destinations"`
}

// osrmRouteResponse is the JSON structure returned by OSRM's route service.
type osrmRouteResponse struct {
	Code   string `json:"code"`
	Routes []struct {
		Distance float64 `json:"distance"` // meters
		Duration float64 `json:"duration"` // seconds
		Geometry string  `json:"geometry"`
	} `json:"routes"`
}

// OSRMService provides distance matrix and routing via the OSRM API.
type OSRMService struct {
	baseURL    string
	httpClient *http.Client
	cache      *redis.Client
	logger     *zap.Logger
}

// NewOSRMService creates a new OSRM service with HTTP client and Redis cache.
func NewOSRMService(cfg *config.Config, redisClient *redis.Client, logger *zap.Logger) *OSRMService {
	return &OSRMService{
		baseURL: cfg.OSRM.BaseURL,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		cache:  redisClient,
		logger: logger,
	}
}

// GetDistanceMatrix calculates distance and duration between all point pairs.
// It uses OSRM's table service and caches results in Redis for 24 hours.
func (s *OSRMService) GetDistanceMatrix(ctx context.Context, points []OSRMPoint) (*DistanceMatrix, error) {
	if len(points) < 2 {
		return nil, fmt.Errorf("need at least 2 points for distance matrix, got %d", len(points))
	}

	// Check cache
	cacheKey := s.matrixCacheKey(points)
	if cached, err := s.getCachedMatrix(ctx, cacheKey); err == nil && cached != nil {
		s.logger.Debug("OSRM distance matrix cache hit", zap.String("key", cacheKey))
		return cached, nil
	}

	// Build coordinate string: lng1,lat1;lng2,lat2;...
	coords := make([]string, len(points))
	for i, p := range points {
		coords[i] = p.String()
	}
	coordStr := strings.Join(coords, ";")

	// Call OSRM table service
	url := fmt.Sprintf("%s/table/v1/driving/%s?annotations=distance,duration",
		s.baseURL, coordStr)

	s.logger.Debug("OSRM table request", zap.String("url", url))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create OSRM request: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OSRM table request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read OSRM response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OSRM table returned status %d: %s", resp.StatusCode, string(body))
	}

	var osrmResp osrmTableResponse
	if err := json.Unmarshal(body, &osrmResp); err != nil {
		return nil, fmt.Errorf("parse OSRM response: %w", err)
	}

	if osrmResp.Code != "Ok" {
		return nil, fmt.Errorf("OSRM returned error code: %s", osrmResp.Code)
	}

	n := len(points)
	matrix := &DistanceMatrix{
		Distances: make([][]float64, n),
		Durations: make([][]float64, n),
		NumPoints: n,
	}

	for i := 0; i < n; i++ {
		matrix.Distances[i] = make([]float64, n)
		matrix.Durations[i] = make([]float64, n)
		for j := 0; j < n; j++ {
			// OSRM returns meters and seconds; convert to km and minutes
			matrix.Distances[i][j] = osrmResp.Distances[i][j] / 1000.0
			matrix.Durations[i][j] = osrmResp.Durations[i][j] / 60.0
		}
	}

	// Cache the result
	if err := s.cacheMatrix(ctx, cacheKey, matrix, 24*time.Hour); err != nil {
		s.logger.Warn("failed to cache OSRM matrix", zap.Error(err))
	}

	return matrix, nil
}

// GetRoute calculates the driving route between two points.
// Returns distance, duration, and encoded polyline geometry.
func (s *OSRMService) GetRoute(ctx context.Context, from, to OSRMPoint) (*RouteSegment, error) {
	url := fmt.Sprintf("%s/route/v1/driving/%s;%s?overview=full&geometries=polyline",
		s.baseURL, from.String(), to.String())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("create OSRM route request: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OSRM route request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read OSRM route response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OSRM route returned status %d: %s", resp.StatusCode, string(body))
	}

	var osrmResp osrmRouteResponse
	if err := json.Unmarshal(body, &osrmResp); err != nil {
		return nil, fmt.Errorf("parse OSRM route response: %w", err)
	}

	if osrmResp.Code != "Ok" || len(osrmResp.Routes) == 0 {
		return nil, fmt.Errorf("OSRM route returned no routes (code: %s)", osrmResp.Code)
	}

	route := osrmResp.Routes[0]
	return &RouteSegment{
		Distance: route.Distance / 1000.0, // meters → km
		Duration: route.Duration / 60.0,   // seconds → minutes
		Geometry: route.Geometry,
	}, nil
}

// matrixCacheKey builds a deterministic Redis key from the set of points.
func (s *OSRMService) matrixCacheKey(points []OSRMPoint) string {
	h := sha256.New()
	for _, p := range points {
		fmt.Fprintf(h, "%.6f,%.6f;", p.Latitude, p.Longitude)
	}
	return fmt.Sprintf("osrm:matrix:%x", h.Sum(nil))
}

// getCachedMatrix retrieves a cached distance matrix from Redis.
func (s *OSRMService) getCachedMatrix(ctx context.Context, key string) (*DistanceMatrix, error) {
	data, err := s.cache.Get(ctx, key).Bytes()
	if err != nil {
		return nil, err
	}
	var matrix DistanceMatrix
	if err := json.Unmarshal(data, &matrix); err != nil {
		return nil, err
	}
	return &matrix, nil
}

// cacheMatrix stores a distance matrix in Redis with TTL.
func (s *OSRMService) cacheMatrix(ctx context.Context, key string, matrix *DistanceMatrix, ttl time.Duration) error {
	data, err := json.Marshal(matrix)
	if err != nil {
		return err
	}
	return s.cache.Set(ctx, key, data, ttl).Err()
}
