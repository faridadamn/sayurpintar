package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// VisitRepository defines the data access contract for visits.
type VisitRepository interface {
	Create(ctx context.Context, visit *models.Visit) error
	CreateBatch(ctx context.Context, visits []models.Visit) error
	GetByID(ctx context.Context, id string) (*models.Visit, error)
	ListByRoute(ctx context.Context, routeID string) ([]models.Visit, error)
	Update(ctx context.Context, visit *models.Visit) error
	UpdateStatus(ctx context.Context, id string, status string) error
	MarkArrived(ctx context.Context, id string) error
	MarkCompleted(ctx context.Context, id string, items json.RawMessage, amount float64, paymentMethod string) error
	MarkSkipped(ctx context.Context, id string, reason string) error
	GetVisitHistory(ctx context.Context, pelangganID string, limit int) ([]models.Visit, error)
	GetStatsByPedagang(ctx context.Context, pedagangID string, from, to string) (*VisitStats, error)
}

// VisitStats holds aggregated visit statistics for a pedagang.
type VisitStats struct {
	TotalVisits  int            `json:"total_visits"`
	Completed    int            `json:"completed"`
	Skipped      int            `json:"skipped"`
	TotalRevenue float64        `json:"total_revenue"`
	AvgDuration  float64        `json:"avg_duration_min"`
	TopCustomers []CustomerStat `json:"top_customers"`
}

// CustomerStat holds per-customer visit statistics.
type CustomerStat struct {
	PelangganID   string  `json:"pelanggan_id"`
	PelangganName string  `json:"pelanggan_name"`
	VisitCount    int     `json:"visit_count"`
	TotalRevenue  float64 `json:"total_revenue"`
}

// visitRepo implements VisitRepository backed by pgxpool.
type visitRepo struct {
	pool *pgxpool.Pool
}

// NewVisitRepository returns a new VisitRepository.
func NewVisitRepository(pool *pgxpool.Pool) VisitRepository {
	return &visitRepo{pool: pool}
}

const visitColumns = `
	v.id, v.route_id, v.waypoint_id, v.pelanggan_id, v.order_id,
	v.visit_order, v.planned_arrival::text, v.actual_arrival, v.actual_departure,
	v.items_sold, v.amount, v.payment_method, v.payment_status,
	v.notes, v.status, v.created_at, v.updated_at
`

const visitJoinColumns = visitColumns + `,
	COALESCE(w.label, '') AS waypoint_label,
	COALESCE(u.name, '') AS pelanggan_name,
	CASE
		WHEN v.actual_arrival IS NOT NULL AND v.actual_departure IS NOT NULL
		THEN EXTRACT(EPOCH FROM (v.actual_departure - v.actual_arrival)) / 60
		ELSE 0
	END::int AS duration_min
`

// scanVisit scans a single row (with joins) into a Visit struct.
func scanVisit(row pgx.Row) (*models.Visit, error) {
	var v models.Visit
	var plannedArrival *string

	err := row.Scan(
		&v.ID, &v.RouteID, &v.WaypointID, &v.PelangganID, &v.OrderID,
		&v.VisitOrder, &plannedArrival, &v.ActualArrival, &v.ActualDeparture,
		&v.ItemsSold, &v.Amount, &v.PaymentMethod, &v.PaymentStatus,
		&v.Notes, &v.Status, &v.CreatedAt, &v.UpdatedAt,
		&v.WaypointLabel, &v.PelangganName, &v.DurationMin,
	)
	if err != nil {
		return nil, err
	}

	v.PlannedArrival = plannedArrival
	return &v, nil
}

