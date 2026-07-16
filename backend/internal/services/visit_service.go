package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// CompleteVisitRequest holds the data for completing a visit.
type CompleteVisitRequest struct {
	Items         []models.VisitItem `json:"items" validate:"required,min=1"`
	Amount        float64            `json:"amount" validate:"required,gt=0"`
	PaymentMethod string             `json:"payment_method" validate:"required,oneof=cash qris transfer"`
	Notes         string             `json:"notes"`
}

// VisitSummary holds a daily summary of visits for a pedagang.
type VisitSummary struct {
	Date         string  `json:"date"`
	TotalVisits  int     `json:"total_visits"`
	Completed    int     `json:"completed"`
	Skipped      int     `json:"skipped"`
	TotalRevenue float64 `json:"total_revenue"`
	TotalItems   int     `json:"total_items"`
	AvgPerVisit  float64 `json:"avg_per_visit"`
	Duration     int     `json:"duration_min"`
}

// VisitService handles visit-related business logic.
type VisitService struct {
	visitRepo    repository.VisitRepository
	routeRepo    repository.RouteRepository
	waypointRepo repository.WaypointRepository
	logger       *zap.Logger
}

// NewVisitService creates a new VisitService.
func NewVisitService(
	visitRepo repository.VisitRepository,
	routeRepo repository.RouteRepository,
	waypointRepo repository.WaypointRepository,
	logger *zap.Logger,
) *VisitService {
	return &VisitService{
		visitRepo:    visitRepo,
		routeRepo:    routeRepo,
		waypointRepo: waypointRepo,
		logger:       logger,
	}
}

// CreateVisitsForRoute creates visit records for all waypoints in a route.
// Sets visit_order based on optimized_order, calculates planned_arrival.
func (s *VisitService) CreateVisitsForRoute(ctx context.Context, route *models.Route) error {
	// Determine the ordered list of waypoint IDs
	var orderedIDs []string
	if len(route.OptimizedOrder) > 0 {
		orderedIDs = route.OptimizedOrder
	} else {
		orderedIDs = route.WaypointIDs
	}

	if len(orderedIDs) == 0 {
		s.logger.Warn("No waypoints in route, skipping visit creation",
			zap.String("route_id", route.ID))
		return nil
	}

	// Fetch waypoint details to get pelanggan_id
	waypoints := make(map[string]*models.Waypoint)
	for _, wpID := range orderedIDs {
		wp, err := s.waypointRepo.GetByID(ctx, wpID)
		if err != nil {
			s.logger.Warn("Skipping waypoint in visit creation",
				zap.String("waypoint_id", wpID), zap.Error(err))
			continue
		}
		waypoints[wpID] = wp
	}

	// Build visits: estimate 15 minutes per visit starting from 08:00
	startHour := 8
	startMin := 0

	visits := make([]models.Visit, 0, len(orderedIDs))
	for i, wpID := range orderedIDs {
		wp := waypoints[wpID]
		if wp == nil {
			continue
		}

		// Calculate planned arrival: startHour:startMin + i*15min
		totalMin := startHour*60 + startMin + i*15
		hour := totalMin / 60
		minute := totalMin % 60
		plannedArrival := fmt.Sprintf("%02d:%02d", hour, minute)

		visit := models.Visit{
			RouteID:        route.ID,
			WaypointID:     wpID,
			PelangganID:    wp.PelangganID,
			VisitOrder:     i + 1,
			PlannedArrival: &plannedArrival,
			PaymentMethod:  "cash",
			PaymentStatus:  "pending",
			Status:         "pending",
		}

		visits = append(visits, visit)
	}

	if len(visits) == 0 {
		s.logger.Warn("No valid visits to create for route",
			zap.String("route_id", route.ID))
		return nil
	}

	if err := s.visitRepo.CreateBatch(ctx, visits); err != nil {
		return fmt.Errorf("create visits batch: %w", err)
	}

	s.logger.Info("Created visits for route",
		zap.String("route_id", route.ID),
		zap.Int("count", len(visits)),
	)
	return nil
}

