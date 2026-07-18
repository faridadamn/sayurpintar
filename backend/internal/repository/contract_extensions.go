package repository

import (
	"context"
	"fmt"
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
