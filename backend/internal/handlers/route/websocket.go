package route

import (
	"encoding/json"
	"log"
	"time"

	"github.com/gofiber/fiber/v2"
	ws "github.com/gofiber/websocket/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

const (
	wsWriteWait      = 10 * time.Second
	wsPongWait       = 60 * time.Second
	wsPingPeriod     = (wsPongWait * 9) / 10
	wsMaxMessageSize = 512
)

// wsTrackingMessage represents an incoming WebSocket message from a pedagang.
type wsTrackingMessage struct {
	Type string  `json:"type"`
	Lat  float64 `json:"lat"`
	Lng  float64 `json:"lng"`
}

// HandleTrackingWebSocket upgrades the connection to WebSocket for real-time GPS tracking.
// Messages from pedagang: { "type": "location", "lat": -6.2, "lng": 106.8 }
// Messages to pelanggan: { "type": "pedagang_location", "pedagang_id": "...", "lat": -6.2, "lng": 106.8, "eta_min": 15 }
func HandleTrackingWebSocket(hub *services.TrackingHub) fiber.Handler {
	return ws.New(func(c *ws.Conn) {
		// Extract user info from Fiber locals (set by auth middleware during upgrade)
		userID, _ := c.Locals("user_id").(string)
		role, _ := c.Locals("role").(string)

		if userID == "" {
			c.Close()
			return
		}

		switch role {
		case "pedagang":
			handlePedagangWS(hub, userID, c)
		case "pelanggan":
			handlePelangganWS(hub, userID, c)
		default:
			c.Close()
		}
	})
}

// handlePedagangWS handles the WebSocket connection for a pedagang (vendor).
func handlePedagangWS(hub *services.TrackingHub, pedagangID string, c *ws.Conn) {
	hub.RegisterPedagang(pedagangID, c)
	defer hub.UnregisterPedagang(pedagangID)

	c.SetReadLimit(wsMaxMessageSize)
	c.SetReadDeadline(time.Now().Add(wsPongWait))
	c.SetPongHandler(func(string) error {
		c.SetReadDeadline(time.Now().Add(wsPongWait))
		return nil
	})

	// Start ping ticker
	done := make(chan struct{})
	go func() {
		ticker := time.NewTicker(wsPingPeriod)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				c.SetWriteDeadline(time.Now().Add(wsWriteWait))
				if err := c.WriteMessage(ws.PingMessage, nil); err != nil {
					return
				}
			case <-done:
				return
			}
		}
	}()
	defer close(done)

	for {
		_, message, err := c.ReadMessage()
		if err != nil {
			if ws.IsUnexpectedCloseError(err, ws.CloseGoingAway, ws.CloseNormalClosure) {
				log.Printf("WebSocket read error for pedagang %s: %v", pedagangID, err)
			}
			break
		}

		var msg wsTrackingMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}

		if msg.Type == "location" {
			hub.UpdateLocation(pedagangID, msg.Lat, msg.Lng)
		}
	}
}

// handlePelangganWS handles the WebSocket connection for a pelanggan (customer).
func handlePelangganWS(hub *services.TrackingHub, pelangganID string, c *ws.Conn) {
	c.SetReadLimit(wsMaxMessageSize)
	c.SetReadDeadline(time.Now().Add(wsPongWait))
	c.SetPongHandler(func(string) error {
		c.SetReadDeadline(time.Now().Add(wsPongWait))
		return nil
	})

	// Start ping ticker
	done := make(chan struct{})
	go func() {
		ticker := time.NewTicker(wsPingPeriod)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				c.SetWriteDeadline(time.Now().Add(wsWriteWait))
				if err := c.WriteMessage(ws.PingMessage, nil); err != nil {
					return
				}
			case <-done:
				return
			}
		}
	}()
	defer close(done)

	for {
		_, message, err := c.ReadMessage()
		if err != nil {
			if ws.IsUnexpectedCloseError(err, ws.CloseGoingAway, ws.CloseNormalClosure) {
				log.Printf("WebSocket read error for pelanggan %s: %v", pelangganID, err)
			}
			break
		}

		var msg struct {
			Type       string `json:"type"`
			PedagangID string `json:"pedagang_id"`
		}
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}

		if msg.Type == "track" && msg.PedagangID != "" {
			hub.SubscribePelanggan(msg.PedagangID, pelangganID)
		}
	}
}

// GetPedagangLocation is an HTTP fallback for location polling.
// GET /routes/track/:pedagang_id — returns the current location of a pedagang.
func GetPedagangLocation(hub *services.TrackingHub) fiber.Handler {
	return func(c *fiber.Ctx) error {
		pedagangID := c.Params("pedagang_id")
		if pedagangID == "" {
			return utils.ErrorResponse(c, fiber.StatusBadRequest, "pedagang_id is required", nil)
		}

		point, err := hub.GetPedagangLocation(pedagangID)
		if err != nil {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Pedagang location not found", nil)
		}

		return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
			"pedagang_id": pedagangID,
			"lat":         point.Latitude,
			"lng":         point.Longitude,
		}, nil)
	}
}
