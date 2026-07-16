package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

// seedProduct is the JSON representation in products.json.
type seedProduct struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Category    string `json:"category"`
	DefaultUnit string `json:"default_unit"`
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Read products.json
	data, err := os.ReadFile("products.json")
	if err != nil {
		log.Fatalf("Failed to read products.json: %v", err)
	}

	var seeds []seedProduct
	if err := json.Unmarshal(data, &seeds); err != nil {
		log.Fatalf("Failed to parse products.json: %v", err)
	}

	if len(seeds) == 0 {
		log.Fatal("No products found in products.json")
	}

	// Connect to PostgreSQL
	pgURL := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		getEnv("POSTGRES_USER", "sp_dev"),
		getEnv("POSTGRES_PASSWORD", "sp_dev_password"),
		getEnv("POSTGRES_HOST", "localhost"),
		getEnv("POSTGRES_PORT", "5432"),
		getEnv("POSTGRES_DB", "sayurpintar"),
	)

	pool, err := pgxpool.New(ctx, pgURL)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Failed to ping PostgreSQL: %v", err)
	}

	// Convert seed products to model products with deterministic UUIDs
	products := make([]models.Product, 0, len(seeds))
	for _, s := range seeds {
		// Generate a deterministic UUID v5 from the seed ID
		id := uuid.NewSHA1(uuid.NameSpaceURL, []byte(s.ID))

		products = append(products, models.Product{
			ID:          id,
			Name:        s.Name,
			Category:    s.Category,
			DefaultUnit: s.DefaultUnit,
			IsActive:    true,
		})
	}

	// Bulk upsert using INSERT ... ON CONFLICT
	query := `
		INSERT INTO products (id, name, category, default_unit, is_active)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			category = EXCLUDED.category,
			default_unit = EXCLUDED.default_unit,
			is_active = EXCLUDED.is_active,
			updated_at = NOW()`

	tx, err := pool.Begin(ctx)
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}
	defer tx.Rollback(ctx)

	for _, p := range products {
		if _, err := tx.Exec(ctx, query, p.ID, p.Name, p.Category, p.DefaultUnit, p.IsActive); err != nil {
			log.Fatalf("Failed to upsert product %s (%s): %v", p.Name, p.ID, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	log.Printf("Seeded %d products", len(products))
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
