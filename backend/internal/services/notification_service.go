package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

const (
	notifCachePrefix = "notif:unread:"
	notifCacheTTL    = 5 * time.Minute
)

// NotifBadge represents a gamification badge or achievement (notification variant).
type NotifBadge struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
	Level       int    `json:"level"`
	UnlockedAt  string `json:"unlocked_at"`
}

// NotificationService orchestrates in-app notification operations.
type NotificationService struct {
	notifRepo repository.NotificationRepository
	notifDisp *NotificationDispatcher
	redis     *redis.Client
	logger    *zap.Logger
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(
	notifRepo repository.NotificationRepository,
	notifDisp *NotificationDispatcher,
	redis *redis.Client,
	logger *zap.Logger,
) *NotificationService {
	return &NotificationService{
		notifRepo: notifRepo,
		notifDisp: notifDisp,
		redis:     redis,
		logger:    logger.Named("notification_service"),
	}
}

// Create creates a new in-app notification and invalidates the unread count cache.
func (s *NotificationService) Create(ctx context.Context, userID, notifType, title, body string, data map[string]string) error {
	notif := &models.Notification{
		ID:     uuid.New().String(),
		UserID: userID,
		Type:   notifType,
		Title:  title,
		Body:   body,
	}

	if data != nil {
		dataBytes, err := json.Marshal(data)
		if err != nil {
			s.logger.Warn("failed to marshal notification data", zap.Error(err))
			notif.Data = json.RawMessage("{}")
		} else {
			notif.Data = json.RawMessage(dataBytes)
		}
	} else {
		notif.Data = json.RawMessage("{}")
	}

	if err := s.notifRepo.Create(ctx, notif); err != nil {
		return fmt.Errorf("create notification: %w", err)
	}

	// Invalidate unread count cache
	s.invalidateUnreadCache(ctx, userID)

	s.logger.Debug("notification created",
		zap.String("id", notif.ID),
		zap.String("user_id", userID),
		zap.String("type", notifType),
		zap.String("title", title))

	return nil
}

// List returns a user's notifications.
func (s *NotificationService) List(ctx context.Context, userID string, unreadOnly bool, limit int) ([]models.Notification, error) {
	return s.notifRepo.ListByUser(ctx, userID, unreadOnly, limit)
}

// MarkAsRead marks a notification as read and invalidates the unread count cache.
func (s *NotificationService) MarkAsRead(ctx context.Context, notifID, userID string) error {
	// Verify the notification belongs to the user
	notif, err := s.notifRepo.GetByID(ctx, notifID)
	if err != nil {
		return fmt.Errorf("get notification: %w", err)
	}
	if notif.UserID != userID {
		return fmt.Errorf("notification does not belong to user")
	}

	if err := s.notifRepo.MarkAsRead(ctx, notifID, userID); err != nil {
		return fmt.Errorf("mark as read: %w", err)
	}

	s.invalidateUnreadCache(ctx, userID)
	return nil
}

// MarkAllAsRead marks all notifications as read for a user.
func (s *NotificationService) MarkAllAsRead(ctx context.Context, userID string) error {
	if err := s.notifRepo.MarkAllAsRead(ctx, userID); err != nil {
		return fmt.Errorf("mark all as read: %w", err)
	}

	s.invalidateUnreadCache(ctx, userID)
	return nil
}

// GetUnreadCount returns the unread notification count, using Redis cache when available.
func (s *NotificationService) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	// Try cache first
	if s.redis != nil {
		key := notifCachePrefix + userID
		val, err := s.redis.Get(ctx, key).Int()
		if err == nil {
			return val, nil
		}
	}

	count, err := s.notifRepo.CountUnread(ctx, userID)
	if err != nil {
		return 0, fmt.Errorf("count unread: %w", err)
	}

	// Store in cache
	if s.redis != nil {
		key := notifCachePrefix + userID
		s.redis.Set(ctx, key, count, notifCacheTTL)
	}

	return count, nil
}

