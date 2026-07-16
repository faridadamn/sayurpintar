package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// OrderSummary holds aggregate statistics for a day's orders.
type OrderSummary struct {
	Date          string  `json:"date"`
	TotalOrders   int     `json:"total_orders"`
	Delivered     int     `json:"delivered"`
	Cancelled     int     `json:"cancelled"`
	Pending       int     `json:"pending"`
	TotalRevenue  float64 `json:"total_revenue"`
	PaidAmount    float64 `json:"paid_amount"`
	UnpaidAmount  float64 `json:"unpaid_amount"`
	AvgRating     float64 `json:"avg_rating"`
}

// OrderRepository defines the data access contract for orders.
type OrderRepository interface {
	Create(ctx context.Context, order *models.Order) error
	CreateBatch(ctx context.Context, orders []models.Order) error
	GetByID(ctx context.Context, id string) (*models.Order, error)
	ListByPedagangAndDate(ctx context.Context, pedagangID string, date string) ([]models.Order, error)
	ListByPelanggan(ctx context.Context, pelangganID string, limit int) ([]models.Order, error)
	UpdateStatus(ctx context.Context, id string, status string) error
	MarkDelivered(ctx context.Context, id string) error
	MarkCancelled(ctx context.Context, id string, reason string) error
	AddRating(ctx context.Context, id string, rating int, comment string) error
	UpdatePayment(ctx context.Context, id string, paymentStatus string, paymentMethod string) error
	GetTodayOrders(ctx context.Context, pedagangID string) ([]models.Order, error)
	GetOrderSummary(ctx context.Context, pedagangID string, date string) (*OrderSummary, error)
	ExistsForSubscriptionAndDate(ctx context.Context, subscriptionID string, date string) (bool, error)
}

// orderRepo implements OrderRepository backed by pgxpool.
type orderRepo struct {
	pool *pgxpool.Pool
}

// NewOrderRepository returns a new OrderRepository.
func NewOrderRepository(pool *pgxpool.Pool) OrderRepository {
	return &orderRepo{pool: pool}
}

const orderColumns = `
	o.id, o.subscription_id, o.pedagang_id, o.pelanggan_id,
	o.items, o.total_price, o.status, o.delivery_date,
	o.delivery_notes, o.delivered_at, o.cancelled_at, o.cancel_reason,
	o.rating, o.rating_comment, o.rated_at,
	o.payment_method, o.payment_status, o.paid_at,
	o.created_at, o.updated_at`

const orderJoinColumns = orderColumns + `,
	COALESCE(u.name, '') AS pelanggan_name,
	COALESCE(u.phone, '') AS pelanggan_phone,
	COALESCE(u.address, '') AS pelanggan_address`

// scanOrder scans a row with JOIN columns into an Order struct.
func scanOrder(row pgx.Row) (*models.Order, error) {
	var o models.Order
	err := row.Scan(
		&o.ID, &o.SubscriptionID, &o.PedagangID, &o.PelangganID,
		&o.Items, &o.TotalPrice, &o.Status, &o.DeliveryDate,
		&o.DeliveryNotes, &o.DeliveredAt, &o.CancelledAt, &o.CancelReason,
		&o.Rating, &o.RatingComment, &o.RatedAt,
		&o.PaymentMethod, &o.PaymentStatus, &o.PaidAt,
		&o.CreatedAt, &o.UpdatedAt,
		&o.PelangganName, &o.PelangganPhone, &o.PelangganAddr,
	)
	if err != nil {
		return nil, err
	}
	return &o, nil
}

