package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// DebtRepository defines the data access contract for debts (piutang).
type DebtRepository interface {
	Create(ctx context.Context, debt *models.Debt) error
	GetByID(ctx context.Context, id string) (*models.Debt, error)
	ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Debt, error)
	ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Debt, error)
	AddPayment(ctx context.Context, debtID string, amount float64) error
	UpdateStatus(ctx context.Context, debtID string, status string) error
	IncrementReminder(ctx context.Context, debtID string) error
	WriteOff(ctx context.Context, debtID string, reason string) error
	GetOverdue(ctx context.Context, pedagangID string, days int) ([]models.Debt, error)
	GetTotalOutstanding(ctx context.Context, pedagangID string) (float64, int, error)
	GetByOrderID(ctx context.Context, orderID string) (*models.Debt, error)
}

// debtRepo implements DebtRepository backed by pgxpool.
type debtRepo struct {
	pool *pgxpool.Pool
}

// NewDebtRepository returns a new DebtRepository.
func NewDebtRepository(pool *pgxpool.Pool) DebtRepository {
	return &debtRepo{pool: pool}
}

const debtColumns = `
	d.id, d.pedagang_id, d.pelanggan_id, d.order_id,
	d.amount, d.amount_paid, d.remaining, d.status,
	d.reminder_count, d.last_reminder_at, d.due_date,
	d.settled_at, d.write_off_reason, d.created_at, d.updated_at`

const debtJoinColumns = debtColumns + `,
	COALESCE(u.name, '') AS pelanggan_name,
	COALESCE(u.phone, '') AS pelanggan_phone`

func scanDebt(row pgx.Row) (*models.Debt, error) {
	var d models.Debt
	err := row.Scan(
		&d.ID, &d.PedagangID, &d.PelangganID, &d.OrderID,
		&d.Amount, &d.AmountPaid, &d.Remaining, &d.Status,
		&d.ReminderCount, &d.LastReminderAt, &d.DueDate,
		&d.SettledAt, &d.WriteOffReason, &d.CreatedAt, &d.UpdatedAt,
		&d.PelangganName, &d.PelangganPhone,
	)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

func scanDebtRows(rows pgx.Rows) ([]models.Debt, error) {
	var debts []models.Debt
	for rows.Next() {
		var d models.Debt
		if err := rows.Scan(
			&d.ID, &d.PedagangID, &d.PelangganID, &d.OrderID,
			&d.Amount, &d.AmountPaid, &d.Remaining, &d.Status,
			&d.ReminderCount, &d.LastReminderAt, &d.DueDate,
			&d.SettledAt, &d.WriteOffReason, &d.CreatedAt, &d.UpdatedAt,
			&d.PelangganName, &d.PelangganPhone,
		); err != nil {
			return nil, fmt.Errorf("scan debt row: %w", err)
		}
		debts = append(debts, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate debts: %w", err)
	}
	if debts == nil {
		debts = []models.Debt{}
	}
	return debts, nil
}

// Create inserts a new debt and populates generated fields.
func (r *debtRepo) Create(ctx context.Context, debt *models.Debt) error {
	query := `
		INSERT INTO debts (pedagang_id, pelanggan_id, order_id, amount, due_date)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, remaining, status, created_at, updated_at`

	err := r.pool.QueryRow(ctx, query,
		debt.PedagangID, debt.PelangganID, debt.OrderID, debt.Amount, debt.DueDate,
	).Scan(&debt.ID, &debt.Remaining, &debt.Status, &debt.CreatedAt, &debt.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert debt: %w", err)
	}
	return nil
}

// GetByID fetches a debt by UUID with pelanggan JOIN.
func (r *debtRepo) GetByID(ctx context.Context, id string) (*models.Debt, error) {
	query := `
		SELECT ` + debtJoinColumns + `
		FROM debts d
		LEFT JOIN users u ON u.id = d.pelanggan_id
		WHERE d.id = $1`

	debt, err := scanDebt(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrDebtNotFound
		}
		return nil, fmt.Errorf("get debt by id: %w", err)
	}
	return debt, nil
}

// ListByPedagang returns debts for a pedagang, optionally filtered by status.
func (r *debtRepo) ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Debt, error) {
	query := `
		SELECT ` + debtJoinColumns + `
		FROM debts d
		LEFT JOIN users u ON u.id = d.pelanggan_id
		WHERE d.pedagang_id = $1`
	args := []interface{}{pedagangID}
	argIdx := 2

	if status != "" {
		query += fmt.Sprintf(" AND d.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	query += " ORDER BY d.due_date ASC NULLS LAST, d.created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list debts by pedagang: %w", err)
	}
	defer rows.Close()

	return scanDebtRows(rows)
}

// ListByPelanggan returns debts for a pelanggan, optionally filtered by status.
func (r *debtRepo) ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Debt, error) {
	query := `
		SELECT ` + debtJoinColumns + `
		FROM debts d
		LEFT JOIN users u ON u.id = d.pelanggan_id
		WHERE d.pelanggan_id = $1`
	args := []interface{}{pelangganID}
	argIdx := 2

	if status != "" {
		query += fmt.Sprintf(" AND d.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	query += " ORDER BY d.due_date ASC NULLS LAST, d.created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list debts by pelanggan: %w", err)
	}
	defer rows.Close()

	return scanDebtRows(rows)
}

// AddPayment records a partial or full payment against a debt.
func (r *debtRepo) AddPayment(ctx context.Context, debtID string, amount float64) error {
	query := `
		UPDATE debts
		SET amount_paid = amount_paid + $2,
			status = CASE
				WHEN (amount_paid + $2) >= amount THEN 'settled'
				WHEN (amount_paid + $2) > 0 THEN 'partial'
				ELSE status
			END,
			settled_at = CASE
				WHEN (amount_paid + $2) >= amount THEN NOW()
				ELSE settled_at
			END,
			updated_at = NOW()
		WHERE id = $1 AND status NOT IN ('settled', 'written_off')
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, debtID, amount).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrDebtNotFound
		}
		return fmt.Errorf("add payment to debt: %w", err)
	}
	return nil
}

// UpdateStatus changes the status of a debt.
func (r *debtRepo) UpdateStatus(ctx context.Context, debtID string, status string) error {
	query := `
		UPDATE debts
		SET status = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, debtID, status).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrDebtNotFound
		}
		return fmt.Errorf("update debt status: %w", err)
	}
	return nil
}