// NotifyOrderCreated sends an in-app notification when a new order is created.
func (s *NotificationService) NotifyOrderCreated(ctx context.Context, order *models.Order) error {
	title := "Pesanan Baru 📦"
	body := fmt.Sprintf("Pesanan baru seharga Rp %.0f telah dibuat untuk pengantaran %s.", order.TotalPrice, order.DeliveryDate)

	data := map[string]string{
		"order_id":      order.ID,
		"delivery_date": order.DeliveryDate,
		"total_price":   fmt.Sprintf("%.0f", order.TotalPrice),
	}

	return s.Create(ctx, order.PelangganID, models.NotifTypeOrder, title, body, data)
}

// NotifyOrderDelivered sends an in-app notification when an order is delivered.
func (s *NotificationService) NotifyOrderDelivered(ctx context.Context, order *models.Order) error {
	title := "Pesanan Diantar ✅"
	body := fmt.Sprintf("Pesanan Anda seharga Rp %.0f telah berhasil diantar. Terima kasih!", order.TotalPrice)

	data := map[string]string{
		"order_id":      order.ID,
		"total_price":   fmt.Sprintf("%.0f", order.TotalPrice),
		"delivery_date": order.DeliveryDate,
	}

	return s.Create(ctx, order.PelangganID, models.NotifTypeOrder, title, body, data)
}

// NotifySubscriptionEvent sends an in-app notification for subscription lifecycle events.
func (s *NotificationService) NotifySubscriptionEvent(ctx context.Context, userID, event string, sub *models.Subscription) error {
	var title, body string

	switch event {
	case "activated":
		title = "Langganan Aktif 🎉"
		body = fmt.Sprintf("Langganan %s Anda telah aktif. Pesanan akan dikirim sesuai jadwal.", sub.PackageName)
	case "paused":
		title = "Langganan Dijeda ⏸"
		body = fmt.Sprintf("Langganan %s telah dijeda sementara.", sub.PackageName)
	case "resumed":
		title = "Langganan Dilanjut ▶️"
		body = fmt.Sprintf("Langganan %s telah dilanjutkan.", sub.PackageName)
	case "cancelled":
		title = "Langganan Dibatalkan ❌"
		body = fmt.Sprintf("Langganan %s telah dibatalkan.", sub.PackageName)
	default:
		title = "Pembaruan Langganan"
		body = fmt.Sprintf("Langganan %s telah diperbarui: %s.", sub.PackageName, event)
	}

	data := map[string]string{
		"subscription_id": sub.ID,
		"package_id":      sub.PackageID,
		"event":           event,
	}

	return s.Create(ctx, userID, models.NotifTypeSubscriber, title, body, data)
}

// NotifyPriceAlert sends an in-app notification when a price alert is triggered.
func (s *NotificationService) NotifyPriceAlert(ctx context.Context, alert *models.PriceAlert, change *PriceChange) error {
	direction := "naik"
	if change.Direction == "down" {
		direction = "turun"
	}

	title := fmt.Sprintf("Harga %s %s ⚠️", alert.ProductName, direction)
	body := fmt.Sprintf(
		"Harga %s di %s %s %.1f%% (dari Rp %.0f menjadi Rp %.0f).",
		alert.ProductName, alert.Area, direction, change.ChangePct, change.OldPrice, change.NewPrice,
	)

	data := map[string]string{
		"alert_id":   alert.ID,
		"product_id": alert.ProductID,
		"area":       alert.Area,
		"change_pct": fmt.Sprintf("%.1f", change.ChangePct),
		"direction":  change.Direction,
		"old_price":  fmt.Sprintf("%.0f", change.OldPrice),
		"new_price":  fmt.Sprintf("%.0f", change.NewPrice),
	}

	return s.Create(ctx, alert.UserID, "price_alert", title, body, data)
}

// NotifyRouteReminder sends a daily route reminder to a pedagang.
func (s *NotificationService) NotifyRouteReminder(ctx context.Context, pedagangID string, routeCount int) error {
	title := "Rute Hari Ini 🗺️"
	body := fmt.Sprintf("Hari ini ada %d pelanggan yang menunggu! Jangan lupa cek rute Anda.", routeCount)

	data := map[string]string{
		"route_count": fmt.Sprintf("%d", routeCount),
		"date":        time.Now().Format("2006-01-02"),
	}

	return s.Create(ctx, pedagangID, models.NotifTypeRoute, title, body, data)
}

