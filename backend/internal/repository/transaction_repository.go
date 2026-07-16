package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// TransactionRepository defines the data access contract for transactions.
type TransactionRepository interface {
	Create(ctx context.Context, txn *models.Transaction) error
	GetByID(ctx context.Context, id string) (*models.Transaction, error)
	ListByPedagang(ctx context.Context, pedagangID string, from, to string) ([]models.Transaction, error)
	GetDailyTotal(ctx context.Context, pedagangID string, date string) (float64, error)
	GetDailyByPaymentMethod(ctx context.Context, pedagangID string, date string) (map[string]float64, error)
	GetWeeklyTotals(ctx context.Context, pedagangID string, weekStart string) (map[string]float64, error)
	GetMonthlyTotal(ctx context.Context, pedagangID string, month string) (float64, error)
	GetDailyExpenseTotal(ctx context.Context, pedagangID string, date string) (float64, error)
	GetMonthlyExpenseTotal(ctx context.Context, pedagangID string, month string) (float64, error)
	GetDailyByCategory(ctx context.Context, pedagangID string, date string) (map[string]float64, error)
}

// transactionRepo implements TransactionRepository backed by pgxpool.
type transactionRepo struct {
	pool *pgxpool.Pool
}

// NewTransactionRepository returns a new TransactionRepository.
func NewTransactionRepository(pool *pgxpool.Pool) TransactionRepository {
	return &transactionRepo{pool: pool}
}

const transactionColumns = `
	id, pedagang_id, pelanggan_id, order_id, debt_id,
	type, amount, payment_method, payment_gateway,
	gateway_transaction_id, gateway_status, status, notes,
	created_at, updated_at
`

// Create inserts a new transaction and populates generated fields.
func (r *transactionRepo) Create(ctx context.Context, txn *models.Transaction) error {
	query := `
		INSERT INTO transactions (
			pedagang_id, pelanggan_id, order_id, debt_id,
			type, amount, payment_method, payment_gateway,
			gateway_transaction_id, gateway_status, status, notes
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at`

	err := r.pool.QueryRow(ctx, query,
		txn.PedagangID, txn.PelangganID, txn.OrderID, txn.DebtID,
		txn.Type, txn.Amount, txn.PaymentMethod, txn.PaymentGateway,
		txn.GatewayTransactionID, txn.GatewayStatus, txn.Status, txn.Notes,
	).Scan(&txn.ID, &txn.CreatedAt, &txn.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert transaction: %w", err)
	}
	return nil
}

// GetByID fetches a transaction by UUID.
func (r *transactionRepo) GetByID(ctx context.Context, id string) (*models.Transaction, error) {
	query := `SELECT ` + transactionColumns + ` FROM transactions WHERE id = $1`

	var t models.Transaction
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&t.ID, &t.PedagangID, &t.PelangganID, &t.OrderID, &t.DebtID,
		&t.Type, &t.Amount, &t.PaymentMethod, &t.PaymentGateway,
		&t.GatewayTransactionID, &t.GatewayStatus, &t.Status, &t.Notes,
		&t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get transaction by id: %w", err)
	}
	return &t, nil
}

