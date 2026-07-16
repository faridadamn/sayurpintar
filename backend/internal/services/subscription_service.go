package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"go.uber.org/zap"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
)

// SubscribeRequest holds the payload for creating a new subscription.
type SubscribeRequest struct {
	PackageID        string `json:"package_id" validate:"required,uuid"`
	PaymentMethod    string `json:"payment_method" validate:"required,oneof=cash qris transfer"`
	PaymentFrequency string `json:"payment_frequency" validate:"omitempty,oneof=per_delivery weekly monthly"`
}

// ModifyRequest holds the payload for modifying the next delivery.
type ModifyRequest struct {
	DeliveryDate string              `json:"delivery_date" validate:"required"` // YYYY-MM-DD
	Items        []models.PackageItem `json:"items"`
	SkipDelivery bool                `json:"skip_delivery"`
	Reason       string              `json:"reason"`
}

// SubscriptionDetail enriches a subscription with package info and delivery history.
type SubscriptionDetail struct {
	models.Subscription
	Package       *models.SubscriptionPackage         `json:"package"`
	DeliveryCount int                                  `json:"delivery_count"`
	TotalSpent    float64                              `json:"total_spent"`
	NextDelivery  string                               `json:"next_delivery"`
	Modifications []models.SubscriptionModification    `json:"recent_modifications"`
}

// SubscriberStats holds aggregated stats for a pedagang's subscription business.
type SubscriberStats struct {
	TotalSubscribers   int     `json:"total_subscribers"`
	ActiveSubscribers  int     `json:"active_subscribers"`
	PausedSubscribers  int     `json:"paused_subscribers"`
	MonthlyRevenue     float64 `json:"monthly_revenue"`
	AvgDeliveryPerWeek float64 `json:"avg_delivery_per_week"`
}

// SubscriptionService manages the subscription lifecycle.
type SubscriptionService struct {
	subRepo        repository.SubscriptionRepository
	pkgRepo        repository.SubscriptionPackageRepository
	modRepo        repository.SubscriptionModificationRepository
	orderRepo      repository.OrderRepository
	notifier       *SubscriptionNotifier
	logger         *zap.Logger
}

// NewSubscriptionService creates a SubscriptionService.
func NewSubscriptionService(
	subRepo repository.SubscriptionRepository,
	pkgRepo repository.SubscriptionPackageRepository,
	modRepo repository.SubscriptionModificationRepository,
	orderRepo repository.OrderRepository,
	notifier *SubscriptionNotifier,
	logger *zap.Logger,
) *SubscriptionService {
	return &SubscriptionService{
		subRepo:        subRepo,
		pkgRepo:        pkgRepo,
		modRepo:        modRepo,
		orderRepo:      orderRepo,
		notifier:       notifier,
		logger:         logger.Named("subscription"),
	}
}

