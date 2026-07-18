package services

import (
	"context"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// Insight represents a business insight generated for a pedagang.
type Insight struct {
	ID       string `json:"id"`
	UserID   string `json:"user_id"`
	Type     string `json:"type"` // "revenue", "customer", "product", "route", "price"
	Title    string `json:"title"`
	Body     string `json:"body"`
	Priority string `json:"priority"` // "high", "medium", "low"
	Icon     string `json:"icon"`
	Action   string `json:"action"` // suggested action text
	Created  string `json:"created"`
}

// InsightService generates actionable business insights for pedagangs.
type InsightService struct {
	orderRepo repository.OrderRepository
	subRepo   repository.SubscriptionRepository
	routeRepo repository.RouteRepository
	visitRepo repository.VisitRepository
	priceRepo *repository.PriceRepository
	userRepo  repository.UserRepository
	logger    *zap.Logger
}

// NewInsightService creates a new InsightService.
func NewInsightService(
	orderRepo repository.OrderRepository,
	subRepo repository.SubscriptionRepository,
	routeRepo repository.RouteRepository,
	visitRepo repository.VisitRepository,
	priceRepo *repository.PriceRepository,
	userRepo repository.UserRepository,
	logger *zap.Logger,
) *InsightService {
	return &InsightService{
		orderRepo: orderRepo,
		subRepo:   subRepo,
		routeRepo: routeRepo,
		visitRepo: visitRepo,
		priceRepo: priceRepo,
		userRepo:  userRepo,
		logger:    logger.Named("insight_service"),
	}
}

// GetInsights returns all actionable insights for a user.
func (s *InsightService) GetInsights(ctx context.Context, userID string) ([]Insight, error) {
	// Verify user exists
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get user: %w", err)
	}

	var insights []Insight
	now := time.Now()
	today := now.Format("2006-01-02")

	// Generate insights based on order data
	if user.IsPedagang() {
		orders, err := s.orderRepo.GetTodayOrders(ctx, userID)
		if err == nil && len(orders) > 0 {
			delivered := 0
			totalRevenue := 0.0
			for _, o := range orders {
				if o.Status == "delivered" {
					delivered++
					totalRevenue += o.TotalPrice
				}
			}

			if delivered > 0 {
				insights = append(insights, Insight{
					ID:       fmt.Sprintf("rev-%s", today),
					UserID:   userID,
					Type:     "revenue",
					Title:    "Omset Hari Ini",
					Body:     fmt.Sprintf("Anda sudah mengantar %d pesanan dengan total omset Rp %.0f hari ini.", delivered, totalRevenue),
					Priority: "medium",
					Icon:     "💰",
					Action:   "Lihat detail transaksi",
					Created:  now.Format(time.RFC3339),
				})
			}

			pending := len(orders) - delivered
			if pending > 0 {
				insights = append(insights, Insight{
					ID:       fmt.Sprintf("pending-%s", today),
					UserID:   userID,
					Type:     "route",
					Title:    "Pesanan Belum Diantar",
					Body:     fmt.Sprintf("Masih ada %d pesanan yang menunggu untuk diantar.", pending),
					Priority: "high",
					Icon:     "📦",
					Action:   "Lihat rute hari ini",
					Created:  now.Format(time.RFC3339),
				})
			}
		}
	}

	// If no insights generated, provide a helpful default
	if len(insights) == 0 {
		insights = append(insights, Insight{
			ID:       fmt.Sprintf("welcome-%s", today),
			UserID:   userID,
			Type:     "system",
			Title:    "Selamat Datang! 🌱",
			Body:     "Mulai hari Anda dengan melihat harga pasar terkini dan mengelola pesanan.",
			Priority: "low",
			Icon:     "🌱",
			Action:   "Jelajahi SayurPintar",
			Created:  now.Format(time.RFC3339),
		})
	}

	return insights, nil
}

// GenerateInsights creates fresh insights for a pedagang (called by scheduler).
func (s *InsightService) GenerateInsights(ctx context.Context, pedagangID string) ([]Insight, error) {
	return s.GetInsights(ctx, pedagangID)
}
