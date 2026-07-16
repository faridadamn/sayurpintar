package repository

import (
	"context"
	"fmt"
	"time"
)

// SumOutstanding returns the outstanding balance for a pedagang.
func (r *debtRepo) SumOutstanding(ctx context.Context, pedagangID string) (float64, error) {
	var total float64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(remaining), 0)
		FROM debts
		WHERE pedagang_id = $1 AND status IN ('outstanding', 'partial')`, pedagangID).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("sum outstanding debts: %w", err)
	}
	return total, nil
}

// SumSettled returns the original value of settled debts for a pedagang.
func (r *debtRepo) SumSettled(ctx context.Context, pedagangID string) (float64, error) {
	var total float64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount), 0)
		FROM debts
		WHERE pedagang_id = $1 AND status = 'settled'`, pedagangID).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("sum settled debts: %w", err)
	}
	return total, nil
}

// CancelPendingBySubscription cancels pending future orders for a subscription.
func (r *orderRepo) CancelPendingBySubscription(ctx context.Context, subscriptionID string, from time.Time) (int, error) {
	commandTag, err := r.pool.Exec(ctx, `
		UPDATE orders
		SET status = 'cancelled', cancel_reason = 'subscription inactive', cancelled_at = NOW(), updated_at = NOW()
		WHERE subscription_id = $1
		  AND status = 'pending'
		  AND delivery_date >= $2`, subscriptionID, from.Format("2006-01-02"))
	if err != nil {
		return 0, fmt.Errorf("cancel pending subscription orders: %w", err)
	}
	return int(commandTag.RowsAffected()), nil
}

// CountDeliveredBySubscription counts completed deliveries for a subscription.
func (r *orderRepo) CountDeliveredBySubscription(ctx context.Context, subscriptionID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM orders
		WHERE subscription_id = $1 AND status = 'delivered'`, subscriptionID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count delivered subscription orders: %w", err)
	}
	return count, nil
}

// SumSpentBySubscription returns the total value of delivered orders.
func (r *orderRepo) SumSpentBySubscription(ctx context.Context, subscriptionID string) (float64, error) {
	var total float64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(total_price), 0) FROM orders
		WHERE subscription_id = $1 AND status = 'delivered'`, subscriptionID).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("sum delivered subscription orders: %w", err)
	}
	return total, nil
}

// GetNextDeliveryDate returns the nearest pending delivery date.
func (r *orderRepo) GetNextDeliveryDate(ctx context.Context, subscriptionID string) (*string, error) {
	var date *string
	err := r.pool.QueryRow(ctx, `
		SELECT MIN(delivery_date)::text FROM orders
		WHERE subscription_id = $1
		  AND status = 'pending'
		  AND delivery_date >= CURRENT_DATE`, subscriptionID).Scan(&date)
	if err != nil {
		return nil, fmt.Errorf("get next subscription delivery: %w", err)
	}
	return date, nil
}