// Subscribe creates a new subscription for a pelanggan.
func (s *SubscriptionService) Subscribe(ctx context.Context, pelangganID string, req SubscribeRequest) (*models.Subscription, error) {
	// Validate package exists and is active
	pkg, err := s.pkgRepo.GetByID(ctx, req.PackageID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionPackageNotFound) {
			return nil, fmt.Errorf("paket langganan tidak ditemukan")
		}
		return nil, fmt.Errorf("get package: %w", err)
	}
	if !pkg.IsActive {
		return nil, repository.ErrPackageInactive
	}

	// Check pelanggan not already subscribed
	existing, err := s.subRepo.GetActiveByPelangganAndPackage(ctx, pelangganID, req.PackageID)
	if err != nil {
		return nil, fmt.Errorf("check existing subscription: %w", err)
	}
	if existing != nil {
		return nil, repository.ErrAlreadySubscribed
	}

	// Check max_subscribers not reached
	if pkg.MaxSubscribers > 0 {
		count, err := s.subRepo.CountByPackage(ctx, req.PackageID)
		if err != nil {
			return nil, fmt.Errorf("count subscribers: %w", err)
		}
		if count >= pkg.MaxSubscribers {
			return nil, repository.ErrPackageLimitReached
		}
	}

	// Default payment frequency
	paymentFreq := req.PaymentFrequency
	if paymentFreq == "" {
		paymentFreq = "per_delivery"
	}

	sub := &models.Subscription{
		PackageID:        req.PackageID,
		PedagangID:       pkg.PedagangID,
		PelangganID:      pelangganID,
		PaymentMethod:    req.PaymentMethod,
		PaymentFrequency: paymentFreq,
		Status:           "active",
		StartDate:        time.Now().Format("2006-01-02"),
	}

	if err := s.subRepo.Create(ctx, sub); err != nil {
		return nil, fmt.Errorf("create subscription: %w", err)
	}

	s.logger.Info("subscription created",
		zap.String("subscription_id", sub.ID),
		zap.String("pelanggan_id", pelangganID),
		zap.String("package_id", req.PackageID),
	)

	// Send confirmation notification (best-effort)
	if s.notifier != nil {
		go func() {
			bgCtx := context.Background()
			if err := s.notifier.NotifySubscriptionConfirmed(bgCtx, sub, pkg); err != nil {
				s.logger.Warn("failed to send subscription confirmation",
					zap.String("subscription_id", sub.ID),
					zap.Error(err),
				)
			}
		}()
	}

	return sub, nil
}

// PauseSubscription pauses an active subscription and cancels future pending orders.
func (s *SubscriptionService) PauseSubscription(ctx context.Context, subscriptionID, pelangganID string, reason string) error {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return fmt.Errorf("langganan tidak ditemukan")
		}
		return fmt.Errorf("get subscription: %w", err)
	}

	if sub.PelangganID != pelangganID {
		return fmt.Errorf("langganan bukan milik Anda")
	}

	if sub.Status != "active" {
		return fmt.Errorf("langganan tidak dalam status aktif (saat ini: %s)", sub.Status)
	}

	if err := s.subRepo.Pause(ctx, subscriptionID, reason); err != nil {
		return fmt.Errorf("pause subscription: %w", err)
	}

	// Cancel all future pending orders
	if s.orderRepo != nil {
		count, err := s.orderRepo.CancelPendingBySubscription(ctx, subscriptionID, time.Now())
		if err != nil {
			s.logger.Warn("failed to cancel pending orders on pause",
				zap.String("subscription_id", subscriptionID),
				zap.Error(err),
			)
		} else if count > 0 {
			s.logger.Info("cancelled pending orders due to pause",
				zap.String("subscription_id", subscriptionID),
				zap.Int("cancelled_count", count),
			)
		}
	}

	s.logger.Info("subscription paused",
		zap.String("subscription_id", subscriptionID),
		zap.String("reason", reason),
	)

	// Re-fetch for notification
	sub.Status = "paused"
	if reason != "" {
		sub.PauseReason = &reason
	}
	now := time.Now()
	sub.PausedAt = &now

	if s.notifier != nil {
		go func() {
			bgCtx := context.Background()
			if err := s.notifier.NotifySubscriptionPaused(bgCtx, sub); err != nil {
				s.logger.Warn("failed to send pause notification",
					zap.String("subscription_id", subscriptionID),
					zap.Error(err),
				)
			}
		}()
	}

	return nil
}

// ResumeSubscription resumes a paused subscription.
func (s *SubscriptionService) ResumeSubscription(ctx context.Context, subscriptionID, pelangganID string) error {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return fmt.Errorf("langganan tidak ditemukan")
		}
		return fmt.Errorf("get subscription: %w", err)
	}

	if sub.PelangganID != pelangganID {
		return fmt.Errorf("langganan bukan milik Anda")
	}

	if sub.Status != "paused" {
		return fmt.Errorf("langganan tidak dalam status paused (saat ini: %s)", sub.Status)
	}

	if err := s.subRepo.Resume(ctx, subscriptionID); err != nil {
		return fmt.Errorf("resume subscription: %w", err)
	}

	s.logger.Info("subscription resumed",
		zap.String("subscription_id", subscriptionID),
	)

	sub.Status = "active"

	if s.notifier != nil {
		go func() {
			bgCtx := context.Background()
			if err := s.notifier.NotifySubscriptionResumed(bgCtx, sub); err != nil {
				s.logger.Warn("failed to send resume notification",
					zap.String("subscription_id", subscriptionID),
					zap.Error(err),
				)
			}
		}()
	}

	return nil
}