// NotifyPiutangReminder sends a piutang (debt) reminder notification.
func (s *NotificationService) NotifyPiutangReminder(ctx context.Context, pedagangID string, totalPiutang float64, count int) error {
	title := "Pengingat Piutang 💰"
	body := fmt.Sprintf(
		"Anda memiliki %d piutang dengan total Rp %.0f. Segera tagih untuk menjaga arus kas.",
		count, totalPiutang,
	)

	data := map[string]string{
		"total_piutang": fmt.Sprintf("%.0f", totalPiutang),
		"count":         fmt.Sprintf("%d", count),
		"date":          time.Now().Format("2006-01-02"),
	}

	return s.Create(ctx, pedagangID, "piutang", title, body, data)
}

// NotifyRewardBadge sends a notification when a user earns a badge or levels up.
func (s *NotificationService) NotifyRewardBadge(ctx context.Context, userID string, badge *NotifBadge) error {
	title := fmt.Sprintf("Badge Baru: %s 🏆", badge.Name)
	body := fmt.Sprintf("Selamat! Anda mendapatkan badge \"%s\" — %s", badge.Name, badge.Description)

	data := map[string]string{
		"badge_id":   badge.ID,
		"badge_name": badge.Name,
		"badge_icon": badge.Icon,
		"level":      fmt.Sprintf("%d", badge.Level),
	}

	return s.Create(ctx, userID, models.NotifTypeReward, title, body, data)
}

// NotifyPaymentSuccess sends notification when payment is received.
func (s *NotificationService) NotifyPaymentSuccess(ctx context.Context, userID string, amount float64, method string) error {
	title := "Pembayaran Berhasil ✅"
	body := fmt.Sprintf("Pembayaran sebesar Rp %.0f melalui %s telah berhasil. Terima kasih!", amount, method)

	data := map[string]string{
		"amount": fmt.Sprintf("%.0f", amount),
		"method": method,
		"date":   time.Now().Format("2006-01-02 15:04"),
	}

	return s.Create(ctx, userID, models.NotifTypePayment, title, body, data)
}

// NotifyPaymentFailed sends notification when a payment fails.
func (s *NotificationService) NotifyPaymentFailed(ctx context.Context, userID string, orderID string, reason string) error {
	title := "Pembayaran Gagal ❌"
	body := fmt.Sprintf("Pembayaran untuk pesanan %s gagal (%s). Silakan coba lagi.", orderID, reason)

	data := map[string]string{
		"order_id": orderID,
		"reason":   reason,
		"date":     time.Now().Format("2006-01-02 15:04"),
	}

	return s.Create(ctx, userID, models.NotifTypePayment, title, body, data)
}

// NotifyInvoiceReady sends notification with invoice download link.
func (s *NotificationService) NotifyInvoiceReady(ctx context.Context, userID string, orderID string) error {
	title := "Invoice Tersedia 📄"
	body := fmt.Sprintf("Invoice untuk pesanan %s sudah dapat diunduh.", orderID)

	data := map[string]string{
		"order_id":    orderID,
		"invoice_url": fmt.Sprintf("/api/v1/payments/%s/invoice", orderID),
		"date":        time.Now().Format("2006-01-02 15:04"),
	}

	return s.Create(ctx, userID, models.NotifTypePayment, title, body, data)
}

// CleanupOldNotifications deletes notifications older than 30 days.
// Returns the number of deleted notifications.
func (s *NotificationService) CleanupOldNotifications(ctx context.Context) (int, error) {
	cutoff := time.Now().AddDate(0, 0, -30)

	deleted, err := s.notifRepo.DeleteOlderThanTime(ctx, cutoff)
	if err != nil {
		return 0, fmt.Errorf("cleanup old notifications: %w", err)
	}

	s.logger.Info("old notifications cleaned up",
		zap.Int("deleted", deleted),
		zap.Time("cutoff", cutoff))

	return deleted, nil
}

// invalidateUnreadCache clears the cached unread count for a user.
func (s *NotificationService) invalidateUnreadCache(ctx context.Context, userID string) {
	if s.redis == nil {
		return
	}
	key := notifCachePrefix + userID
	if err := s.redis.Del(ctx, key).Err(); err != nil {
		s.logger.Warn("failed to invalidate unread count cache",
			zap.String("user_id", userID), zap.Error(err))
	}
}
