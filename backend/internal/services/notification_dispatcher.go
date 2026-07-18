package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// DeliveryResult captures the outcome of a notification delivery attempt.
type DeliveryResult struct {
	Channel   string `json:"channel"` // "whatsapp" or "sms"
	MessageID string `json:"message_id"`
	Status    string `json:"status"` // "sent", "failed", "fallback"
	Error     string `json:"error,omitempty"`
}

// NotificationDispatcher tries WhatsApp first and falls back to SMS on failure.
type NotificationDispatcher struct {
	whatsapp *WhatsAppService
	sms      *SMSService
	redis    *redis.Client
	logger   *zap.Logger
}

// NewNotificationDispatcher creates a NotificationDispatcher.
func NewNotificationDispatcher(whatsapp *WhatsAppService, sms *SMSService, redis *redis.Client, logger *zap.Logger) *NotificationDispatcher {
	return &NotificationDispatcher{
		whatsapp: whatsapp,
		sms:      sms,
		redis:    redis,
		logger:   logger.Named("notification"),
	}
}

// --- Redis helpers -------------------------------------------------------------

func (d *NotificationDispatcher) deliveryKey(phone string) string {
	return fmt.Sprintf("notif:delivery:%s", phone)
}

func (d *NotificationDispatcher) rateLimitKey(phone string) string {
	return fmt.Sprintf("notif:rate:%s", phone)
}

// recordDelivery stores the delivery method in Redis for analytics (24h TTL).
func (d *NotificationDispatcher) recordDelivery(ctx context.Context, phone string, result *DeliveryResult) {
	if d.redis == nil {
		return
	}
	data, err := json.Marshal(result)
	if err != nil {
		d.logger.Warn("failed to marshal delivery result", zap.Error(err))
		return
	}
	key := d.deliveryKey(phone)
	if err := d.redis.Set(ctx, key, data, 24*time.Hour).Err(); err != nil {
		d.logger.Warn("failed to record delivery in Redis", zap.Error(err))
	}
}

// checkRateLimit returns true if the phone number has exceeded the OTP rate limit.
// Allows at most 3 OTPs per 10 minutes per phone number.
func (d *NotificationDispatcher) checkRateLimit(ctx context.Context, phone string) (bool, error) {
	if d.redis == nil {
		return false, nil
	}
	key := d.rateLimitKey(phone)

	count, err := d.redis.Incr(ctx, key).Result()
	if err != nil {
		d.logger.Warn("rate limit check failed, allowing request", zap.Error(err))
		return false, nil
	}

	if count == 1 {
		d.redis.Expire(ctx, key, 10*time.Minute)
	}

	if count > 3 {
		d.logger.Warn("rate limit exceeded for phone", zap.String("phone", phone))
		return true, nil
	}
	return false, nil
}

// --- public methods ------------------------------------------------------------

// SendOTP tries to send an OTP via WhatsApp first.
// If WhatsApp fails, it falls back to SMS.
// Records the delivery method in Redis for analytics.
func (d *NotificationDispatcher) SendOTP(ctx context.Context, phone string, otp string) (*DeliveryResult, error) {
	// Check rate limit
	limited, err := d.checkRateLimit(ctx, phone)
	if err != nil {
		d.logger.Error("rate limit check error", zap.Error(err))
	}
	if limited {
		return nil, fmt.Errorf("rate limit exceeded for phone %s: too many OTP requests", phone)
	}

	// Try WhatsApp first
	d.logger.Info("attempting OTP delivery via WhatsApp", zap.String("phone", phone))
	msgID, err := d.whatsapp.SendOTP(ctx, phone, otp)
	if err == nil {
		result := &DeliveryResult{
			Channel:   "whatsapp",
			MessageID: msgID,
			Status:    "sent",
		}
		d.recordDelivery(ctx, phone, result)
		d.logger.Info("OTP sent via WhatsApp",
			zap.String("phone", phone),
			zap.String("message_id", msgID),
		)
		return result, nil
	}

	d.logger.Warn("WhatsApp OTP failed, falling back to SMS",
		zap.String("phone", phone),
		zap.Error(err),
	)
	waErr := err.Error()

	// Fallback to SMS
	smsID, err := d.sms.SendOTP(ctx, phone, otp)
	if err == nil {
		result := &DeliveryResult{
			Channel:   "sms",
			MessageID: smsID,
			Status:    "fallback",
			Error:     waErr,
		}
		d.recordDelivery(ctx, phone, result)
		d.logger.Info("OTP sent via SMS fallback",
			zap.String("phone", phone),
			zap.String("message_id", smsID),
		)
		return result, nil
	}

	// Both failed
	d.logger.Error("all OTP delivery channels failed",
		zap.String("phone", phone),
		zap.String("whatsapp_error", waErr),
		zap.String("sms_error", err.Error()),
	)

	result := &DeliveryResult{
		Channel: "none",
		Status:  "failed",
		Error:   fmt.Sprintf("whatsapp: %s; sms: %s", waErr, err.Error()),
	}
	d.recordDelivery(ctx, phone, result)
	return result, fmt.Errorf("all delivery channels failed for phone %s: whatsapp=%s; sms=%s", phone, waErr, err.Error())
}