// CancelSubscription cancels a subscription and cancels future pending orders.
func (s *SubscriptionService) CancelSubscription(ctx context.Context, subscriptionID, pelangganID string, reason string) error {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return fmt.Errorf("langganan tidak ditemukan")
		}
		return fmt.Errorf("get subscription: %w", err)
	}

	if sub.PelangganID != pelangganID {
		return fmt.Errorf("langganan bukan milik Anda")
	}

	if sub.Status != "active" && sub.Status != "paused" {
		return fmt.Errorf("langganan tidak dapat dibatalkan (status: %s)", sub.Status)
	}

	if err := s.subRepo.Cancel(ctx, subscriptionID, reason); err != nil {
		return fmt.Errorf("cancel subscription: %w", err)
	}

	// Cancel all future pending orders
	if s.orderRepo != nil {
		count, err := s.orderRepo.CancelPendingBySubscription(ctx, subscriptionID, time.Now())
		if err != nil {
			s.logger.Warn("failed to cancel pending orders on cancel",
				zap.String("subscription_id", subscriptionID),
				zap.Error(err),
			)
		} else if count > 0 {
			s.logger.Info("cancelled pending orders due to cancellation",
				zap.String("subscription_id", subscriptionID),
				zap.Int("cancelled_count", count),
			)
		}
	}

	s.logger.Info("subscription cancelled",
		zap.String("subscription_id", subscriptionID),
		zap.String("reason", reason),
	)

	sub.Status = "cancelled"
	if reason != "" {
		sub.CancelReason = &reason
	}
	now := time.Now()
	sub.CancelledAt = &now

	if s.notifier != nil {
		go func() {
			bgCtx := context.Background()
			if err := s.notifier.NotifySubscriptionCancelled(bgCtx, sub); err != nil {
				s.logger.Warn("failed to send cancellation notification",
					zap.String("subscription_id", subscriptionID),
					zap.Error(err),
				)
			}
		}()
	}

	return nil
}

// ModifyNextDelivery creates or updates a modification for the next delivery.
func (s *SubscriptionService) ModifyNextDelivery(ctx context.Context, subscriptionID, pelangganID string, req ModifyRequest) error {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return fmt.Errorf("langganan tidak ditemukan")
		}
		return fmt.Errorf("get subscription: %w", err)
	}

	if sub.PelangganID != pelangganID {
		return fmt.Errorf("langganan bukan milik Anda")
	}

	if sub.Status != "active" {
		return fmt.Errorf("hanya langganan aktif yang bisa dimodifikasi (status: %s)", sub.Status)
	}

	// Validate delivery date is not in the past
	deliveryDate, err := time.Parse("2006-01-02", req.DeliveryDate)
	if err != nil {
		return fmt.Errorf("format tanggal tidak valid, gunakan YYYY-MM-DD: %w", err)
	}
	today := time.Now().Truncate(24 * time.Hour)
	if deliveryDate.Before(today) {
		return fmt.Errorf("tanggal pengiriman tidak boleh di masa lalu")
	}

	// Build modification record
	var itemsJSON json.RawMessage
	if len(req.Items) > 0 {
		itemsJSON, err = json.Marshal(req.Items)
		if err != nil {
			return fmt.Errorf("marshal items: %w", err)
		}
	}

	mod := &models.SubscriptionModification{
		SubscriptionID: subscriptionID,
		DeliveryDate:   req.DeliveryDate,
		Items:          itemsJSON,
		SkipDelivery:   req.SkipDelivery,
		Reason:         req.Reason,
	}

	if err := s.modRepo.Create(ctx, mod); err != nil {
		return fmt.Errorf("create modification: %w", err)
	}

	s.logger.Info("delivery modification saved",
		zap.String("subscription_id", subscriptionID),
		zap.String("delivery_date", req.DeliveryDate),
		zap.Bool("skip", req.SkipDelivery),
	)

	return nil
}