// scanOrderBasic scans a row without JOINs.
func scanOrderBasic(row pgx.Row) (*models.Order, error) {
	var o models.Order
	err := row.Scan(
		&o.ID, &o.SubscriptionID, &o.PedagangID, &o.PelangganID,
		&o.Items, &o.TotalPrice, &o.Status, &o.DeliveryDate,
		&o.DeliveryNotes, &o.DeliveredAt, &o.CancelledAt, &o.CancelReason,
		&o.Rating, &o.RatingComment, &o.RatedAt,
		&o.PaymentMethod, &o.PaymentStatus, &o.PaidAt,
		&o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &o, nil
}

// Create inserts a new order and populates generated fields.
func (r *orderRepo) Create(ctx context.Context, order *models.Order) error {
	if order.Items == nil {
		order.Items = json.RawMessage("[]")
	}

	query := `
		INSERT INTO orders (
			subscription_id, pedagang_id, pelanggan_id,
			items, total_price, status, delivery_date,
			delivery_notes, payment_method, payment_status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING ` + orderColumns

	row := r.pool.QueryRow(ctx, query,
		order.SubscriptionID, order.PedagangID, order.PelangganID,
		order.Items, order.TotalPrice, order.Status, order.DeliveryDate,
		order.DeliveryNotes, order.PaymentMethod, order.PaymentStatus,
	)

	created, err := scanOrderBasic(row)
	if err != nil {
		return fmt.Errorf("insert order: %w", err)
	}
	*order = *created
	return nil
}

// CreateBatch inserts multiple orders in a single transaction.
func (r *orderRepo) CreateBatch(ctx context.Context, orders []models.Order) error {
	if len(orders) == 0 {
		return nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	query := `
		INSERT INTO orders (
			subscription_id, pedagang_id, pelanggan_id,
			items, total_price, status, delivery_date,
			delivery_notes, payment_method, payment_status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at`

	for i := range orders {
		if orders[i].Items == nil {
			orders[i].Items = json.RawMessage("[]")
		}

		err := tx.QueryRow(ctx, query,
			orders[i].SubscriptionID, orders[i].PedagangID, orders[i].PelangganID,
			orders[i].Items, orders[i].TotalPrice, orders[i].Status, orders[i].DeliveryDate,
			orders[i].DeliveryNotes, orders[i].PaymentMethod, orders[i].PaymentStatus,
		).Scan(&orders[i].ID, &orders[i].CreatedAt, &orders[i].UpdatedAt)
		if err != nil {
			return fmt.Errorf("insert order[%d]: %w", i, err)
		}
	}

	return tx.Commit(ctx)
}

// GetByID fetches an order by UUID with pelanggan JOIN.
func (r *orderRepo) GetByID(ctx context.Context, id string) (*models.Order, error) {
	query := `
		SELECT ` + orderJoinColumns + `
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.id = $1`

	order, err := scanOrder(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrOrderNotFound
		}
		return nil, fmt.Errorf("get order by id: %w", err)
	}
	return order, nil
}

// ListByPedagangAndDate returns all orders for a pedagang on a given date.
func (r *orderRepo) ListByPedagangAndDate(ctx context.Context, pedagangID string, date string) ([]models.Order, error) {
	query := `
		SELECT ` + orderJoinColumns + `
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.pedagang_id = $1 AND o.delivery_date = $2
		ORDER BY o.created_at`

	rows, err := r.pool.Query(ctx, query, pedagangID, date)
	if err != nil {
		return nil, fmt.Errorf("list orders by pedagang and date: %w", err)
	}
	defer rows.Close()

	return scanOrderRows(rows)
}

// ListByPelanggan returns recent orders for a pelanggan.
func (r *orderRepo) ListByPelanggan(ctx context.Context, pelangganID string, limit int) ([]models.Order, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `
		SELECT ` + orderJoinColumns + `
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.pelanggan_id = $1
		ORDER BY o.delivery_date DESC, o.created_at DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, query, pelangganID, limit)
	if err != nil {
		return nil, fmt.Errorf("list orders by pelanggan: %w", err)
	}
	defer rows.Close()

	return scanOrderRows(rows)
}

// UpdateStatus changes the status of an order.
func (r *orderRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	query := `
		UPDATE orders
		SET status = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id, status).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrOrderNotFound
		}
		return fmt.Errorf("update order status: %w", err)
	}
	return nil
}

// MarkDelivered marks an order as delivered with timestamp.
func (r *orderRepo) MarkDelivered(ctx context.Context, id string) error {
	query := `
		UPDATE orders
		SET status = 'delivered', delivered_at = NOW(), updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrOrderNotFound
		}
		return fmt.Errorf("mark delivered: %w", err)
	}
	return nil
}

// MarkCancelled marks an order as cancelled with reason and timestamp.
func (r *orderRepo) MarkCancelled(ctx context.Context, id string, reason string) error {
	query := `
		UPDATE orders
		SET status = 'cancelled', cancel_reason = $2, cancelled_at = NOW(), updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id, reason).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrOrderNotFound
		}
		return fmt.Errorf("mark cancelled: %w", err)
	}
	return nil
}

// AddRating adds a customer rating to a delivered order.
func (r *orderRepo) AddRating(ctx context.Context, id string, rating int, comment string) error {
	query := `
		UPDATE orders
		SET rating = $2, rating_comment = $3, rated_at = NOW(), updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id, rating, comment).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrOrderNotFound
		}
		return fmt.Errorf("add rating: %w", err)
	}
	return nil
}

// UpdatePayment updates payment status and method.
func (r *orderRepo) UpdatePayment(ctx context.Context, id string, paymentStatus string, paymentMethod string) error {
	query := `
		UPDATE orders
		SET payment_status = $2, payment_method = $3,
		    paid_at = CASE WHEN $2 = 'paid' THEN NOW() ELSE paid_at END,
		    updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id, paymentStatus, paymentMethod).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrOrderNotFound
		}
		return fmt.Errorf("update payment: %w", err)
	}
	return nil
}

// GetTodayOrders returns all orders for a pedagang where delivery_date = today.
func (r *orderRepo) GetTodayOrders(ctx context.Context, pedagangID string) ([]models.Order, error) {
	query := `
		SELECT ` + orderJoinColumns + `
		FROM orders o
		LEFT JOIN users u ON u.id = o.pelanggan_id
		WHERE o.pedagang_id = $1 AND o.delivery_date = CURRENT_DATE
		ORDER BY o.created_at`

	rows, err := r.pool.Query(ctx, query, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("get today orders: %w", err)
	}
	defer rows.Close()

	return scanOrderRows(rows)
}