// IncrementReminder increments the reminder count and updates the last reminder timestamp.
func (r *debtRepo) IncrementReminder(ctx context.Context, debtID string) error {
	query := `
		UPDATE debts
		SET reminder_count = reminder_count + 1,
			last_reminder_at = NOW(),
			updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, debtID).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrDebtNotFound
		}
		return fmt.Errorf("increment reminder: %w", err)
	}
	return nil
}

// WriteOff marks a debt as uncollectable.
func (r *debtRepo) WriteOff(ctx context.Context, debtID string, reason string) error {
	query := `
		UPDATE debts
		SET status = 'written_off', write_off_reason = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, debtID, reason).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrDebtNotFound
		}
		return fmt.Errorf("write off debt: %w", err)
	}
	return nil
}

// GetOverdue returns outstanding/partial debts that are overdue by at least `days` days.
func (r *debtRepo) GetOverdue(ctx context.Context, pedagangID string, days int) ([]models.Debt, error) {
	query := `
		SELECT ` + debtJoinColumns + `
		FROM debts d
		LEFT JOIN users u ON u.id = d.pelanggan_id
		WHERE d.pedagang_id = $1
		  AND d.status IN ('outstanding', 'partial')
		  AND d.due_date IS NOT NULL
		  AND d.due_date <= CURRENT_DATE - INTERVAL '1 day' * $2
		ORDER BY d.due_date ASC`

	rows, err := r.pool.Query(ctx, query, pedagangID, days)
	if err != nil {
		return nil, fmt.Errorf("get overdue debts: %w", err)
	}
	defer rows.Close()

	return scanDebtRows(rows)
}

// GetTotalOutstanding returns the total outstanding amount and count for a pedagang.
func (r *debtRepo) GetTotalOutstanding(ctx context.Context, pedagangID string) (float64, int, error) {
	query := `
		SELECT COALESCE(SUM(remaining), 0), COUNT(*)
		FROM debts
		WHERE pedagang_id = $1 AND status IN ('outstanding', 'partial')`

	var total float64
	var count int
	err := r.pool.QueryRow(ctx, query, pedagangID).Scan(&total, &count)
	if err != nil {
		return 0, 0, fmt.Errorf("get total outstanding: %w", err)
	}
	return total, count, nil
}

// GetByOrderID fetches the debt associated with an order.
func (r *debtRepo) GetByOrderID(ctx context.Context, orderID string) (*models.Debt, error) {
	query := `
		SELECT ` + debtJoinColumns + `
		FROM debts d
		LEFT JOIN users u ON u.id = d.pelanggan_id
		WHERE d.order_id = $1
		LIMIT 1`

	debt, err := scanDebt(r.pool.QueryRow(ctx, query, orderID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrDebtNotFound
		}
		return nil, fmt.Errorf("get debt by order id: %w", err)
	}
	return debt, nil
}
