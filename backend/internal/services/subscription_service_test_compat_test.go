package services

import (
	"context"
	"strings"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
)

func (m *mockSubscriptionRepo) GetActiveSubscriptionsForDate(ctx context.Context, date time.Time) ([]models.Subscription, error) {
	result := make([]models.Subscription, 0)
	for _, sub := range m.subs {
		if sub.Status == "active" {
			result = append(result, *sub)
		}
	}
	return result, nil
}

func (m *subscriptionMockOrderRepo) Create(ctx context.Context, order *models.Order) error {
	return nil
}

func (m *subscriptionMockOrderRepo) CreateBatch(ctx context.Context, orders []models.Order) error {
	return nil
}

func (m *subscriptionMockOrderRepo) GetByID(ctx context.Context, id string) (*models.Order, error) {
	return nil, nil
}

func (m *subscriptionMockOrderRepo) ListByPedagangAndDate(ctx context.Context, pedagangID string, date string) ([]models.Order, error) {
	return []models.Order{}, nil
}

func (m *subscriptionMockOrderRepo) ListByPelanggan(ctx context.Context, pelangganID string, limit int) ([]models.Order, error) {
	return []models.Order{}, nil
}

func (m *subscriptionMockOrderRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	return nil
}

func (m *subscriptionMockOrderRepo) MarkDelivered(ctx context.Context, id string) error {
	return nil
}

func (m *subscriptionMockOrderRepo) MarkCancelled(ctx context.Context, id string, reason string) error {
	return nil
}

func (m *subscriptionMockOrderRepo) AddRating(ctx context.Context, id string, rating int, comment string) error {
	return nil
}

func (m *subscriptionMockOrderRepo) UpdatePayment(ctx context.Context, id string, paymentStatus string, paymentMethod string) error {
	return nil
}

func (m *subscriptionMockOrderRepo) GetTodayOrders(ctx context.Context, pedagangID string) ([]models.Order, error) {
	return []models.Order{}, nil
}

func (m *subscriptionMockOrderRepo) GetOrderSummary(ctx context.Context, pedagangID string, date string) (*repository.OrderSummary, error) {
	return &repository.OrderSummary{Date: date}, nil
}

func (m *subscriptionMockOrderRepo) ExistsForSubscriptionAndDate(ctx context.Context, subscriptionID string, date string) (bool, error) {
	return false, nil
}

func (n *SubscriptionNotifier) buildWhatsAppMessage(template string, params map[string]string) string {
	message := template
	for key, value := range params {
		message = strings.ReplaceAll(message, "{"+key+"}", value)
	}
	return message
}

func dayNameID(day time.Weekday) string {
	names := [...]string{"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
	return names[int(day)]
}

func deliveryDaysToString(days []int) string {
	if len(days) == 0 {
		return "jadwal"
	}

	names := make([]string, 0, len(days))
	for _, day := range days {
		if day < 0 || day > 6 {
			continue
		}
		names = append(names, dayNameID(time.Weekday(day)))
	}
	if len(names) == 0 {
		return "jadwal"
	}
	return strings.Join(names, ", ")
}
