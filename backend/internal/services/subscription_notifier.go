package services

import (
	"context"
	"fmt"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// EnrichedOrder pairs an order with pelanggan phone for notification delivery.
type EnrichedOrder struct {
	models.Order
	PelangganPhone string `json:"pelanggan_phone"`
}

// SubscriptionNotifier handles sending WhatsApp/SMS notifications
// related to subscription events (confirmations, pauses, delivery reminders).
type SubscriptionNotifier struct {
	notifDispatcher *NotificationDispatcher
	subRepo         repository.SubscriptionRepository
	logger          *zap.Logger
}

// NewSubscriptionNotifier creates a SubscriptionNotifier.
func NewSubscriptionNotifier(
	notifDispatcher *NotificationDispatcher,
	subRepo repository.SubscriptionRepository,
	logger *zap.Logger,
) *SubscriptionNotifier {
	return &SubscriptionNotifier{
		notifDispatcher: notifDispatcher,
		subRepo:         subRepo,
		logger:          logger.Named("subscription-notifier"),
	}
}

// NotifyTomorrowDeliveries sends delivery reminders for tomorrow's orders.
func (n *SubscriptionNotifier) NotifyTomorrowDeliveries(ctx context.Context, orders []models.Order) (int, error) {
	if n.notifDispatcher == nil {
		return 0, nil
	}

	sent := 0
	for _, order := range orders {
		if order.PelangganPhone == "" {
			continue
		}

		message := fmt.Sprintf(
			"Pesanan Anda sebesar Rp%.0f akan diantar besok (%s). Terima kasih! 🥬",
			order.TotalPrice,
			order.DeliveryDate,
		)

		_, err := n.notifDispatcher.SendNotification(ctx, order.PelangganPhone, message, "auto")
		if err != nil {
			n.logger.Warn("failed to send delivery reminder",
				zap.String("order_id", order.ID),
				zap.Error(err))
			continue
		}
		sent++
	}

	return sent, nil
}

// NotifyTomorrowDeliveriesWithPhones sends delivery reminders with pre-fetched phone numbers.
func (n *SubscriptionNotifier) NotifyTomorrowDeliveriesWithPhones(ctx context.Context, orders []EnrichedOrder) (int, error) {
	if n.notifDispatcher == nil {
		return 0, nil
	}

	sent := 0
	for _, order := range orders {
		if order.PelangganPhone == "" {
			continue
		}

		message := fmt.Sprintf(
			"Pesanan Anda sebesar Rp%.0f akan diantar besok (%s). Terima kasih! 🥬",
			order.TotalPrice,
			order.DeliveryDate,
		)

		_, err := n.notifDispatcher.SendNotification(ctx, order.PelangganPhone, message, "auto")
		if err != nil {
			n.logger.Warn("failed to send delivery reminder",
				zap.String("order_id", order.ID),
				zap.Error(err))
			continue
		}
		sent++
	}

	return sent, nil
}

// NotifySubscriptionConfirmed sends a confirmation notification when a subscription is created.
func (n *SubscriptionNotifier) NotifySubscriptionConfirmed(ctx context.Context, sub *models.Subscription, pkg *models.SubscriptionPackage) error {
	if n.notifDispatcher == nil {
		return nil
	}

	// Get pelanggan phone from subscription (if available via join)
	if sub.PelangganPhone == "" {
		return nil
	}

	message := fmt.Sprintf(
		"Langganan Anda untuk paket \"%s\" telah aktif! Pengiriman pertama: %s. Terima kasih telah berlangganan SayurPintar! 🥬",
		sub.PackageName,
		sub.StartDate,
	)

	_, err := n.notifDispatcher.SendNotification(ctx, sub.PelangganPhone, message, "auto")
	return err
}

// NotifySubscriptionPaused sends a notification when a subscription is paused.
func (n *SubscriptionNotifier) NotifySubscriptionPaused(ctx context.Context, sub *models.Subscription) error {
	if n.notifDispatcher == nil || sub.PelangganPhone == "" {
		return nil
	}

	message := fmt.Sprintf(
		"Langganan Anda untuk paket \"%s\" telah dijeda. Anda dapat melanjutkan kapan saja melalui aplikasi.",
		sub.PackageName,
	)

	_, err := n.notifDispatcher.SendNotification(ctx, sub.PelangganPhone, message, "auto")
	return err
}

// NotifySubscriptionResumed sends a notification when a subscription is resumed.
func (n *SubscriptionNotifier) NotifySubscriptionResumed(ctx context.Context, sub *models.Subscription) error {
	if n.notifDispatcher == nil || sub.PelangganPhone == "" {
		return nil
	}

	message := fmt.Sprintf(
		"Langganan Anda untuk paket \"%s\" telah diaktifkan kembali! Pengiriman akan dilanjutkan sesuai jadwal.",
		sub.PackageName,
	)

	_, err := n.notifDispatcher.SendNotification(ctx, sub.PelangganPhone, message, "auto")
	return err
}

// NotifySubscriptionCancelled sends a notification when a subscription is cancelled.
func (n *SubscriptionNotifier) NotifySubscriptionCancelled(ctx context.Context, sub *models.Subscription) error {
	if n.notifDispatcher == nil || sub.PelangganPhone == "" {
		return nil
	}

	message := fmt.Sprintf(
		"Langganan Anda untuk paket \"%s\" telah dibatalkan. Kami harap Anda berlangganan kembali di masa depan!",
		sub.PackageName,
	)

	_, err := n.notifDispatcher.SendNotification(ctx, sub.PelangganPhone, message, "auto")
	return err
}