// GetActiveSubscriptions returns all subscriptions for a user based on their role.
func (s *SubscriptionService) GetActiveSubscriptions(ctx context.Context, userID string, role string) ([]models.Subscription, error) {
	switch role {
	case "pedagang":
		return s.subRepo.ListByPedagang(ctx, userID, "active")
	case "pelanggan":
		return s.subRepo.ListByPelanggan(ctx, userID, "active")
	default:
		return nil, fmt.Errorf("role tidak didukung: %s", role)
	}
}

// GetSubscriptionDetail returns a subscription with package info and delivery history.
func (s *SubscriptionService) GetSubscriptionDetail(ctx context.Context, subscriptionID string) (*SubscriptionDetail, error) {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return nil, fmt.Errorf("langganan tidak ditemukan")
		}
		return nil, fmt.Errorf("get subscription: %w", err)
	}

	detail := &SubscriptionDetail{
		Subscription: *sub,
	}

	// Fetch package info
	pkg, err := s.pkgRepo.GetByID(ctx, sub.PackageID)
	if err != nil && !errors.Is(err, repository.ErrSubscriptionPackageNotFound) {
		s.logger.Warn("failed to fetch package for subscription detail",
			zap.String("subscription_id", subscriptionID),
			zap.Error(err),
		)
	} else if pkg != nil {
		detail.Package = pkg
	}

	// Fetch delivery stats
	if s.orderRepo != nil {
		count, err := s.orderRepo.CountDeliveredBySubscription(ctx, subscriptionID)
		if err != nil {
			s.logger.Warn("failed to count deliveries", zap.Error(err))
		} else {
			detail.DeliveryCount = count
		}

		spent, err := s.orderRepo.SumSpentBySubscription(ctx, subscriptionID)
		if err != nil {
			s.logger.Warn("failed to sum spent", zap.Error(err))
		} else {
			detail.TotalSpent = spent
		}

		nextDel, err := s.orderRepo.GetNextDeliveryDate(ctx, subscriptionID)
		if err != nil {
			s.logger.Warn("failed to get next delivery", zap.Error(err))
		} else if nextDel != nil {
			detail.NextDelivery = *nextDel
		}
	}

	// Fetch recent modifications
	mods, err := s.modRepo.ListBySubscription(ctx, subscriptionID, 5)
	if err != nil {
		s.logger.Warn("failed to fetch modifications", zap.Error(err))
	} else {
		detail.Modifications = mods
	}

	return detail, nil
}

// GetUpcomingDeliveries returns the next N delivery dates for a subscription.
func (s *SubscriptionService) GetUpcomingDeliveries(ctx context.Context, subscriptionID string, count int) ([]string, error) {
	if count <= 0 {
		count = 5
	}
	if count > 30 {
		count = 30
	}

	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return nil, fmt.Errorf("langganan tidak ditemukan")
		}
		return nil, fmt.Errorf("get subscription: %w", err)
	}

	if sub.Status != "active" {
		return nil, fmt.Errorf("hanya langganan aktif yang memiliki jadwal pengiriman")
	}

	// Fetch package to get delivery_days
	pkg, err := s.pkgRepo.GetByID(ctx, sub.PackageID)
	if err != nil {
		return nil, fmt.Errorf("get package: %w", err)
	}

	if len(pkg.DeliveryDays) == 0 {
		return []string{}, nil
	}

	// Generate upcoming delivery dates based on delivery_days (0=Sunday..6=Saturday)
	dates := make([]string, 0, count)
	today := time.Now().Truncate(24 * time.Hour)
	for d := 0; d < 60 && len(dates) < count; d++ {
		candidate := today.AddDate(0, 0, d)
		weekday := int(candidate.Weekday())
		for _, deliveryDay := range pkg.DeliveryDays {
			if weekday == deliveryDay {
				dates = append(dates, candidate.Format("2006-01-02"))
				break
			}
		}
	}

	return dates, nil
}