// MarkArrived records vendor arrival at customer location.
func (s *VisitService) MarkArrived(ctx context.Context, visitID string) error {
	if err := s.visitRepo.MarkArrived(ctx, visitID); err != nil {
		return fmt.Errorf("mark arrived: %w", err)
	}

	s.logger.Info("Visit marked arrived", zap.String("visit_id", visitID))
	return nil
}

// MarkCompleted records a completed visit with items sold and payment info.
func (s *VisitService) MarkCompleted(ctx context.Context, visitID string, req CompleteVisitRequest) error {
	// Serialize items to JSON
	itemsJSON, err := json.Marshal(req.Items)
	if err != nil {
		return fmt.Errorf("marshal items: %w", err)
	}

	if err := s.visitRepo.MarkCompleted(ctx, visitID, itemsJSON, req.Amount, req.PaymentMethod); err != nil {
		return fmt.Errorf("mark completed: %w", err)
	}

	// If there are notes, update them separately
	if req.Notes != "" {
		visit, err := s.visitRepo.GetByID(ctx, visitID)
		if err != nil {
			s.logger.Warn("Failed to fetch visit for notes update",
				zap.String("visit_id", visitID), zap.Error(err))
			return nil
		}
		visit.Notes = &req.Notes
		if err := s.visitRepo.Update(ctx, visit); err != nil {
			s.logger.Warn("Failed to update visit notes",
				zap.String("visit_id", visitID), zap.Error(err))
		}
	}

	s.logger.Info("Visit marked completed",
		zap.String("visit_id", visitID),
		zap.Float64("amount", req.Amount),
		zap.String("payment_method", req.PaymentMethod),
	)
	return nil
}

// MarkSkipped marks a visit as skipped with a reason.
func (s *VisitService) MarkSkipped(ctx context.Context, visitID string, reason string) error {
	if err := s.visitRepo.MarkSkipped(ctx, visitID, reason); err != nil {
		return fmt.Errorf("mark skipped: %w", err)
	}

	s.logger.Info("Visit marked skipped",
		zap.String("visit_id", visitID),
		zap.String("reason", reason),
	)
	return nil
}

// GetTodayVisits returns all visits for today's route of a pedagang.
func (s *VisitService) GetTodayVisits(ctx context.Context, pedagangID string) ([]models.Visit, error) {
	today := time.Now().Format("2006-01-02")

	route, err := s.routeRepo.GetByPedagangAndDate(ctx, pedagangID, today)
	if err != nil {
		if err == repository.ErrRouteNotFound {
			return []models.Visit{}, nil
		}
		return nil, fmt.Errorf("get today route: %w", err)
	}

	visits, err := s.visitRepo.ListByRoute(ctx, route.ID)
	if err != nil {
		return nil, fmt.Errorf("list today visits: %w", err)
	}

	return visits, nil
}

// GetVisitSummary returns a daily visit summary for a pedagang.
func (s *VisitService) GetVisitSummary(ctx context.Context, pedagangID string, date string) (*VisitSummary, error) {
	route, err := s.routeRepo.GetByPedagangAndDate(ctx, pedagangID, date)
	if err != nil {
		if err == repository.ErrRouteNotFound {
			return &VisitSummary{Date: date}, nil
		}
		return nil, fmt.Errorf("get route: %w", err)
	}

	visits, err := s.visitRepo.ListByRoute(ctx, route.ID)
	if err != nil {
		return nil, fmt.Errorf("list visits: %w", err)
	}

	summary := &VisitSummary{
		Date:        date,
		TotalVisits: len(visits),
	}

	for _, v := range visits {
		switch v.Status {
		case "completed":
			summary.Completed++
			if v.Amount != nil {
				summary.TotalRevenue += *v.Amount
			}
			// Count items
			if v.ItemsSold != nil {
				var items []models.VisitItem
				if err := json.Unmarshal(v.ItemsSold, &items); err == nil {
					for _, item := range items {
						summary.TotalItems += int(item.Qty)
					}
				}
			}
			summary.Duration += v.DurationMin
		case "skipped":
			summary.Skipped++
		}
	}

	if summary.Completed > 0 {
		summary.AvgPerVisit = summary.TotalRevenue / float64(summary.Completed)
	}

	return summary, nil
}