// SendNotification sends a notification via the specified channel.
// If channel is "whatsapp" or "sms", it uses that channel directly.
// If channel is empty or "auto", it tries WhatsApp first, then SMS.
func (d *NotificationDispatcher) SendNotification(ctx context.Context, phone string, message string, channel string) (*DeliveryResult, error) {
	switch channel {
	case "whatsapp":
		return d.sendViaWhatsApp(ctx, phone, message)
	case "sms":
		return d.sendViaSMS(ctx, phone, message)
	default:
		// auto: try WhatsApp first, fall back to SMS
		return d.sendAutoNotification(ctx, phone, message)
	}
}

func (d *NotificationDispatcher) sendViaWhatsApp(ctx context.Context, phone string, message string) (*DeliveryResult, error) {
	d.logger.Info("sending notification via WhatsApp", zap.String("phone", phone))
	msgID, err := d.whatsapp.SendNotification(ctx, phone, message)
	if err != nil {
		result := &DeliveryResult{
			Channel: "whatsapp",
			Status:  "failed",
			Error:   err.Error(),
		}
		d.recordDelivery(ctx, phone, result)
		return result, fmt.Errorf("whatsapp notification failed: %w", err)
	}

	result := &DeliveryResult{
		Channel:   "whatsapp",
		MessageID: msgID,
		Status:    "sent",
	}
	d.recordDelivery(ctx, phone, result)
	return result, nil
}

func (d *NotificationDispatcher) sendViaSMS(ctx context.Context, phone string, message string) (*DeliveryResult, error) {
	d.logger.Info("sending notification via SMS", zap.String("phone", phone))
	msgID, err := d.sms.SendNotification(ctx, phone, message)
	if err != nil {
		result := &DeliveryResult{
			Channel: "sms",
			Status:  "failed",
			Error:   err.Error(),
		}
		d.recordDelivery(ctx, phone, result)
		return result, fmt.Errorf("sms notification failed: %w", err)
	}

	result := &DeliveryResult{
		Channel:   "sms",
		MessageID: msgID,
		Status:    "sent",
	}
	d.recordDelivery(ctx, phone, result)
	return result, nil
}

func (d *NotificationDispatcher) sendAutoNotification(ctx context.Context, phone string, message string) (*DeliveryResult, error) {
	// Try WhatsApp first
	d.logger.Info("attempting notification via WhatsApp (auto)", zap.String("phone", phone))
	msgID, err := d.whatsapp.SendNotification(ctx, phone, message)
	if err == nil {
		result := &DeliveryResult{
			Channel:   "whatsapp",
			MessageID: msgID,
			Status:    "sent",
		}
		d.recordDelivery(ctx, phone, result)
		return result, nil
	}

	d.logger.Warn("WhatsApp notification failed, falling back to SMS",
		zap.String("phone", phone),
		zap.Error(err),
	)
	waErr := err.Error()

	// Fallback to SMS
	smsID, err := d.sms.SendNotification(ctx, phone, message)
	if err == nil {
		result := &DeliveryResult{
			Channel:   "sms",
			MessageID: smsID,
			Status:    "fallback",
			Error:     waErr,
		}
		d.recordDelivery(ctx, phone, result)
		return result, nil
	}

	// Both failed
	d.logger.Error("all notification channels failed",
		zap.String("phone", phone),
		zap.String("whatsapp_error", waErr),
		zap.String("sms_error", err.Error()),
	)

	result := &DeliveryResult{
		Channel: "none",
		Status:  "failed",
		Error:   fmt.Sprintf("whatsapp: %s; sms: %s", waErr, err.Error()),
	}
	d.recordDelivery(ctx, phone, result)
	return result, fmt.Errorf("all delivery channels failed for phone %s: whatsapp=%s; sms=%s", phone, waErr, err.Error())
}
