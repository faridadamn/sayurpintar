package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// WaypointRepository defines the data access contract for waypoints.
type WaypointRepository interface {
	Create(ctx context.Context, wp *models.Waypoint) error
	GetByID(ctx context.Context, id string) (*models.Waypoint, error)
	ListByPedagang(ctx context.Context, pedagangID string, activeOnly bool) ([]models.Waypoint, error)
	Update(ctx context.Context, wp *models.Waypoint) error
	Delete(ctx context.Context, id string) error
	SetActive(ctx context.Context, id string, active bool) error
	// Spatial queries
	FindNearby(ctx context.Context, lat, lng float64, radiusKm float64, limit int) ([]models.Waypoint, error)
	GetByPelanggan(ctx context.Context, pelangganID string) ([]models.Waypoint, error)
	CountByPedagang(ctx context.Context, pedagangID string) (int, error)
}

// waypointRepo implements WaypointRepository backed by pgxpool.
type waypointRepo struct {
	pool *pgxpool.Pool
}

// NewWaypointRepository returns a new WaypointRepository.
func NewWaypointRepository(pool *pgxpool.Pool) WaypointRepository {
	return &waypointRepo{pool: pool}
}

// waypointColumns is the SELECT column list matching the waypoints table.
const waypointColumns = `
	w.id, w.pedagang_id, w.pelanggan_id, w.label, w.address,
	w.location, w.notes, w.priority, w.is_active,
	w.preferred_time_start, w.preferred_time_end,
	w.created_at, w.updated_at`

// waypointJoinColumns adds computed fields from LEFT JOINs.
const waypointJoinColumns = waypointColumns + `,
	COALESCE(u.name, '') AS pelanggan_name,
	0 AS visit_count,
	NULL::timestamptz AS last_visit_at,
	NULL::float8 AS distance_m`

// scanWaypoint scans a single row into a Waypoint struct.
func scanWaypoint(row pgx.Row) (*models.Waypoint, error) {
	var wp models.Waypoint
	var locationWKT *string

	err := row.Scan(
		&wp.ID,
		&wp.PedagangID,
		&wp.PelangganID,
		&wp.Label,
		&wp.Address,
		&locationWKT,
		&wp.Notes,
		&wp.Priority,
		&wp.IsActive,
		&wp.PreferredTimeStart,
		&wp.PreferredTimeEnd,
		&wp.CreatedAt,
		&wp.UpdatedAt,
		&wp.PelangganName,
		&wp.VisitCount,
		&wp.LastVisitAt,
		&wp.DistanceM,
	)
	if err != nil {
		return nil, err
	}

	if locationWKT != nil {
		pt, err := models.ScanPoint(*locationWKT)
		if err != nil {
			return nil, fmt.Errorf("scan waypoint location: %w", err)
		}
		wp.Location = *pt
	}

	return &wp, nil
}

// scanWaypointRow scans a basic row (no joins) into a Waypoint.
func scanWaypointRow(row pgx.Row) (*models.Waypoint, error) {
	var wp models.Waypoint
	var locationWKT *string

	err := row.Scan(
		&wp.ID,
		&wp.PedagangID,
		&wp.PelangganID,
		&wp.Label,
		&wp.Address,
		&locationWKT,
		&wp.Notes,
		&wp.Priority,
		&wp.IsActive,
		&wp.PreferredTimeStart,
		&wp.PreferredTimeEnd,
		&wp.CreatedAt,
		&wp.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if locationWKT != nil {
		pt, err := models.ScanPoint(*locationWKT)
		if err != nil {
			return nil, fmt.Errorf("scan waypoint location: %w", err)
		}
		wp.Location = *pt
	}

	return &wp, nil
}

// Create inserts a new waypoint and populates the struct with DB-generated fields.
func (r *waypointRepo) Create(ctx context.Context, wp *models.Waypoint) error {
	query := `
		INSERT INTO waypoints (pedagang_id, pelanggan_id, label, address, location, notes, priority, is_active, preferred_time_start, preferred_time_end)
		VALUES ($1, $2, $3, $4, ST_GeographyFromText($5), $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at`

	locationWKT := models.WaypointLocationWKT(wp.Location.Latitude, wp.Location.Longitude)

	err := r.pool.QueryRow(ctx, query,
		wp.PedagangID,
		wp.PelangganID,
		wp.Label,
		wp.Address,
		locationWKT,
		wp.Notes,
		wp.Priority,
		wp.IsActive,
		wp.PreferredTimeStart,
		wp.PreferredTimeEnd,
	).Scan(&wp.ID, &wp.CreatedAt, &wp.UpdatedAt)

	if err != nil {
		return fmt.Errorf("insert waypoint: %w", err)
	}
	return nil
}

// GetByID fetches a waypoint by its UUID, joining with users for pelanggan name.
func (r *waypointRepo) GetByID(ctx context.Context, id string) (*models.Waypoint, error) {
	query := `
		SELECT ` + waypointJoinColumns + `
		FROM waypoints w
		LEFT JOIN users u ON u.id = w.pelanggan_id
		WHERE w.id = $1`

	wp, err := scanWaypoint(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrWaypointNotFound
		}
		return nil, fmt.Errorf("get waypoint by id: %w", err)
	}
	return wp, nil
}