// scanVisitRow scans a basic row (no joins) into a Visit struct.
func scanVisitRow(row pgx.Row) (*models.Visit, error) {
	var v models.Visit
	var plannedArrival *string

	err := row.Scan(
		&v.ID, &v.RouteID, &v.WaypointID, &v.PelangganID, &v.OrderID,
		&v.VisitOrder, &plannedArrival, &v.ActualArrival, &v.ActualDeparture,
		&v.ItemsSold, &v.Amount, &v.PaymentMethod, &v.PaymentStatus,
		&v.Notes, &v.Status, &v.CreatedAt, &v.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	v.PlannedArrival = plannedArrival
	return &v, nil
}

// Create inserts a new visit record.
func (r *visitRepo) Create(ctx context.Context, visit *models.Visit) error {
	query := `
		INSERT INTO visits (route_id, waypoint_id, pelanggan_id, order_id,
			visit_order, planned_arrival, items_sold, amount,
			payment_method, payment_status, notes, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at`

	err := r.pool.QueryRow(ctx, query,
		visit.RouteID,
		visit.WaypointID,
		visit.PelangganID,
		visit.OrderID,
		visit.VisitOrder,
		visit.PlannedArrival,
		visit.ItemsSold,
		visit.Amount,
		visit.PaymentMethod,
		visit.PaymentStatus,
		visit.Notes,
		visit.Status,
	).Scan(&visit.ID, &visit.CreatedAt, &visit.UpdatedAt)

	if err != nil {
		return fmt.Errorf("insert visit: %w", err)
	}
	return nil
}

// CreateBatch inserts multiple visits in a single transaction.
func (r *visitRepo) CreateBatch(ctx context.Context, visits []models.Visit) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO visits (route_id, waypoint_id, pelanggan_id, order_id,
			visit_order, planned_arrival, items_sold, amount,
			payment_method, payment_status, notes, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at`

	for i := range visits {
		err := tx.QueryRow(ctx, query,
			visits[i].RouteID,
			visits[i].WaypointID,
			visits[i].PelangganID,
			visits[i].OrderID,
			visits[i].VisitOrder,
			visits[i].PlannedArrival,
			visits[i].ItemsSold,
			visits[i].Amount,
			visits[i].PaymentMethod,
			visits[i].PaymentStatus,
			visits[i].Notes,
			visits[i].Status,
		).Scan(&visits[i].ID, &visits[i].CreatedAt, &visits[i].UpdatedAt)

		if err != nil {
			return fmt.Errorf("insert visit %d: %w", i, err)
		}
	}

	return tx.Commit(ctx)
}

// GetByID fetches a visit by UUID with joined waypoint label and pelanggan name.
func (r *visitRepo) GetByID(ctx context.Context, id string) (*models.Visit, error) {
	query := `
		SELECT ` + visitJoinColumns + `
		FROM visits v
		LEFT JOIN waypoints w ON w.id = v.waypoint_id
		LEFT JOIN users u ON u.id = v.pelanggan_id
		WHERE v.id = $1`

	visit, err := scanVisit(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrVisitNotFound
		}
		return nil, fmt.Errorf("get visit by id: %w", err)
	}
	return visit, nil
}

// ListByRoute returns all visits for a route ordered by visit_order.
func (r *visitRepo) ListByRoute(ctx context.Context, routeID string) ([]models.Visit, error) {
	query := `
		SELECT ` + visitJoinColumns + `
		FROM visits v
		LEFT JOIN waypoints w ON w.id = v.waypoint_id
		LEFT JOIN users u ON u.id = v.pelanggan_id
		WHERE v.route_id = $1
		ORDER BY v.visit_order ASC`

	rows, err := r.pool.Query(ctx, query, routeID)
	if err != nil {
		return nil, fmt.Errorf("list visits by route: %w", err)
	}
	defer rows.Close()

	var visits []models.Visit
	for rows.Next() {
		var v models.Visit
		var plannedArrival *string

		if err := rows.Scan(
			&v.ID, &v.RouteID, &v.WaypointID, &v.PelangganID, &v.OrderID,
			&v.VisitOrder, &plannedArrival, &v.ActualArrival, &v.ActualDeparture,
			&v.ItemsSold, &v.Amount, &v.PaymentMethod, &v.PaymentStatus,
			&v.Notes, &v.Status, &v.CreatedAt, &v.UpdatedAt,
			&v.WaypointLabel, &v.PelangganName, &v.DurationMin,
		); err != nil {
			return nil, fmt.Errorf("scan visit row: %w", err)
		}

		v.PlannedArrival = plannedArrival
		visits = append(visits, v)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate visits: %w", err)
	}

	return visits, nil
}

// Update persists changes to a visit.
func (r *visitRepo) Update(ctx context.Context, visit *models.Visit) error {
	query := `
		UPDATE visits
		SET items_sold = $2, amount = $3, payment_method = $4, payment_status = $5,
		    notes = $6, status = $7, updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at`

	err := r.pool.QueryRow(ctx, query,
		visit.ID,
		visit.ItemsSold,
		visit.Amount,
		visit.PaymentMethod,
		visit.PaymentStatus,
		visit.Notes,
		visit.Status,
	).Scan(&visit.UpdatedAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrVisitNotFound
		}
		return fmt.Errorf("update visit: %w", err)
	}
	return nil
}

// UpdateStatus updates only the status field of a visit.
func (r *visitRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	query := `
		UPDATE visits
		SET status = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, status).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrVisitNotFound
		}
		return fmt.Errorf("update visit status: %w", err)
	}
	return nil
}

// MarkArrived records the vendor's arrival at a customer location.
func (r *visitRepo) MarkArrived(ctx context.Context, id string) error {
	query := `
		UPDATE visits
		SET status = 'arrived', actual_arrival = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'pending'
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrVisitNotFound
		}
		return fmt.Errorf("mark visit arrived: %w", err)
	}
	return nil
}

// MarkCompleted records a completed visit with items sold and payment info.
func (r *visitRepo) MarkCompleted(ctx context.Context, id string, items json.RawMessage, amount float64, paymentMethod string) error {
	query := `
		UPDATE visits
		SET status = 'completed',
		    actual_departure = NOW(),
		    items_sold = $2,
		    amount = $3,
		    payment_method = $4,
		    payment_status = CASE WHEN $4 = 'cash' THEN 'paid' ELSE 'pending' END,
		    updated_at = NOW()
		WHERE id = $1 AND status IN ('pending', 'arrived')
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, items, amount, paymentMethod).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrVisitNotFound
		}
		return fmt.Errorf("mark visit completed: %w", err)
	}
	return nil
}

