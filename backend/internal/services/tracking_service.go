package services

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/gofiber/websocket/v2"
	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/models"
	"go.uber.org/zap"
)

const (
	trackingGeoKey    = "tracking:pedagang_locations"
	trackingPrefix    = "tracking:location:"
	trackingTTL       = 5 * time.Minute
	writeWait         = 10 * time.Second
	pongWait          = 60 * time.Second
	pingPeriod        = (pongWait * 9) / 10
	maxMessageSize    = 512
)

// TrackingMessage represents a message sent over the tracking WebSocket.
type TrackingMessage struct {
	Type        string  `json:"type"`
	Lat         float64 `json:"lat,omitempty"`
	Lng         float64 `json:"lng,omitempty"`
	PedagangID  string  `json:"pedagang_id,omitempty"`
	ETAMin      int     `json:"eta_min,omitempty"`
	Timestamp   int64   `json:"timestamp,omitempty"`
}

// PedagangConnection represents a connected pedagang's WebSocket.
type PedagangConnection struct {
	PedagangID string
	Conn       *websocket.Conn
	LastUpdate time.Time
	Lat        float64
	Lng        float64
}

// TrackingHub manages all active WebSocket connections for GPS tracking.
type TrackingHub struct {
	mu            sync.RWMutex
	connections   map[string]*PedagangConnection // pedagang_id → connection
	pelangganSubs map[string]map[string]bool     // pedagang_id → set of pelanggan_ids watching
	redis         *redis.Client
	logger        *zap.Logger
}

// NewTrackingHub creates a new TrackingHub.
func NewTrackingHub(redis *redis.Client, logger *zap.Logger) *TrackingHub {
	return &TrackingHub{
		connections:   make(map[string]*PedagangConnection),
		pelangganSubs: make(map[string]map[string]bool),
		redis:         redis,
		logger:        logger,
	}
}

// RegisterPedagang adds a pedagang's WebSocket connection to the hub.
func (h *TrackingHub) RegisterPedagang(pedagangID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Close existing connection if any
	if existing, ok := h.connections[pedagangID]; ok {
		existing.Conn.Close()
	}

	h.connections[pedagangID] = &PedagangConnection{
		PedagangID: pedagangID,
		Conn:       conn,
		LastUpdate: time.Now(),
	}

	h.logger.Info("Pedagang connected for tracking",
		zap.String("pedagang_id", pedagangID),
	)
}

// UnregisterPedagang removes a pedagang's connection from the hub.
func (h *TrackingHub) UnregisterPedagang(pedagangID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if conn, ok := h.connections[pedagangID]; ok {
		conn.Conn.Close()
		delete(h.connections, pedagangID)
	}

	h.logger.Info("Pedagang disconnected from tracking",
		zap.String("pedagang_id", pedagangID),
	)
}

// UpdateLocation processes a location update from a pedagang,
// broadcasts to subscribed pelanggans, and stores in Redis.
func (h *TrackingHub) UpdateLocation(pedagangID string, lat, lng float64) {
	h.mu.Lock()
	if conn, ok := h.connections[pedagangID]; ok {
		conn.Lat = lat
		conn.Lng = lng
		conn.LastUpdate = time.Now()
	}
	// Get list of subscribed pelanggans
	subs := make([]string, 0)
	if subSet, ok := h.pelangganSubs[pedagangID]; ok {
		for pid := range subSet {
			subs = append(subs, pid)
		}
	}
	h.mu.Unlock()

	// Store in Redis for HTTP polling fallback
	ctx := context.Background()
	if err := h.redis.GeoAdd(ctx, trackingGeoKey, &redis.GeoLocation{
		Name:      pedagangID,
		Longitude: lng,
		Latitude:  lat,
	}).Err(); err != nil {
		h.logger.Error("Failed to store location in Redis GEO", zap.Error(err))
	}

	// Also store as JSON for detailed retrieval
	locationData, _ := json.Marshal(map[string]interface{}{
		"lat":        lat,
		"lng":        lng,
		"updated_at": time.Now().Unix(),
	})
	locationKey := trackingPrefix + pedagangID
	if err := h.redis.Set(ctx, locationKey, locationData, trackingTTL).Err(); err != nil {
		h.logger.Error("Failed to store location in Redis", zap.Error(err))
	}

	// Broadcast to subscribed pelanggans
	msg := TrackingMessage{
		Type:       "pedagang_location",
		PedagangID: pedagangID,
		Lat:        lat,
		Lng:        lng,
		Timestamp:  time.Now().Unix(),
	}
	msgJSON, _ := json.Marshal(msg)

	h.mu.RLock()
	for _, pelangganID := range subs {
		// Find pelanggan's connection (if they're also a pedagang connected via WS)
		// In practice, pelanggan receive updates via their own WS connection
		// For now, we write to any active connection that matches
		if pConn, ok := h.connections[pelangganID]; ok {
			pConn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := pConn.Conn.WriteMessage(websocket.TextMessage, msgJSON); err != nil {
				h.logger.Warn("Failed to send location to pelanggan",
					zap.String("pelanggan_id", pelangganID),
					zap.Error(err),
				)
			}
		}
	}
	h.mu.RUnlock()

	h.logger.Debug("Location updated",
		zap.String("pedagang_id", pedagangID),
		zap.Float64("lat", lat),
		zap.Float64("lng", lng),
		zap.Int("subscribers", len(subs)),
	)
}

