package services

import (
	"context"
	"time"
)

func (m *mockOrderRepo) CancelPendingBySubscription(ctx context.Context, subscriptionID string, from time.Time) (int, error) {
	return 0, nil
}

func (m *mockOrderRepo) CountDeliveredBySubscription(ctx context.Context, subscriptionID string) (int, error) {
	return 0, nil
}

func (m *mockOrderRepo) SumSpentBySubscription(ctx context.Context, subscriptionID string) (float64, error) {
	return 0, nil
}

func (m *mockOrderRepo) GetNextDeliveryDate(ctx context.Context, subscriptionID string) (*string, error) {
	return nil, nil
}
