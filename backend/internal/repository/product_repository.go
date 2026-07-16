package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// ErrProductNotFound is declared in errors.go

// ProductRepository defines the data access contract for products.
type ProductRepository interface {
	GetAll(ctx context.Context, activeOnly bool) ([]models.Product, error)
	GetByID(ctx context.Context, id string) (*models.Product, error)
	Search(ctx context.Context, query string) ([]models.Product, error)
	GetByCategory(ctx context.Context, category string) ([]models.Product, error)
	Create(ctx context.Context, product *models.Product) error
	Update(ctx context.Context, product *models.Product) error
	Delete(ctx context.Context, id string) error
	BulkCreate(ctx context.Context, products []models.Product) error
}

// productRepo implements ProductRepository backed by pgxpool.
type productRepo struct {
	pool *pgxpool.Pool
}

// NewProductRepository returns a new ProductRepository backed by the given pool.
func NewProductRepository(pool *pgxpool.Pool) ProductRepository {
	return &productRepo{pool: pool}
}

const productColumns = `
	id, name, category, default_unit, image_url, is_active, created_at, updated_at
`

// scanProduct scans a single row into a Product struct.
func scanProduct(row pgx.Row) (*models.Product, error) {
	var p models.Product
	err := row.Scan(
		&p.ID,
		&p.Name,
		&p.Category,
		&p.DefaultUnit,
		&p.ImageURL,
		&p.IsActive,
		&p.CreatedAt,
		&p.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// GetAll returns all products. When activeOnly is true only active products are returned.
func (r *productRepo) GetAll(ctx context.Context, activeOnly bool) ([]models.Product, error) {
	query := `SELECT ` + productColumns + ` FROM products`
	if activeOnly {
		query += ` WHERE is_active = TRUE`
	}
	query += ` ORDER BY name ASC`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query products: %w", err)
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var p models.Product
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Category, &p.DefaultUnit,
			&p.ImageURL, &p.IsActive, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan product: %w", err)
		}
		products = append(products, p)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate products: %w", err)
	}
	if products == nil {
		products = []models.Product{}
	}
	return products, nil
}

// GetByID returns a single product by UUID.
func (r *productRepo) GetByID(ctx context.Context, id string) (*models.Product, error) {
	query := `SELECT ` + productColumns + ` FROM products WHERE id = $1`

	p, err := scanProduct(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrProductNotFound
		}
		return nil, fmt.Errorf("get product by id: %w", err)
	}
	return p, nil
}

// Search returns products whose name matches the query (case-insensitive substring).
func (r *productRepo) Search(ctx context.Context, query string) ([]models.Product, error) {
	sqlQuery := `SELECT ` + productColumns + ` FROM products
		WHERE is_active = TRUE AND name ILIKE $1
		ORDER BY name ASC`

	rows, err := r.pool.Query(ctx, sqlQuery, "%"+query+"%")
	if err != nil {
		return nil, fmt.Errorf("search products: %w", err)
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var p models.Product
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Category, &p.DefaultUnit,
			&p.ImageURL, &p.IsActive, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan product: %w", err)
		}
		products = append(products, p)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate search results: %w", err)
	}
	if products == nil {
		products = []models.Product{}
	}
	return products, nil
}

// GetByCategory returns active products in the given category.
func (r *productRepo) GetByCategory(ctx context.Context, category string) ([]models.Product, error) {
	query := `SELECT ` + productColumns + ` FROM products
		WHERE category = $1 AND is_active = TRUE
		ORDER BY name ASC`

	rows, err := r.pool.Query(ctx, query, category)
	if err != nil {
		return nil, fmt.Errorf("query products by category: %w", err)
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var p models.Product
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Category, &p.DefaultUnit,
			&p.ImageURL, &p.IsActive, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan product: %w", err)
		}
		products = append(products, p)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate products: %w", err)
	}
	if products == nil {
		products = []models.Product{}
	}
	return products, nil
}

// Create inserts a new product. The product struct is re-scanned after insert
// to capture DB-generated fields (id, created_at, updated_at).
func (r *productRepo) Create(ctx context.Context, product *models.Product) error {
	query := `
		INSERT INTO products (name, category, default_unit, image_url)
		VALUES ($1, $2, $3, $4)
		RETURNING ` + productColumns

	p, err := scanProduct(r.pool.QueryRow(ctx, query,
		product.Name,
		product.Category,
		product.DefaultUnit,
		product.ImageURL,
	))
	if err != nil {
		return fmt.Errorf("insert product: %w", err)
	}
	*product = *p
	return nil
}

// Update persists changes to mutable product fields.
func (r *productRepo) Update(ctx context.Context, product *models.Product) error {
	query := `
		UPDATE products
		SET name = $2, category = $3, default_unit = $4, image_url = $5,
		    is_active = $6, updated_at = NOW()
		WHERE id = $1
		RETURNING ` + productColumns

	p, err := scanProduct(r.pool.QueryRow(ctx, query,
		product.ID,
		product.Name,
		product.Category,
		product.DefaultUnit,
		product.ImageURL,
		product.IsActive,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrProductNotFound
		}
		return fmt.Errorf("update product: %w", err)
	}
	*product = *p
	return nil
}

// Delete removes a product by ID.
func (r *productRepo) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM products WHERE id = $1 RETURNING id`

	var deletedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&deletedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrProductNotFound
		}
		return fmt.Errorf("delete product: %w", err)
	}
	return nil
}

// BulkCreate upserts a slice of products in a single transaction.
// Uses INSERT … ON CONFLICT (id) DO UPDATE so re-running is idempotent.
func (r *productRepo) BulkCreate(ctx context.Context, products []models.Product) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	query := `
		INSERT INTO products (id, name, category, default_unit, image_url, is_active)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			category = EXCLUDED.category,
			default_unit = EXCLUDED.default_unit,
			image_url = EXCLUDED.image_url,
			is_active = EXCLUDED.is_active,
			updated_at = NOW()`

	for _, p := range products {
		if _, err := tx.Exec(ctx, query,
			p.ID, p.Name, p.Category, p.DefaultUnit, p.ImageURL, p.IsActive,
		); err != nil {
			return fmt.Errorf("upsert product %s: %w", p.ID, err)
		}
	}

	return tx.Commit(ctx)
}