// ListByPedagang returns transactions for a pedagang within a date range.
func (r *transactionRepo) ListByPedagang(ctx context.Context, pedagangID string, from, to string) ([]models.Transaction, error) {
	query := `SELECT ` + transactionColumns + ` FROM transactions WHERE pedagang_id = $1`
	args := []interface{}{pedagangID}
	argIdx := 2

	if from != "" {
		query += fmt.Sprintf(" AND created_at >= $%d", argIdx)
		args = append(args, from)
		argIdx++
	}
	if to != "" {
		query += fmt.Sprintf(" AND created_at <= $%d", argIdx)
		args = append(args, to+" 23:59:59")
		argIdx++
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list transactions: %w", err)
	}
	defer rows.Close()

	var txns []models.Transaction
	for rows.Next() {
		var t models.Transaction
		if err := rows.Scan(
			&t.ID, &t.PedagangID, &t.PelangganID, &t.OrderID, &t.DebtID,
			&t.Type, &t.Amount, &t.PaymentMethod, &t.PaymentGateway,
			&t.GatewayTransactionID, &t.GatewayStatus, &t.Status, &t.Notes,
			&t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan transaction: %w", err)
		}
		txns = append(txns, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate transactions: %w", err)
	}
	if txns == nil {
		txns = []models.Transaction{}
	}
	return txns, nil
}

// GetDailyTotal returns the sum of sale transactions for a pedagang on a date.
func (r *transactionRepo) GetDailyTotal(ctx context.Context, pedagangID string, date string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'sale'
		  AND DATE(created_at) = $2::date`

	var total float64
	err := r.pool.QueryRow(ctx, query, pedagangID, date).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get daily total: %w", err)
	}
	return total, nil
}

// GetDailyByPaymentMethod returns sale totals grouped by payment method for a date.
func (r *transactionRepo) GetDailyByPaymentMethod(ctx context.Context, pedagangID string, date string) (map[string]float64, error) {
	query := `
		SELECT COALESCE(payment_method, 'unknown'), COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'sale'
		  AND DATE(created_at) = $2::date
		GROUP BY payment_method`

	rows, err := r.pool.Query(ctx, query, pedagangID, date)
	if err != nil {
		return nil, fmt.Errorf("get daily by payment method: %w", err)
	}
	defer rows.Close()

	result := make(map[string]float64)
	for rows.Next() {
		var method string
		var total float64
		if err := rows.Scan(&method, &total); err != nil {
			return nil, fmt.Errorf("scan payment method: %w", err)
		}
		result[method] = total
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate payment methods: %w", err)
	}
	return result, nil
}

// GetWeeklyTotals returns daily sale totals for each day of the week starting from weekStart.
func (r *transactionRepo) GetWeeklyTotals(ctx context.Context, pedagangID string, weekStart string) (map[string]float64, error) {
	query := `
		SELECT TO_CHAR(DATE(created_at), 'YYYY-MM-DD'), COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'sale'
		  AND DATE(created_at) >= $2::date
		  AND DATE(created_at) < ($2::date + INTERVAL '7 days')
		GROUP BY DATE(created_at)
		ORDER BY DATE(created_at)`

	rows, err := r.pool.Query(ctx, query, pedagangID, weekStart)
	if err != nil {
		return nil, fmt.Errorf("get weekly totals: %w", err)
	}
	defer rows.Close()

	result := make(map[string]float64)
	for rows.Next() {
		var day string
		var total float64
		if err := rows.Scan(&day, &total); err != nil {
			return nil, fmt.Errorf("scan weekly total: %w", err)
		}
		result[day] = total
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate weekly totals: %w", err)
	}
	return result, nil
}

// GetMonthlyTotal returns the sum of sale transactions for a month (YYYY-MM).
func (r *transactionRepo) GetMonthlyTotal(ctx context.Context, pedagangID string, month string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'sale'
		  AND TO_CHAR(created_at, 'YYYY-MM') = $2`

	var total float64
	err := r.pool.QueryRow(ctx, query, pedagangID, month).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get monthly total: %w", err)
	}
	return total, nil
}

// GetDailyExpenseTotal returns the sum of expense transactions for a pedagang on a date.
func (r *transactionRepo) GetDailyExpenseTotal(ctx context.Context, pedagangID string, date string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'expense'
		  AND DATE(created_at) = $2::date`

	var total float64
	err := r.pool.QueryRow(ctx, query, pedagangID, date).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get daily expense total: %w", err)
	}
	return total, nil
}

// GetMonthlyExpenseTotal returns the sum of expense transactions for a month (YYYY-MM).
func (r *transactionRepo) GetMonthlyExpenseTotal(ctx context.Context, pedagangID string, month string) (float64, error) {
	query := `
		SELECT COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'expense'
		  AND TO_CHAR(created_at, 'YYYY-MM') = $2`

	var total float64
	err := r.pool.QueryRow(ctx, query, pedagangID, month).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get monthly expense total: %w", err)
	}
	return total, nil
}

// GetDailyByCategory returns expense totals grouped by notes category for a date.
func (r *transactionRepo) GetDailyByCategory(ctx context.Context, pedagangID string, date string) (map[string]float64, error) {
	query := `
		SELECT COALESCE(notes, 'lainnya'), COALESCE(SUM(amount), 0)
		FROM transactions
		WHERE pedagang_id = $1 AND type = 'expense'
		  AND DATE(created_at) = $2::date
		GROUP BY notes`

	rows, err := r.pool.Query(ctx, query, pedagangID, date)
	if err != nil {
		return nil, fmt.Errorf("get daily by category: %w", err)
	}
	defer rows.Close()

	result := make(map[string]float64)
	for rows.Next() {
		var cat string
		var total float64
		if err := rows.Scan(&cat, &total); err != nil {
			return nil, fmt.Errorf("scan category: %w", err)
		}
		result[cat] = total
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate categories: %w", err)
	}
	return result, nil
}
