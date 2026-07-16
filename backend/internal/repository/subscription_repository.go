package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// SubscriptionRepository defines the data access contract for subscriptions.
type SubscriptionRepository interface {
	Create(ctx context.Context, sub *models.Subscription) error
	GetByID(ctx context.Context, id string) (*models.Subscription, error)
	GetActiveByPelangganAndPackage(ctx context.Context, pelangganID, packageID string) (*models.Subscription, error)
	UpdateStatus(ctx context.Context, id string, status string) error
	Pause(ctx context.Context, id string, reason string) error
	Resume(ctx context.Context, id string) error
	Cancel(ctx context.Context, id string, reason string) error
	ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Subscription, error)
	ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Subscription, error)
	CountByPackage(ctx context.Context, packageID string) (int, error)
	// GetActiveSubscriptionsForDate returns all active subscriptions that should deliver on the given date.
	GetActiveSubscriptionsForDate(ctx context.Context, date time.Time) ([]models.Subscription, error)
}

// SubscriptionPackageRepository defines the data access contract for subscription packages.
type SubscriptionPackageRepository interface {
	GetByID(ctx context.Context, id string) (*models.SubscriptionPackage, error)
}

// SubscriptionModificationRepository defines the data access contract for subscription modifications.
type SubscriptionModificationRepository interface {
	Create(ctx context.Context, mod *models.SubscriptionModification) error
	GetBySubscriptionAndDate(ctx context.Context, subscriptionID, deliveryDate string) (*models.SubscriptionModification, error)
	ListBySubscription(ctx context.Context, subscriptionID string, limit int) ([]models.SubscriptionModification, error)
}

// subscriptionRepo implements SubscriptionRepository backed by pgxpool.
type subscriptionRepo struct {
	pool *pgxpool.Pool
}

// NewSubscriptionRepository returns a new SubscriptionRepository.
func NewSubscriptionRepository(pool *pgxpool.Pool) SubscriptionRepository {
	return &subscriptionRepo{pool: pool}
}

const subscriptionColumns = `
	id, package_id, pedagang_id, pelanggan_id, payment_method, payment_frequency,
	status, start_date, end_date, pause_reason, paused_at, cancelled_at,
	cancel_reason, created_at, updated_at
`

func scanSubscription(row pgx.Row) (*models.Subscription, error) {
	var s models.Subscription
	err := row.Scan(
		&s.ID, &s.PackageID, &s.PedagangID, &s.PelangganID,
		&s.PaymentMethod, &s.PaymentFrequency, &s.Status, &s.StartDate,
		&s.EndDate, &s.PauseReason, &s.PausedAt, &s.CancelledAt,
		&s.CancelReason, &s.CreatedAt, &s.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *subscriptionRepo) Create(ctx context.Context, sub *models.Subscription) error {
	query := `
		INSERT INTO subscriptions (package_id, pedagang_id, pelanggan_id, payment_method,
			payment_frequency, status, start_date)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at`

	err := r.pool.QueryRow(ctx, query,
		sub.PackageID, sub.PedagangID, sub.PelangganID,
		sub.PaymentMethod, sub.PaymentFrequency, sub.Status, sub.StartDate,
	).Scan(&sub.ID, &sub.CreatedAt, &sub.UpdatedAt)

	if err != nil {
		return fmt.Errorf("insert subscription: %w", err)
	}
	return nil
}

func (r *subscriptionRepo) GetByID(ctx context.Context, id string) (*models.Subscription, error) {
	query := `SELECT ` + subscriptionColumns + ` FROM subscriptions WHERE id = $1`

	sub, err := scanSubscription(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSubscriptionNotFound
		}
		return nil, fmt.Errorf("get subscription by id: %w", err)
	}
	return sub, nil
}

func (r *subscriptionRepo) GetActiveByPelangganAndPackage(ctx context.Context, pelangganID, packageID string) (*models.Subscription, error) {
	query := `SELECT ` + subscriptionColumns + ` FROM subscriptions 
		WHERE pelanggan_id = $1 AND package_id = $2 AND status = 'active'`

	sub, err := scanSubscription(r.pool.QueryRow(ctx, query, pelangganID, packageID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("get active subscription: %w", err)
	}
	return sub, nil
}

func (r *subscriptionRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	query := `
		UPDATE subscriptions SET status = $2, updated_at = NOW()
		WHERE id = $1 RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, status).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSubscriptionNotFound
		}
		return fmt.Errorf("update subscription status: %w", err)
	}
	return nil
}

func (r *subscriptionRepo) Pause(ctx context.Context, id string, reason string) error {
	query := `
		UPDATE subscriptions
		SET status = 'paused', pause_reason = $2, paused_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'active'
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, reason).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSubscriptionNotFound
		}
		return fmt.Errorf("pause subscription: %w", err)
	}
	return nil
}