// ListByPedagang returns all waypoints for a pedagang, optionally filtering active only.
func (r *waypointRepo) ListByPedagang(ctx context.Context, pedagangID string, activeOnly bool) ([]models.Waypoint, error) {
	query := `
		SELECT ` + waypointJoinColumns + `
		FROM waypoints w
		LEFT JOIN users u ON u.id = w.pelanggan_id
		WHERE w.pedagang_id = $1`

	args := []interface{}{pedagangID}

	if activeOnly {
		query += ` AND w.is_active = TRUE`
	}

	query += ` ORDER BY w.priority DESC, w.created_at DESC`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list waypoints: %w", err)
	}
	defer rows.Close()

	var waypoints []models.Waypoint
	for rows.Next() {
		var wp models.Waypoint
		var locationWKT *string

		if err := rows.Scan(
			&wp.ID, &wp.PedagangID, &wp.PelangganID, &wp.Label, &wp.Address,
			&locationWKT, &wp.Notes, &wp.Priority, &wp.IsActive,
			&wp.PreferredTimeStart, &wp.PreferredTimeEnd,
			&wp.CreatedAt, &wp.UpdatedAt,
			&wp.PelangganName, &wp.VisitCount, &wp.LastVisitAt, &wp.DistanceM,
		); err != nil {
			return nil, fmt.Errorf("scan waypoint row: %w", err)
		}

		if locationWKT != nil {
			pt, err := models.ScanPoint(*locationWKT)
			if err != nil {
				return nil, fmt.Errorf("scan waypoint location: %w", err)
			}
			wp.Location = *pt
		}

		waypoints = append(waypoints, wp)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate waypoints: %w", err)
	}

	return waypoints, nil
}

// Update modifies an existing waypoint.
func (r *waypointRepo) Update(ctx context.Context, wp *models.Waypoint) error {
	query := `
		UPDATE waypoints
		SET label = $2, address = $3, location = ST_GeographyFromText($4),
		    notes = $5, priority = $6, is_active = $7,
		    preferred_time_start = $8, preferred_time_end = $9,
		    pelanggan_id = $10, updated_at = NOW()
		WHERE id = $1
		RETURNING updated_at`

	locationWKT := models.WaypointLocationWKT(wp.Location.Latitude, wp.Location.Longitude)

	err := r.pool.QueryRow(ctx, query,
		wp.ID,
		wp.Label,
		wp.Address,
		locationWKT,
		wp.Notes,
		wp.Priority,
		wp.IsActive,
		wp.PreferredTimeStart,
		wp.PreferredTimeEnd,
		wp.PelangganID,
	).Scan(&wp.UpdatedAt)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrWaypointNotFound
		}
		return fmt.Errorf("update waypoint: %w", err)
	}
	return nil
}