// SubscribePelanggan subscribes a pelanggan to track a pedagang's location.
func (h *TrackingHub) SubscribePelanggan(pedagangID, pelangganID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.pelangganSubs[pedagangID] == nil {
		h.pelangganSubs[pedagangID] = make(map[string]bool)
	}
	h.pelangganSubs[pedagangID][pelangganID] = true

	h.logger.Info("Pelanggan subscribed to pedagang",
		zap.String("pedagang_id", pedagangID),
		zap.String("pelanggan_id", pelangganID),
	)
}

// UnsubscribePelanggan removes a pelanggan's subscription to a pedagang.
func (h *TrackingHub) UnsubscribePelanggan(pedagangID, pelangganID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if subs, ok := h.pelangganSubs[pedagangID]; ok {
		delete(subs, pelangganID)
		if len(subs) == 0 {
			delete(h.pelangganSubs, pedagangID)
		}
	}
}

// GetPedagangLocation returns the current location of a pedagang from Redis.
func (h *TrackingHub) GetPedagangLocation(pedagangID string) (*models.Point, error) {
	ctx := context.Background()
	locationKey := trackingPrefix + pedagangID

	data, err := h.redis.Get(ctx, locationKey).Result()
	if err != nil {
		if err == redis.Nil {
			// Try GEO lookup as fallback
			return h.getGeoLocation(ctx, pedagangID)
		}
		return nil, fmt.Errorf("get location from redis: %w", err)
	}

	var loc struct {
		Lat float64 `json:"lat"`
		Lng float64 `json:"lng"`
	}
	if err := json.Unmarshal([]byte(data), &loc); err != nil {
		return nil, fmt.Errorf("unmarshal location: %w", err)
	}

	return &models.Point{Latitude: loc.Lat, Longitude: loc.Lng}, nil
}

// getGeoLocation retrieves location from Redis GEO set.
func (h *TrackingHub) getGeoLocation(ctx context.Context, pedagangID string) (*models.Point, error) {
	pos, err := h.redis.GeoPos(ctx, trackingGeoKey, pedagangID).Result()
	if err != nil {
		return nil, fmt.Errorf("geo pos: %w", err)
	}
	if len(pos) == 0 || pos[0] == nil {
		return nil, fmt.Errorf("pedagang location not found")
	}

	return &models.Point{
		Latitude:  pos[0].Latitude,
		Longitude: pos[0].Longitude,
	}, nil
}

// BroadcastRouteUpdate sends a route update message to a connected pedagang.
func (h *TrackingHub) BroadcastRouteUpdate(pedagangID string, data interface{}) {
	h.mu.RLock()
	conn, ok := h.connections[pedagangID]
	h.mu.RUnlock()

	if !ok {
		return
	}

	msg := map[string]interface{}{
		"type": "route_update",
		"data": data,
	}
	msgJSON, _ := json.Marshal(msg)

	conn.Conn.SetWriteDeadline(time.Now().Add(writeWait))
	if err := conn.Conn.WriteMessage(websocket.TextMessage, msgJSON); err != nil {
		h.logger.Warn("Failed to send route update",
			zap.String("pedagang_id", pedagangID),
			zap.Error(err),
		)
	}
}

// GetActivePedagangCount returns the number of connected pedagangs.
func (h *TrackingHub) GetActivePedagangCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.connections)
}

// HaversineDistance calculates the distance between two points in meters.
func HaversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadiusM = 6371000
	dLat := (lat2 - lat1) * math.Pi / 180
	dLng := (lng2 - lng1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusM * c
}

// EstimateETA returns estimated time in minutes based on distance.
// Assumes average speed of 20 km/h for a vendor on a motorcycle.
func EstimateETA(lat1, lng1, lat2, lng2 float64) int {
	distM := HaversineDistance(lat1, lng1, lat2, lng2)
	speedMPerMin := 20000.0 / 60.0 // 20 km/h in m/min
	if speedMPerMin == 0 {
		return 0
	}
	return int(math.Ceil(distM / speedMPerMin))
}
