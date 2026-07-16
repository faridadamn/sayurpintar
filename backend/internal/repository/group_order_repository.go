package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// GroupOrderRepository defines the data access contract for group orders.
type GroupOrderRepository interface {
	CreateGroup(ctx context.Context, group *models.GroupOrder) error
	GetGroupByID(ctx context.Context, id string) (*models.GroupOrder, error)
	ListOpenGroups(ctx context.Context, area string) ([]models.GroupOrder, error)
	ListByOrganizer(ctx context.Context, organizerID string) ([]models.GroupOrder, error)
	UpdateGroupStatus(ctx context.Context, id string, status string) error
	UpdateCurrentQty(ctx context.Context, id string) error

	JoinGroup(ctx context.Context, participant *models.GroupParticipant) error
	LeaveGroup(ctx context.Context, groupID, pedagangID string) error
	ListParticipants(ctx context.Context, groupID string) ([]models.GroupParticipant, error)
	GetParticipant(ctx context.Context, groupID, pedagangID string) (*models.GroupParticipant, error)

	CreateSupplier(ctx context.Context, supplier *models.Supplier) error
	ListSuppliers(ctx context.Context) ([]models.Supplier, error)
	RateSupplier(ctx context.Context, supplierID string, rating float64) error
	GetSupplierByID(ctx context.Context, id string) (*models.Supplier, error)
}

// groupOrderRepo implements GroupOrderRepository backed by pgxpool.
type groupOrderRepo struct {
	pool *pgxpool.Pool
}

// NewGroupOrderRepository returns a new GroupOrderRepository.
func NewGroupOrderRepository(pool *pgxpool.Pool) GroupOrderRepository {
	return &groupOrderRepo{pool: pool}
}

const groupOrderColumns = `
	id, organizer_id, supplier_id, product_id, product_name,
	target_qty, current_qty, group_price, regular_price, unit,
	deadline, delivery_date, delivery_point, status, created_at, updated_at
`

const participantColumns = `
	id, group_order_id, pedagang_id, qty, total_price, status, joined_at
`

const supplierColumns = `
	id, name, address, phone, location, rating, is_active, created_at
`