// Delete removes a waypoint by ID.
func (r *waypointRepo) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM waypoints WHERE id = $1 RETURNING id`

	var deletedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&deletedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrWaypointNotFound
		}
		return fmt.Errorf("delete waypoint: %w", err)
	}
	return nil
}

// SetActive toggles the is_active flag for a waypoint.
func (r *waypointRepo) SetActive(ctx context.Context, id string, active bool) error {
	query := `
		UPDATE waypoints
		SET is_active = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING id`

	var updatedID string
	err := r.pool.QueryRow(ctx, query, id, active).Scan(&updatedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrWaypointNotFound
		}
		return fmt.Errorf("set waypoint active: %w", err)
	}
	return nil
}

// FindNearby finds waypoints within radiusKm of the given coordinates using PostGIS.
// Returns results ordered by distance (nearest first) with distance_m populated.
func (r *waypointRepo) FindNearby(ctx context.Context, lat, lng float64, radiusKm float64, limit int) ([]models.Waypoint, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `
		SELECT ` + waypointColumns + `,
			COALESCE(u.name, '') AS pelanggan_name,
			0 AS visit_count,
			NULL::timestamptz AS last_visit_at,
			ST_Distance(w.location, ST_GeographyFromText($1)) AS distance_m
		FROM waypoints w
		LEFT JOIN users u ON u.id = w.pelanggan_id
		WHERE w.is_active = TRUE
		  AND ST_DWithin(w.location, ST_GeographyFromText($1), $2)
		ORDER BY distance_m ASC
		LIMIT $3`

	pointWKT := models.WaypointLocationWKT(lat, lng)
	radiusM := radiusKm * 1000.0

	rows, err := r.pool.Query(ctx, query, pointWKT, radiusM, limit)
	if err != nil {
		return nil, fmt.Errorf("find nearby waypoints: %w", err)
	}
	defer rows.Close()

	var waypoints []models.Waypoint
	for rows.Next() {
		var wp models.Waypoint
		var locationWKT *string

		if err := rows.Scan(
			&wp.ID, &wp.PedagangID, &wp.PelangganID, &wp.Label, &wp.Address,
			&locationWKT, &wp.Notes, &wp.Priority, &wp.IsActive,
			&wp.PreferredTimeStart, &wp.PreferredTimeEnd,
			&wp.CreatedAt, &wp.UpdatedAt,
			&wp.PelangganName, &wp.VisitCount, &wp.LastVisitAt, &wp.DistanceM,
		); err != nil {
			return nil, fmt.Errorf("scan nearby waypoint: %w", err)
		}

		if locationWKT != nil {
			pt, err := models.ScanPoint(*locationWKT)
			if err != nil {
				return nil, fmt.Errorf("scan nearby waypoint location: %w", err)
			}
			wp.Location = *pt
		}

		waypoints = append(waypoints, wp)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate nearby waypoints: %w", err)
	}

	return waypoints, nil
}

// GetByPelanggan returns all waypoints linked to a specific pelanggan.
func (r *waypointRepo) GetByPelanggan(ctx context.Context, pelangganID string) ([]models.Waypoint, error) {
	query := `
		SELECT ` + waypointJoinColumns + `
		FROM waypoints w
		LEFT JOIN users u ON u.id = w.pelanggan_id
		WHERE w.pelanggan_id = $1
		ORDER BY w.created_at DESC`

	rows, err := r.pool.Query(ctx, query, pelangganID)
	if err != nil {
		return nil, fmt.Errorf("get waypoints by pelanggan: %w", err)
	}
	defer rows.Close()

	var waypoints []models.Waypoint
	for rows.Next() {
		var wp models.Waypoint
		var locationWKT *string

		if err := rows.Scan(
			&wp.ID, &wp.PedagangID, &wp.PelangganID, &wp.Label, &wp.Address,
			&locationWKT, &wp.Notes, &wp.Priority, &wp.IsActive,
			&wp.PreferredTimeStart, &wp.PreferredTimeEnd,
			&wp.CreatedAt, &wp.UpdatedAt,
			&wp.PelangganName, &wp.VisitCount, &wp.LastVisitAt, &wp.DistanceM,
		); err != nil {
			return nil, fmt.Errorf("scan pelanggan waypoint: %w", err)
		}

		if locationWKT != nil {
			pt, err := models.ScanPoint(*locationWKT)
			if err != nil {
				return nil, fmt.Errorf("scan pelanggan waypoint location: %w", err)
			}
			wp.Location = *pt
		}

		waypoints = append(waypoints, wp)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate pelanggan waypoints: %w", err)
	}

	return waypoints, nil
}

// CountByPedagang returns the total number of waypoints for a pedagang.
func (r *waypointRepo) CountByPedagang(ctx context.Context, pedagangID string) (int, error) {
	query := `SELECT COUNT(*) FROM waypoints WHERE pedagang_id = $1`

	var count int
	if err := r.pool.QueryRow(ctx, query, pedagangID).Scan(&count); err != nil {
		return 0, fmt.Errorf("count waypoints: %w", err)
	}
	return count, nil
}
