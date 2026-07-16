package route

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// Handler handles route and waypoint HTTP requests.
type Handler struct {
	routeService *services.RouteService
	visitHandler *VisitHandler
}

// NewHandler creates a new route Handler.
func NewHandler(routeService *services.RouteService) *Handler {
	return &Handler{
		routeService: routeService,
	}
}

// SetVisitHandler sets the visit handler for the route handler.
func (h *Handler) SetVisitHandler(vh *VisitHandler) {
	h.visitHandler = vh
}

// OptimizeRoute triggers route optimization for today's route.
// POST /routes/optimize
func (h *Handler) OptimizeRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	optimized, err := h.routeService.OptimizeTodayRoute(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to optimize route", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, optimized, nil)
}

// GetTodayRoute returns the pedagang's route for today.
// GET /routes/today
func (h *Handler) GetTodayRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	route, err := h.routeService.GetOrCreateTodayRoute(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get today's route", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, route, nil)
}

// StartRoute marks today's route as in_progress.
// POST /routes/today/start
func (h *Handler) StartRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	route, err := h.routeService.GetOrCreateTodayRoute(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get route", err.Error())
	}

	if err := h.routeService.StartRoute(c.Context(), route.ID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to start route", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message":  "Route started",
		"route_id": route.ID,
	}, nil)
}

// CompleteRoute marks today's route as completed.
// POST /routes/today/complete
func (h *Handler) CompleteRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	route, err := h.routeService.GetOrCreateTodayRoute(c.Context(), pedagangID)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get route", err.Error())
	}

	var body struct {
		ActualDistanceKm  float64 `json:"actual_distance_km"`
		ActualDurationMin int     `json:"actual_duration_min"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if err := h.routeService.CompleteRoute(c.Context(), route.ID, body.ActualDistanceKm, body.ActualDurationMin); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to complete route", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Route completed",
	}, nil)
}

// AddToTodayRoute adds a waypoint to today's route.
// POST /routes/today/waypoints
func (h *Handler) AddToTodayRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)

	var body struct {
		WaypointID string `json:"waypoint_id"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.WaypointID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "waypoint_id is required", nil)
	}

	if err := h.routeService.AddWaypointToRoute(c.Context(), pedagangID, body.WaypointID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to add waypoint", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Waypoint added to today's route",
	}, nil)
}

// RemoveFromTodayRoute removes a waypoint from today's route.
// DELETE /routes/today/waypoints/:id
func (h *Handler) RemoveFromTodayRoute(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	waypointID := c.Params("id")

	if waypointID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "waypoint id is required", nil)
	}

	if err := h.routeService.RemoveWaypointFromRoute(c.Context(), pedagangID, waypointID); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Failed to remove waypoint", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Waypoint removed from today's route",
	}, nil)
}

// GetRouteHistory returns routes within a date range.
// GET /routes/history?from=2026-01-01&to=2026-07-16
func (h *Handler) GetRouteHistory(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	from := c.Query("from", "")
	to := c.Query("to", "")

	routes, err := h.routeService.GetRouteHistory(c.Context(), pedagangID, from, to)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get route history", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, routes, nil)
}

// GetRouteStats returns aggregate route statistics.
// GET /routes/stats?days=30
func (h *Handler) GetRouteStats(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	daysStr := c.Query("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days <= 0 {
		days = 30
	}

	stats, err := h.routeService.GetRouteStats(c.Context(), pedagangID, days)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get route stats", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, stats, nil)
}

// ── Legacy stubs (kept for backward compatibility) ──

// GetRoutes returns all routes for the pedagang.
func (h *Handler) GetRoutes(c *fiber.Ctx) error {
	pedagangID := middleware.GetUserID(c)
	routes, err := h.routeService.GetRouteHistory(c.Context(), pedagangID, "", "")
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get routes", err.Error())
	}
	return utils.SuccessResponse(c, fiber.StatusOK, routes, nil)
}

// CreateRoute is a no-op — routes are auto-created via GetOrCreateTodayRoute.
func (h *Handler) CreateRoute(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Routes are auto-created. Use GET /routes/today instead.", nil)
}

// GetRoute returns a specific route by ID (not yet implemented).
func (h *Handler) GetRoute(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Not implemented", nil)
}

// UpdateRoute updates a route (not yet implemented).
func (h *Handler) UpdateRoute(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Not implemented", nil)
}

// DeleteRoute deletes a route (not yet implemented).
func (h *Handler) DeleteRoute(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Not implemented", nil)
}

// GetWaypoints returns waypoints (not yet implemented in this handler).
func (h *Handler) GetWaypoints(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Use /waypoints endpoint instead", nil)
}

// CreateWaypoint creates a waypoint (not yet implemented in this handler).
func (h *Handler) CreateWaypoint(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Use /waypoints endpoint instead", nil)
}

// UpdateWaypoint updates a waypoint (not yet implemented in this handler).
func (h *Handler) UpdateWaypoint(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Use /waypoints endpoint instead", nil)
}

// DeleteWaypoint deletes a waypoint (not yet implemented in this handler).
func (h *Handler) DeleteWaypoint(c *fiber.Ctx) error {
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Use /waypoints endpoint instead", nil)
}

// CompleteVisit delegates to the visit handler's MarkVisitCompleted.
func (h *Handler) CompleteVisit(c *fiber.Ctx) error {
	if h.visitHandler != nil {
		return h.visitHandler.MarkVisitCompleted(c)
	}
	return utils.ErrorResponse(c, fiber.StatusNotImplemented, "Visit handler not configured", nil)
}