// MarkSkipped marks a visit as skipped with a reason stored in notes.
func (r *visitRepo) MarkSkipped(ctx context.Context, id string, reason string) error {
	query := `
		UPDATE visits
		SET status = 'skipped',
		    notes = CASE WHEN notes IS NULL OR notes = '' THEN $2 ELSE notes || E'\n' || $2 END,
		    updated_at = NOW()
		WHERE id = $1 AND status = 'pending'
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, "SKIPPED: "+reason).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrVisitNotFound
		}
		return fmt.Errorf("mark visit skipped: %w", err)
	}
	return nil
}

// GetVisitHistory returns the most recent visits for a pelanggan.
func (r *visitRepo) GetVisitHistory(ctx context.Context, pelangganID string, limit int) ([]models.Visit, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `
		SELECT ` + visitJoinColumns + `
		FROM visits v
		LEFT JOIN waypoints w ON w.id = v.waypoint_id
		LEFT JOIN users u ON u.id = v.pelanggan_id
		WHERE v.pelanggan_id = $1
		ORDER BY v.created_at DESC
		LIMIT $2`

	rows, err := r.pool.Query(ctx, query, pelangganID, limit)
	if err != nil {
		return nil, fmt.Errorf("get visit history: %w", err)
	}
	defer rows.Close()

	var visits []models.Visit
	for rows.Next() {
		var v models.Visit
		var plannedArrival *string

		if err := rows.Scan(
			&v.ID, &v.RouteID, &v.WaypointID, &v.PelangganID, &v.OrderID,
			&v.VisitOrder, &plannedArrival, &v.ActualArrival, &v.ActualDeparture,
			&v.ItemsSold, &v.Amount, &v.PaymentMethod, &v.PaymentStatus,
			&v.Notes, &v.Status, &v.CreatedAt, &v.UpdatedAt,
			&v.WaypointLabel, &v.PelangganName, &v.DurationMin,
		); err != nil {
			return nil, fmt.Errorf("scan visit history row: %w", err)
		}

		v.PlannedArrival = plannedArrival
		visits = append(visits, v)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate visit history: %w", err)
	}

	return visits, nil
}

// GetStatsByPedagang returns aggregated visit statistics for a pedagang within a date range.
func (r *visitRepo) GetStatsByPedagang(ctx context.Context, pedagangID string, from, to string) (*VisitStats, error) {
	// Aggregate stats
	statsQuery := `
		SELECT
			COUNT(*) AS total_visits,
			COUNT(*) FILTER (WHERE v.status = 'completed') AS completed,
			COUNT(*) FILTER (WHERE v.status = 'skipped') AS skipped,
			COALESCE(SUM(v.amount) FILTER (WHERE v.status = 'completed'), 0) AS total_revenue,
			COALESCE(AVG(
				EXTRACT(EPOCH FROM (v.actual_departure - v.actual_arrival)) / 60
			) FILTER (WHERE v.actual_arrival IS NOT NULL AND v.actual_departure IS NOT NULL), 0) AS avg_duration
		FROM visits v
		JOIN routes r ON r.id = v.route_id
		WHERE r.pedagang_id = $1
		  AND r.date >= $2::date
		  AND r.date <= $3::date`

	var stats VisitStats
	err := r.pool.QueryRow(ctx, statsQuery, pedagangID, from, to).Scan(
		&stats.TotalVisits,
		&stats.Completed,
		&stats.Skipped,
		&stats.TotalRevenue,
		&stats.AvgDuration,
	)
	if err != nil {
		return nil, fmt.Errorf("get visit stats: %w", err)
	}

	// Top customers
	customerQuery := `
		SELECT
			v.pelanggan_id,
			COALESCE(u.name, '') AS pelanggan_name,
			COUNT(*) AS visit_count,
			COALESCE(SUM(v.amount) FILTER (WHERE v.status = 'completed'), 0) AS total_revenue
		FROM visits v
		JOIN routes r ON r.id = v.route_id
		LEFT JOIN users u ON u.id = v.pelanggan_id
		WHERE r.pedagang_id = $1
		  AND r.date >= $2::date
		  AND r.date <= $3::date
		  AND v.pelanggan_id IS NOT NULL
		GROUP BY v.pelanggan_id, u.name
		ORDER BY total_revenue DESC
		LIMIT 10`

	rows, err := r.pool.Query(ctx, customerQuery, pedagangID, from, to)
	if err != nil {
		return nil, fmt.Errorf("get top customers: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var cs CustomerStat
		if err := rows.Scan(&cs.PelangganID, &cs.PelangganName, &cs.VisitCount, &cs.TotalRevenue); err != nil {
			return nil, fmt.Errorf("scan customer stat: %w", err)
		}
		stats.TopCustomers = append(stats.TopCustomers, cs)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate top customers: %w", err)
	}

	return &stats, nil
}
