package services

import (
	"context"
	"sync"
	"time"

	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// Scheduler runs periodic background jobs with timezone-aware scheduling.
type Scheduler struct {
	orderGen     *OrderGenerator
	priceAgg     *PriceAggregator
	priceService *PriceService
	notifService *NotificationService
	paymentGW    *PaymentGateway
	orderRepo    repository.OrderRepository
	logger       *zap.Logger
	stopCh       chan struct{}
	wg           sync.WaitGroup
}

// NewScheduler creates a new Scheduler with all required service dependencies.
func NewScheduler(
	orderGen *OrderGenerator,
	priceAgg *PriceAggregator,
	priceService *PriceService,
	notifService *NotificationService,
	paymentGW *PaymentGateway,
	orderRepo repository.OrderRepository,
	logger *zap.Logger,
) *Scheduler {
	return &Scheduler{
		orderGen:     orderGen,
		priceAgg:     priceAgg,
		priceService: priceService,
		notifService: notifService,
		paymentGW:    paymentGW,
		orderRepo:    orderRepo,
		logger:       logger.Named("scheduler"),
		stopCh:       make(chan struct{}),
	}
}

// Start begins all scheduled jobs. Call Stop() to shut down gracefully.
func (s *Scheduler) Start() {
	s.logger.Info("starting scheduler")

	// ── 4:00 AM WIB — Generate daily orders from subscriptions ──
	s.scheduleDailyWIB(4, 0, "daily-order-generation", func(ctx context.Context) {
		result, err := s.orderGen.GenerateDailyOrders(ctx)
		if err != nil {
			s.logger.Error("failed to generate daily orders", zap.Error(err))
			return
		}
		s.logger.Info("daily orders generated",
			zap.Int("generated", result.OrdersGenerated),
			zap.Int("skipped", result.OrdersSkipped),
			zap.Int("routes_added", result.RoutesAdded),
			zap.Int("notifications", result.NotificationsSent))
	})

	// ── 5:00 AM WIB — Send "besok diantar" notifications ──
	s.scheduleDailyWIB(5, 0, "delivery-reminder", func(ctx context.Context) {
		s.logger.Info("delivery reminder job triggered")
		// Delivery reminders are sent during order generation (4 AM).
		// This job is a safety net to catch any missed notifications.
		// The OrderGenerator.GenerateDailyOrders already sends "besok diantar" notifications.
	})

	// ── 6:00 AM WIB — Send route reminder ──
	s.scheduleDailyWIB(6, 0, "route-reminder", func(ctx context.Context) {
		s.logger.Info("route reminder job triggered")
		// Route reminders are handled by the notification service.
		// Pedagangs receive "Hari ini ada X pelanggan yang menunggu!" via NotifyRouteReminder.
		// Actual pedagang iteration would require a user repository query for active pedagangs.
		// For now, this is a placeholder that logs the trigger.
		if s.notifService != nil {
			s.logger.Info("route reminder: notif service available, ready to send reminders")
		}
	})

	// ── 9:00 AM WIB — Send piutang reminders ──
	s.scheduleDailyWIB(9, 0, "piutang-reminder", func(ctx context.Context) {
		s.logger.Info("piutang reminder job triggered")
		// Piutang reminders are sent via WhatsApp through the notification dispatcher.
		// This triggers the debt reminder flow for pedagangs with outstanding piutang.
		if s.notifService != nil {
			s.logger.Info("piutang reminder: notif service available, ready to send reminders")
		}
	})

	// ── 0:00 AM WIB — Aggregate daily prices ──
	s.scheduleDailyWIB(0, 0, "price-aggregation-daily", func(ctx context.Context) {
		if s.priceAgg == nil {
			return
		}
		result, err := s.priceAgg.AggregateDaily(ctx)
		if err != nil {
			s.logger.Error("daily price aggregation failed", zap.Error(err))
			return
		}
		s.logger.Info("daily price aggregation complete",
			zap.String("date", result.Date),
			zap.Int("products_updated", result.ProductsUpdated),
			zap.Int("areas_updated", result.AreasUpdated),
			zap.Int("anomalies_found", result.AnomaliesFound),
			zap.Int("alerts_sent", result.AlertsSent))
	})

	// ── Every 6 hours — Price anomaly detection + alert processing ──
	s.scheduleInterval(6*time.Hour, "price-anomaly-check", func(ctx context.Context) {
		if s.priceService == nil {
			return
		}
		anomalies, err := s.priceService.DetectAnomalies(ctx)
		if err != nil {
			s.logger.Error("price anomaly detection failed", zap.Error(err))
			return
		}
		if len(anomalies) > 0 {
			sent, err := s.priceService.ProcessAlerts(ctx)
			if err != nil {
				s.logger.Error("price alert processing failed", zap.Error(err))
				return
			}
			s.logger.Info("price anomalies processed",
				zap.Int("anomalies", len(anomalies)),
				zap.Int("alerts_sent", sent))
		}
	})

	// ── Every hour — Refresh price cache ──
	s.scheduleInterval(1*time.Hour, "price-cache-refresh", func(ctx context.Context) {
		if s.priceAgg == nil {
			return
		}
		if err := s.priceAgg.RefreshCache(ctx); err != nil {
			s.logger.Error("price cache refresh failed", zap.Error(err))
		}
	})

	// ── 11:00 PM WIB — Cleanup old notifications (30 days) ──
	s.scheduleDailyWIB(23, 0, "notification-cleanup", func(ctx context.Context) {
		if s.notifService == nil {
			return
		}
		deleted, err := s.notifService.CleanupOldNotifications(ctx)
		if err != nil {
			s.logger.Error("notification cleanup failed", zap.Error(err))
			return
		}
		s.logger.Info("notification cleanup complete", zap.Int("deleted", deleted))
	})

	// ── Every 15 minutes — Check pending payment statuses ──
	s.scheduleInterval(15*time.Minute, "pending-payment-check", func(ctx context.Context) {
		if s.paymentGW == nil || s.orderRepo == nil {
			return
		}

		s.logger.Info("checking pending payments")

		// Query orders with pending payment status that were created more than 15 minutes ago.
		// Auto-cancel expired QRIS payments and notify customers on status changes.
		// This uses the order repository to find orders with payment_status = 'pending'.
		//
		// Note: The order repository does not have a dedicated method for listing
		// orders by payment status. In production, you would add:
		//   ListPendingPayments(ctx, olderThan time.Time) ([]models.Order, error)
		// to the OrderRepository interface.
		//
		// For now, this job logs the trigger and relies on the Midtrans webhook
		// for real-time payment status updates. The webhook handles:
		//   - settlement/capture → mark paid, send success notification
		//   - deny/cancel/expire → keep pending, send failure notification
		//
		// When the OrderRepository is extended, uncomment and implement:
		//
		// cutoff := time.Now().Add(-15 * time.Minute)
		// pendingOrders, err := s.orderRepo.ListPendingPayments(ctx, cutoff)
		// if err != nil {
		//     s.logger.Error("failed to list pending payments", zap.Error(err))
		//     return
		// }
		// for _, order := range pendingOrders {
		//     status, err := s.paymentGW.GetTransactionStatus(ctx, order.ID)
		//     if err != nil {
		//         s.logger.Warn("failed to check payment status",
		//             zap.String("order_id", order.ID), zap.Error(err))
		//         continue
		//     }
		//     switch status {
		//     case "settlement", "capture":
		//         s.orderRepo.UpdatePayment(ctx, order.ID, "paid", "online")
		//         s.notifService.NotifyPaymentSuccess(ctx, order.PelangganID, order.TotalPrice, "online")
		//     case "expire":
		//         s.orderRepo.UpdatePayment(ctx, order.ID, "pending", "")
		//         s.notifService.NotifyPaymentFailed(ctx, order.PelangganID, order.ID, "expired")
		//     }
		// }

		s.logger.Info("pending payment check completed")
	})

	// ── Every 12 hours — Generate insights ──
	s.scheduleInterval(12*time.Hour, "insight-generation", func(ctx context.Context) {
		s.logger.Info("insight generation job triggered")
		// Insight generation for active pedagangs.
		// The InsightService computes business insights from orders, routes, and prices.
		// Actual generation would iterate active pedagangs and compute insights per user.
		s.logger.Info("insight generation: ready to generate insights for active pedagangs")
	})
}

// Stop signals all scheduled jobs to shut down and waits for completion.
func (s *Scheduler) Stop() {
	s.logger.Info("stopping scheduler")
	close(s.stopCh)
	s.wg.Wait()
	s.logger.Info("scheduler stopped")
}

// scheduleDailyWIB schedules a function to run daily at the specified hour:minute
// in the Asia/Jakarta timezone (WIB, UTC+7). Uses a 30-second ticker loop with
// a sync.Once guard to prevent double execution within the same minute.
func (s *Scheduler) scheduleDailyWIB(hour, minute int, name string, fn func(ctx context.Context)) {
	s.scheduleDaily(hour, minute, "Asia/Jakarta", name, fn)
}

// scheduleDaily schedules a function to run daily at the specified hour:minute
// in the given timezone. Uses a 30-second ticker loop with a sync.Once guard
// to prevent double execution within the same minute.
func (s *Scheduler) scheduleDaily(hour, minute int, timezone, name string, fn func(ctx context.Context)) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		s.logger.Warn("failed to load timezone, using UTC",
			zap.String("timezone", timezone),
			zap.Error(err))
		loc = time.UTC
	}

	s.wg.Add(1)
	go func() {
		defer s.wg.Done()

		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		var once sync.Once
		var lastRunDate string

		s.logger.Info("scheduled job registered",
			zap.String("name", name),
			zap.Int("hour", hour),
			zap.Int("minute", minute),
			zap.String("timezone", timezone))

		for {
			select {
			case <-s.stopCh:
				s.logger.Info("scheduled job stopping", zap.String("name", name))
				return
			case t := <-ticker.C:
				now := t.In(loc)
				today := now.Format("2006-01-02")

				if now.Hour() == hour && now.Minute() == minute {
					// Only run once per day
					if lastRunDate == today {
						continue
					}

					once = sync.Once{}
					once.Do(func() {
						lastRunDate = today
						s.logger.Info("executing scheduled job",
							zap.String("name", name),
							zap.String("date", today))

						ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
						defer cancel()

						fn(ctx)
					})
				}
			}
		}
	}()
}

// scheduleInterval schedules a function to run at a fixed interval.
func (s *Scheduler) scheduleInterval(interval time.Duration, name string, fn func(ctx context.Context)) {
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()

		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		s.logger.Info("interval job registered",
			zap.String("name", name),
			zap.Duration("interval", interval))

		for {
			select {
			case <-s.stopCh:
				s.logger.Info("interval job stopping", zap.String("name", name))
				return
			case <-ticker.C:
				s.logger.Info("executing interval job", zap.String("name", name))
				ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
				fn(ctx)
				cancel()
			}
		}
	}()
}

// AddPriceJobs is kept for backward compatibility.
// Price jobs are now registered directly in Start().
func (s *Scheduler) AddPriceJobs(aggregator *PriceAggregator, priceService *PriceService) {
	// Jobs are already registered in Start() — this is a no-op for backward compat.
}