// ValidateDeliveryDay checks if a given date is a valid delivery day for the subscription.
func (s *SubscriptionService) ValidateDeliveryDay(ctx context.Context, subscriptionID string, date string) (bool, error) {
	sub, err := s.subRepo.GetByID(ctx, subscriptionID)
	if err != nil {
		if errors.Is(err, repository.ErrSubscriptionNotFound) {
			return false, fmt.Errorf("langganan tidak ditemukan")
		}
		return false, fmt.Errorf("get subscription: %w", err)
	}

	pkg, err := s.pkgRepo.GetByID(ctx, sub.PackageID)
	if err != nil {
		return false, fmt.Errorf("get package: %w", err)
	}

	parsedDate, err := time.Parse("2006-01-02", date)
	if err != nil {
		return false, fmt.Errorf("format tanggal tidak valid: %w", err)
	}

	weekday := int(parsedDate.Weekday())
	for _, deliveryDay := range pkg.DeliveryDays {
		if weekday == deliveryDay {
			return true, nil
		}
	}

	return false, nil
}

// GetSubscriberStats returns subscription stats for a pedagang.
func (s *SubscriptionService) GetSubscriberStats(ctx context.Context, pedagangID string) (*SubscriberStats, error) {
	stats := &SubscriberStats{}

	// Get all subscriptions for this pedagang
	allSubs, err := s.subRepo.ListByPedagang(ctx, pedagangID, "")
	if err != nil {
		return nil, fmt.Errorf("list subscriptions: %w", err)
	}

	stats.TotalSubscribers = len(allSubs)

	// Count by status and calculate revenue
	var totalPackagePrice float64
	for _, sub := range allSubs {
		switch sub.Status {
		case "active":
			stats.ActiveSubscribers++
			// Fetch package price for revenue calculation
			pkg, err := s.pkgRepo.GetByID(ctx, sub.PackageID)
			if err == nil {
				totalPackagePrice += pkg.Price
			}
		case "paused":
			stats.PausedSubscribers++
		}
	}

	// Monthly revenue = sum of active package prices * ~4.33 weeks/month
	// This is a rough estimate; actual revenue depends on delivery frequency
	stats.MonthlyRevenue = totalPackagePrice * 4.33

	// Avg deliveries per week based on package frequencies
	totalWeeklyDeliveries := 0.0
	for _, sub := range allSubs {
		if sub.Status != "active" {
			continue
		}
		pkg, err := s.pkgRepo.GetByID(ctx, sub.PackageID)
		if err != nil {
			continue
		}
		switch pkg.Frequency {
		case "daily":
			totalWeeklyDeliveries += float64(len(pkg.DeliveryDays))
		case "weekly":
			totalWeeklyDeliveries += 1
		case "biweekly":
			totalWeeklyDeliveries += 0.5
		default:
			totalWeeklyDeliveries += float64(len(pkg.DeliveryDays))
		}
	}

	if stats.ActiveSubscribers > 0 {
		stats.AvgDeliveryPerWeek = totalWeeklyDeliveries / float64(stats.ActiveSubscribers)
	}

	return stats, nil
}

// ShouldDeliverToday checks if a subscription has a delivery scheduled for today.
func (s *SubscriptionService) ShouldDeliverToday(ctx context.Context, subscriptionID string) (bool, error) {
	today := time.Now().Format("2006-01-02")
	return s.ValidateDeliveryDay(ctx, subscriptionID, today)
}