func (r *subscriptionRepo) Resume(ctx context.Context, id string) error {
	query := `
		UPDATE subscriptions
		SET status = 'active', pause_reason = NULL, paused_at = NULL, updated_at = NOW()
		WHERE id = $1 AND status = 'paused'
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSubscriptionNotFound
		}
		return fmt.Errorf("resume subscription: %w", err)
	}
	return nil
}

func (r *subscriptionRepo) Cancel(ctx context.Context, id string, reason string) error {
	query := `
		UPDATE subscriptions
		SET status = 'cancelled', cancel_reason = $2, cancelled_at = NOW(),
		    end_date = CURRENT_DATE, updated_at = NOW()
		WHERE id = $1 AND status IN ('active', 'paused')
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, reason).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSubscriptionNotFound
		}
		return fmt.Errorf("cancel subscription: %w", err)
	}
	return nil
}

func (r *subscriptionRepo) ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Subscription, error) {
	query := `SELECT ` + subscriptionColumns + ` FROM subscriptions WHERE pedagang_id = $1`
	args := []interface{}{pedagangID}

	if status != "" {
		query += ` AND status = $2`
		args = append(args, status)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list subscriptions by pedagang: %w", err)
	}
	defer rows.Close()

	var subs []models.Subscription
	for rows.Next() {
		var s models.Subscription
		if err := rows.Scan(
			&s.ID, &s.PackageID, &s.PedagangID, &s.PelangganID,
			&s.PaymentMethod, &s.PaymentFrequency, &s.Status, &s.StartDate,
			&s.EndDate, &s.PauseReason, &s.PausedAt, &s.CancelledAt,
			&s.CancelReason, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan subscription row: %w", err)
		}
		subs = append(subs, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate subscriptions: %w", err)
	}
	return subs, nil
}

func (r *subscriptionRepo) ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Subscription, error) {
	query := `SELECT ` + subscriptionColumns + ` FROM subscriptions WHERE pelanggan_id = $1`
	args := []interface{}{pelangganID}

	if status != "" {
		query += ` AND status = $2`
		args = append(args, status)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list subscriptions by pelanggan: %w", err)
	}
	defer rows.Close()

	var subs []models.Subscription
	for rows.Next() {
		var s models.Subscription
		if err := rows.Scan(
			&s.ID, &s.PackageID, &s.PedagangID, &s.PelangganID,
			&s.PaymentMethod, &s.PaymentFrequency, &s.Status, &s.StartDate,
			&s.EndDate, &s.PauseReason, &s.PausedAt, &s.CancelledAt,
			&s.CancelReason, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan subscription row: %w", err)
		}
		subs = append(subs, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate subscriptions: %w", err)
	}
	return subs, nil
}

func (r *subscriptionRepo) CountByPackage(ctx context.Context, packageID string) (int, error) {
	query := `SELECT COUNT(*) FROM subscriptions WHERE package_id = $1 AND status = 'active'`

	var count int
	err := r.pool.QueryRow(ctx, query, packageID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count subscribers: %w", err)
	}
	return count, nil
}

func (r *subscriptionRepo) GetActiveSubscriptionsForDate(ctx context.Context, date time.Time) ([]models.Subscription, error) {
	// dayOfWeek: 0=Sun, 1=Mon, ..., 6=Sat (matches PostgreSQL EXTRACT(DOW ...))
	dayOfWeek := int(date.Weekday())
	dateStr := date.Format("2006-01-02")

	query := `
		SELECT ` + subscriptionColumns + `, sp.name AS package_name
		FROM subscriptions s
		JOIN subscription_packages sp ON sp.id = s.package_id
		WHERE s.status = 'active'
		  AND s.start_date <= $1
		  AND (s.end_date IS NULL OR s.end_date >= $1)
		  AND $2 = ANY(sp.delivery_days)
		ORDER BY s.created_at`

	rows, err := r.pool.Query(ctx, query, dateStr, dayOfWeek)
	if err != nil {
		return nil, fmt.Errorf("get active subscriptions for date: %w", err)
	}
	defer rows.Close()

	var subs []models.Subscription
	for rows.Next() {
		var s models.Subscription
		if err := rows.Scan(
			&s.ID, &s.PackageID, &s.PedagangID, &s.PelangganID,
			&s.PaymentMethod, &s.PaymentFrequency, &s.Status, &s.StartDate,
			&s.EndDate, &s.PauseReason, &s.PausedAt, &s.CancelledAt,
			&s.CancelReason, &s.CreatedAt, &s.UpdatedAt,
			&s.PackageName,
		); err != nil {
			return nil, fmt.Errorf("scan subscription: %w", err)
		}
		subs = append(subs, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate subscriptions: %w", err)
	}
	return subs, nil
}

// --- SubscriptionPackageRepository implementation ---

type subscriptionPackageRepo struct {
	pool *pgxpool.Pool
}

// NewSubscriptionPackageRepository returns a new SubscriptionPackageRepository.
func NewSubscriptionPackageRepository(pool *pgxpool.Pool) SubscriptionPackageRepository {
	return &subscriptionPackageRepo{pool: pool}
}

const packageColumns = `
	id, pedagang_id, name, description, items, price, frequency,
	delivery_days, max_subscribers, is_active, created_at, updated_at
`

func scanPackage(row pgx.Row) (*models.SubscriptionPackage, error) {
	var p models.SubscriptionPackage
	err := row.Scan(
		&p.ID, &p.PedagangID, &p.Name, &p.Description, &p.Items,
		&p.Price, &p.Frequency, &p.DeliveryDays, &p.MaxSubscribers,
		&p.IsActive, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *subscriptionPackageRepo) GetByID(ctx context.Context, id string) (*models.SubscriptionPackage, error) {
	query := `SELECT ` + packageColumns + ` FROM subscription_packages WHERE id = $1`

	pkg, err := scanPackage(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSubscriptionPackageNotFound
		}
		return nil, fmt.Errorf("get package by id: %w", err)
	}
	return pkg, nil
}

// --- SubscriptionModificationRepository implementation ---

type subscriptionModificationRepo struct {
	pool *pgxpool.Pool
}

// NewSubscriptionModificationRepository returns a new SubscriptionModificationRepository.
func NewSubscriptionModificationRepository(pool *pgxpool.Pool) SubscriptionModificationRepository {
	return &subscriptionModificationRepo{pool: pool}
}

func (r *subscriptionModificationRepo) Create(ctx context.Context, mod *models.SubscriptionModification) error {
	query := `
		INSERT INTO subscription_modifications (subscription_id, delivery_date, items, skip_delivery, reason)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (subscription_id, delivery_date)
		DO UPDATE SET items = $3, skip_delivery = $4, reason = $5, created_at = NOW()
		RETURNING id, created_at`

	err := r.pool.QueryRow(ctx, query,
		mod.SubscriptionID, mod.DeliveryDate, mod.Items,
		mod.SkipDelivery, mod.Reason,
	).Scan(&mod.ID, &mod.CreatedAt)

	if err != nil {
		return fmt.Errorf("create modification: %w", err)
	}
	return nil
}

func (r *subscriptionModificationRepo) GetBySubscriptionAndDate(ctx context.Context, subscriptionID, deliveryDate string) (*models.SubscriptionModification, error) {
	query := `
		SELECT id, subscription_id, delivery_date, items, skip_delivery, reason, created_at
		FROM subscription_modifications
		WHERE subscription_id = $1 AND delivery_date = $2`

	var m models.SubscriptionModification
	err := r.pool.QueryRow(ctx, query, subscriptionID, deliveryDate).Scan(
		&m.ID, &m.SubscriptionID, &m.DeliveryDate, &m.Items,
		&m.SkipDelivery, &m.Reason, &m.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("get modification: %w", err)
	}
	return &m, nil
}

func (r *subscriptionModificationRepo) ListBySubscription(ctx context.Context, subscriptionID string, limit int) ([]models.SubscriptionModification, error) {
	if limit <= 0 || limit > 50 {
		limit = 10
	}

	query := `
		SELECT id, subscription_id, delivery_date, items, skip_delivery, reason, created_at
		FROM subscription_modifications
		WHERE subscription_id = $1
		ORDER BY delivery_date DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, query, subscriptionID, limit)
	if err != nil {
		return nil, fmt.Errorf("list modifications: %w", err)
	}
	defer rows.Close()

	var mods []models.SubscriptionModification
	for rows.Next() {
		var m models.SubscriptionModification
		if err := rows.Scan(
			&m.ID, &m.SubscriptionID, &m.DeliveryDate, &m.Items,
			&m.SkipDelivery, &m.Reason, &m.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan modification: %w", err)
		}
		mods = append(mods, m)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate modifications: %w", err)
	}
	return mods, nil
}