// GetOrderSummary returns aggregate stats for a pedagang's orders on a date.
func (r *orderRepo) GetOrderSummary(ctx context.Context, pedagangID string, date string) (*OrderSummary, error) {
	query := `
		SELECT
			COUNT(*) AS total_orders,
			COUNT(*) FILTER (WHERE status = 'delivered') AS delivered,
			COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
			COUNT(*) FILTER (WHERE status = 'pending') AS pending,
			COALESCE(SUM(total_price), 0) AS total_revenue,
			COALESCE(SUM(total_price) FILTER (WHERE payment_status = 'paid'), 0) AS paid_amount,
			COALESCE(SUM(total_price) FILTER (WHERE payment_status != 'paid'), 0) AS unpaid_amount,
			COALESCE(AVG(rating) FILTER (WHERE rating IS NOT NULL), 0) AS avg_rating
		FROM orders
		WHERE pedagang_id = $1 AND delivery_date = $2`

	var s OrderSummary
	s.Date = date
	err := r.pool.QueryRow(ctx, query, pedagangID, date).Scan(
		&s.TotalOrders, &s.Delivered, &s.Cancelled, &s.Pending,
		&s.TotalRevenue, &s.PaidAmount, &s.UnpaidAmount, &s.AvgRating,
	)
	if err != nil {
		return nil, fmt.Errorf("get order summary: %w", err)
	}
	return &s, nil
}

// ExistsForSubscriptionAndDate checks if an order already exists for a subscription on a date.
func (r *orderRepo) ExistsForSubscriptionAndDate(ctx context.Context, subscriptionID string, date string) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM orders WHERE subscription_id = $1 AND delivery_date = $2)`

	var exists bool
	err := r.pool.QueryRow(ctx, query, subscriptionID, date).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check order exists: %w", err)
	}
	return exists, nil
}

// scanOrderRows scans multiple rows with JOINs into a slice of Order.
func scanOrderRows(rows pgx.Rows) ([]models.Order, error) {
	var orders []models.Order
	for rows.Next() {
		var o models.Order
		if err := rows.Scan(
			&o.ID, &o.SubscriptionID, &o.PedagangID, &o.PelangganID,
			&o.Items, &o.TotalPrice, &o.Status, &o.DeliveryDate,
			&o.DeliveryNotes, &o.DeliveredAt, &o.CancelledAt, &o.CancelReason,
			&o.Rating, &o.RatingComment, &o.RatedAt,
			&o.PaymentMethod, &o.PaymentStatus, &o.PaidAt,
			&o.CreatedAt, &o.UpdatedAt,
			&o.PelangganName, &o.PelangganPhone, &o.PelangganAddr,
		); err != nil {
			return nil, fmt.Errorf("scan order row: %w", err)
		}
		orders = append(orders, o)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate orders: %w", err)
	}
	if orders == nil {
		orders = []models.Order{}
	}
	return orders, nil
}

// CancelPendingBySubscription cancels all pending orders for a subscription
// with delivery dates on or after the given date.
func (r *orderRepo) CancelPendingBySubscription(ctx context.Context, subscriptionID string, fromDate time.Time) (int, error) {
	query := `
		UPDATE orders
		SET status = 'cancelled', cancel_reason = 'subscription paused/cancelled',
		    cancelled_at = NOW(), updated_at = NOW()
		WHERE subscription_id = $1
		  AND status = 'pending'
		  AND delivery_date >= $2`

	tag, err := r.pool.Exec(ctx, query, subscriptionID, fromDate.Format("2006-01-02"))
	if err != nil {
		return 0, fmt.Errorf("cancel pending orders: %w", err)
	}
	return int(tag.RowsAffected()), nil
}

// CountDeliveredBySubscription returns the count of delivered orders for a subscription.
func (r *orderRepo) CountDeliveredBySubscription(ctx context.Context, subscriptionID string) (int, error) {
	query := `SELECT COUNT(*) FROM orders WHERE subscription_id = $1 AND status = 'delivered'`

	var count int
	err := r.pool.QueryRow(ctx, query, subscriptionID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count delivered orders: %w", err)
	}
	return count, nil
}

// SumSpentBySubscription returns the total amount spent on delivered orders for a subscription.
func (r *orderRepo) SumSpentBySubscription(ctx context.Context, subscriptionID string) (float64, error) {
	query := `SELECT COALESCE(SUM(total_price), 0) FROM orders WHERE subscription_id = $1 AND status = 'delivered'`

	var total float64
	err := r.pool.QueryRow(ctx, query, subscriptionID).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("sum spent: %w", err)
	}
	return total, nil
}

// GetNextDeliveryDate returns the next pending delivery date for a subscription.
func (r *orderRepo) GetNextDeliveryDate(ctx context.Context, subscriptionID string) (*string, error) {
	query := `
		SELECT delivery_date FROM orders
		WHERE subscription_id = $1 AND status = 'pending'
		ORDER BY delivery_date ASC LIMIT 1`

	var date string
	err := r.pool.QueryRow(ctx, query, subscriptionID).Scan(&date)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("get next delivery date: %w", err)
	}
	return &date, nil
}