func scanGroupOrder(row pgx.Row) (*models.GroupOrder, error) {
	var g models.GroupOrder
	err := row.Scan(
		&g.ID, &g.OrganizerID, &g.SupplierID, &g.ProductID, &g.ProductName,
		&g.TargetQty, &g.CurrentQty, &g.GroupPrice, &g.RegularPrice, &g.Unit,
		&g.Deadline, &g.DeliveryDate, &g.DeliveryPoint, &g.Status,
		&g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &g, nil
}

func scanParticipant(row pgx.Row) (*models.GroupParticipant, error) {
	var p models.GroupParticipant
	err := row.Scan(
		&p.ID, &p.GroupOrderID, &p.PedagangID, &p.Qty, &p.TotalPrice,
		&p.Status, &p.JoinedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func scanSupplier(row pgx.Row) (*models.Supplier, error) {
	var s models.Supplier
	var locationWKT *string
	err := row.Scan(
		&s.ID, &s.Name, &s.Address, &s.Phone, &locationWKT,
		&s.Rating, &s.IsActive, &s.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	if locationWKT != nil {
		pt, scanErr := models.ScanPoint(*locationWKT)
		if scanErr != nil {
			return nil, fmt.Errorf("scan supplier location: %w", scanErr)
		}
		s.Location = pt
	}
	return &s, nil
}

// CreateGroup inserts a new group order.
func (r *groupOrderRepo) CreateGroup(ctx context.Context, group *models.GroupOrder) error {
	query := `
		INSERT INTO group_orders (
			organizer_id, supplier_id, product_id, product_name,
			target_qty, group_price, regular_price, unit,
			deadline, delivery_date, delivery_point, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING ` + groupOrderColumns

	row := r.pool.QueryRow(ctx, query,
		group.OrganizerID, group.SupplierID, group.ProductID, group.ProductName,
		group.TargetQty, group.GroupPrice, group.RegularPrice, group.Unit,
		group.Deadline, group.DeliveryDate, group.DeliveryPoint, models.GroupStatusOpen,
	)

	created, err := scanGroupOrder(row)
	if err != nil {
		return fmt.Errorf("insert group order: %w", err)
	}
	*group = *created
	return nil
}

// GetGroupByID fetches a group order by ID with computed fields.
func (r *groupOrderRepo) GetGroupByID(ctx context.Context, id string) (*models.GroupOrder, error) {
	query := `
		SELECT ` + groupOrderColumns + `,
			u.name AS organizer_name,
			(SELECT COUNT(*) FROM group_participants gp WHERE gp.group_order_id = go.id AND gp.status != 'cancelled') AS participant_count
		FROM group_orders go
		LEFT JOIN users u ON u.id = go.organizer_id
		WHERE go.id = $1`

	var g models.GroupOrder
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&g.ID, &g.OrganizerID, &g.SupplierID, &g.ProductID, &g.ProductName,
		&g.TargetQty, &g.CurrentQty, &g.GroupPrice, &g.RegularPrice, &g.Unit,
		&g.Deadline, &g.DeliveryDate, &g.DeliveryPoint, &g.Status,
		&g.CreatedAt, &g.UpdatedAt,
		&g.OrganizerName, &g.ParticipantCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrGroupOrderNotFound
		}
		return nil, fmt.Errorf("get group order: %w", err)
	}

	g.Savings = g.RegularPrice - g.GroupPrice
	return &g, nil
}

// ListOpenGroups returns open group orders, optionally filtered by area.
func (r *groupOrderRepo) ListOpenGroups(ctx context.Context, area string) ([]models.GroupOrder, error) {
	query := `
		SELECT ` + groupOrderColumns + `,
			u.name AS organizer_name,
			(SELECT COUNT(*) FROM group_participants gp WHERE gp.group_order_id = go.id AND gp.status != 'cancelled') AS participant_count
		FROM group_orders go
		LEFT JOIN users u ON u.id = go.organizer_id
		WHERE go.status = 'open' AND go.deadline > NOW()`

	args := []interface{}{}
	if area != "" {
		query += ` AND go.delivery_point ILIKE '%' || $1 || '%'`
		args = append(args, area)
	}
	query += ` ORDER BY go.deadline ASC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list open groups: %w", err)
	}
	defer rows.Close()

	groups := make([]models.GroupOrder, 0)
	for rows.Next() {
		var g models.GroupOrder
		if err := rows.Scan(
			&g.ID, &g.OrganizerID, &g.SupplierID, &g.ProductID, &g.ProductName,
			&g.TargetQty, &g.CurrentQty, &g.GroupPrice, &g.RegularPrice, &g.Unit,
			&g.Deadline, &g.DeliveryDate, &g.DeliveryPoint, &g.Status,
			&g.CreatedAt, &g.UpdatedAt,
			&g.OrganizerName, &g.ParticipantCount,
		); err != nil {
			return nil, fmt.Errorf("scan group order: %w", err)
		}
		g.Savings = g.RegularPrice - g.GroupPrice
		groups = append(groups, g)
	}
	return groups, nil
}

// ListByOrganizer returns all group orders created by a specific organizer.
func (r *groupOrderRepo) ListByOrganizer(ctx context.Context, organizerID string) ([]models.GroupOrder, error) {
	query := `
		SELECT ` + groupOrderColumns + `,
			u.name AS organizer_name,
			(SELECT COUNT(*) FROM group_participants gp WHERE gp.group_order_id = go.id AND gp.status != 'cancelled') AS participant_count
		FROM group_orders go
		LEFT JOIN users u ON u.id = go.organizer_id
		WHERE go.organizer_id = $1
		ORDER BY go.created_at DESC`

	rows, err := r.pool.Query(ctx, query, organizerID)
	if err != nil {
		return nil, fmt.Errorf("list by organizer: %w", err)
	}
	defer rows.Close()

	groups := make([]models.GroupOrder, 0)
	for rows.Next() {
		var g models.GroupOrder
		if err := rows.Scan(
			&g.ID, &g.OrganizerID, &g.SupplierID, &g.ProductID, &g.ProductName,
			&g.TargetQty, &g.CurrentQty, &g.GroupPrice, &g.RegularPrice, &g.Unit,
			&g.Deadline, &g.DeliveryDate, &g.DeliveryPoint, &g.Status,
			&g.CreatedAt, &g.UpdatedAt,
			&g.OrganizerName, &g.ParticipantCount,
		); err != nil {
			return nil, fmt.Errorf("scan group order: %w", err)
		}
		g.Savings = g.RegularPrice - g.GroupPrice
		groups = append(groups, g)
	}
	return groups, nil
}

// UpdateGroupStatus sets the status of a group order.
func (r *groupOrderRepo) UpdateGroupStatus(ctx context.Context, id string, status string) error {
	query := `
		UPDATE group_orders
		SET status = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, status).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrGroupOrderNotFound
		}
		return fmt.Errorf("update group status: %w", err)
	}
	return nil
}

// UpdateCurrentQty recalculates and sets current_qty from active participants.
func (r *groupOrderRepo) UpdateCurrentQty(ctx context.Context, id string) error {
	query := `
		UPDATE group_orders
		SET current_qty = COALESCE((
			SELECT SUM(qty) FROM group_participants
			WHERE group_order_id = $1 AND status != 'cancelled'
		), 0),
		updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrGroupOrderNotFound
		}
		return fmt.Errorf("update current qty: %w", err)
	}
	return nil
}

// JoinGroup adds a participant to a group order.
func (r *groupOrderRepo) JoinGroup(ctx context.Context, participant *models.GroupParticipant) error {
	query := `
		INSERT INTO group_participants (group_order_id, pedagang_id, qty, total_price, status)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, joined_at`

	err := r.pool.QueryRow(ctx, query,
		participant.GroupOrderID, participant.PedagangID,
		participant.Qty, participant.TotalPrice, models.ParticipantJoined,
	).Scan(&participant.ID, &participant.JoinedAt)
	if err != nil {
		return fmt.Errorf("insert participant: %w", err)
	}
	return nil
}

// LeaveGroup removes (cancels) a participant from a group order.
func (r *groupOrderRepo) LeaveGroup(ctx context.Context, groupID, pedagangID string) error {
	query := `
		UPDATE group_participants
		SET status = 'cancelled'
		WHERE group_order_id = $1 AND pedagang_id = $2 AND status = 'joined'
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, groupID, pedagangID).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrParticipantNotFound
		}
		return fmt.Errorf("leave group: %w", err)
	}
	return nil
}

// ListParticipants returns all active participants in a group order.
func (r *groupOrderRepo) ListParticipants(ctx context.Context, groupID string) ([]models.GroupParticipant, error) {
	query := `
		SELECT ` + participantColumns + `, u.name AS pedagang_name
		FROM group_participants gp
		LEFT JOIN users u ON u.id = gp.pedagang_id
		WHERE gp.group_order_id = $1 AND gp.status != 'cancelled'
		ORDER BY gp.joined_at ASC`

	rows, err := r.pool.Query(ctx, query, groupID)
	if err != nil {
		return nil, fmt.Errorf("list participants: %w", err)
	}
	defer rows.Close()

	participants := make([]models.GroupParticipant, 0)
	for rows.Next() {
		var p models.GroupParticipant
		if err := rows.Scan(
			&p.ID, &p.GroupOrderID, &p.PedagangID, &p.Qty, &p.TotalPrice,
			&p.Status, &p.JoinedAt, &p.PedagangName,
		); err != nil {
			return nil, fmt.Errorf("scan participant: %w", err)
		}
		participants = append(participants, p)
	}
	return participants, nil
}

// GetParticipant returns a specific participant in a group order.
func (r *groupOrderRepo) GetParticipant(ctx context.Context, groupID, pedagangID string) (*models.GroupParticipant, error) {
	query := `
		SELECT ` + participantColumns + `
		FROM group_participants
		WHERE group_order_id = $1 AND pedagang_id = $2 AND status != 'cancelled'`

	p, err := scanParticipant(r.pool.QueryRow(ctx, query, groupID, pedagangID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrParticipantNotFound
		}
		return nil, fmt.Errorf("get participant: %w", err)
	}
	return p, nil
}

// CreateSupplier inserts a new supplier.
func (r *groupOrderRepo) CreateSupplier(ctx context.Context, supplier *models.Supplier) error {
	query := `
		INSERT INTO suppliers (name, address, phone, location)
		VALUES ($1, $2, $3,`

	var locationArg interface{}
	if supplier.Location != nil {
		wkt := fmt.Sprintf("SRID=4326;POINT(%f %f)", supplier.Location.Longitude, supplier.Location.Latitude)
		locationArg = wkt
		query += ` ST_GeographyFromText($4))`
	} else {
		query += ` NULL)`
	}

	query += ` RETURNING ` + supplierColumns

	var row pgx.Row
	if supplier.Location != nil {
		row = r.pool.QueryRow(ctx, query, supplier.Name, supplier.Address, supplier.Phone, locationArg)
	} else {
		row = r.pool.QueryRow(ctx,
			`INSERT INTO suppliers (name, address, phone, location)
			VALUES ($1, $2, $3, NULL)
			RETURNING `+supplierColumns,
			supplier.Name, supplier.Address, supplier.Phone,
		)
	}

	created, err := scanSupplier(row)
	if err != nil {
		return fmt.Errorf("insert supplier: %w", err)
	}
	*supplier = *created
	return nil
}

// ListSuppliers returns all active suppliers.
func (r *groupOrderRepo) ListSuppliers(ctx context.Context) ([]models.Supplier, error) {
	query := `SELECT ` + supplierColumns + ` FROM suppliers WHERE is_active = TRUE ORDER BY rating DESC, name ASC`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("list suppliers: %w", err)
	}
	defer rows.Close()

	suppliers := make([]models.Supplier, 0)
	for rows.Next() {
		s, err := scanSupplier(rows)
		if err != nil {
			return nil, fmt.Errorf("scan supplier: %w", err)
		}
		suppliers = append(suppliers, *s)
	}
	return suppliers, nil
}

// RateSupplier updates the rating of a supplier (simple average recalculation placeholder).
func (r *groupOrderRepo) RateSupplier(ctx context.Context, supplierID string, rating float64) error {
	// Simple approach: update the rating directly. In production, this would
	// maintain a ratings table and compute averages.
	query := `
		UPDATE suppliers
		SET rating = ((rating + $2) / 2.0)
		WHERE id = $1
		RETURNING id`

	var id string
	err := r.pool.QueryRow(ctx, query, supplierID, rating).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrSupplierNotFound
		}
		return fmt.Errorf("rate supplier: %w", err)
	}
	return nil
}

// GetSupplierByID fetches a supplier by ID.
func (r *groupOrderRepo) GetSupplierByID(ctx context.Context, id string) (*models.Supplier, error) {
	query := `SELECT ` + supplierColumns + ` FROM suppliers WHERE id = $1`

	s, err := scanSupplier(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSupplierNotFound
		}
		return nil, fmt.Errorf("get supplier: %w", err)
	}
	return s, nil
}
