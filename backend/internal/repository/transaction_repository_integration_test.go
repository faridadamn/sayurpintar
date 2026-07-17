package repository

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

func TestTransactionRepositoryIntegration(t *testing.T) {
	host := os.Getenv("POSTGRES_HOST")
	if host == "" {
		t.Skip("POSTGRES_HOST is not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	port := envOrDefault("POSTGRES_PORT", "5432")
	dbName := envOrDefault("POSTGRES_DB", "sayurpintar_test")
	user := envOrDefault("POSTGRES_USER", "sp_test")
	password := envOrDefault("POSTGRES_PASSWORD", "test_password")

	dsn := (&url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, password),
		Host:   fmt.Sprintf("%s:%s", host, port),
		Path:   dbName,
		RawQuery: url.Values{
			"sslmode": []string{"disable"},
		}.Encode(),
	}).String()

	adminPool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect admin pool: %v", err)
	}
	defer adminPool.Close()

	schema := "transaction_test_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := adminPool.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatalf("create test schema: %v", err)
	}
	defer func() {
		_, _ = adminPool.Exec(context.Background(), "DROP SCHEMA "+schema+" CASCADE")
	}()

	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		t.Fatalf("parse pool config: %v", err)
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = schema

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatalf("connect isolated pool: %v", err)
	}
	defer pool.Close()

	createTransactionTestSchema(t, ctx, pool)

	pedagangA := uuid.New()
	pedagangB := uuid.New()
	for _, id := range []uuid.UUID{pedagangA, pedagangB} {
		if _, err := pool.Exec(ctx, `INSERT INTO users (id) VALUES ($1)`, id); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}

	repo := NewTransactionRepository(pool)
	today := time.Now().UTC().Format("2006-01-02")

	saleA := &models.Transaction{
		PedagangID:    pedagangA,
		Type:          models.TxnTypeSale,
		Amount:        150000,
		PaymentMethod: models.PayMethodCash,
		Status:        models.TxnStatusCompleted,
	}
	expenseA := &models.Transaction{
		PedagangID:    pedagangA,
		Type:          models.TxnTypeExpense,
		Amount:        40000,
		PaymentMethod: models.PayMethodTransfer,
		Status:        models.TxnStatusCompleted,
	}
	saleB := &models.Transaction{
		PedagangID:    pedagangB,
		Type:          models.TxnTypeSale,
		Amount:        999000,
		PaymentMethod: models.PayMethodQRIS,
		Status:        models.TxnStatusCompleted,
	}

	for _, txn := range []*models.Transaction{saleA, expenseA, saleB} {
		if err := repo.Create(ctx, txn); err != nil {
			t.Fatalf("create transaction: %v", err)
		}
		if txn.ID == uuid.Nil || txn.CreatedAt.IsZero() {
			t.Fatalf("generated fields were not populated: %+v", txn)
		}
	}

	fetched, err := repo.GetByID(ctx, saleA.ID.String())
	if err != nil {
		t.Fatalf("get transaction by id: %v", err)
	}
	if fetched.PedagangID != pedagangA || fetched.Amount != saleA.Amount {
		t.Fatalf("unexpected fetched transaction: %+v", fetched)
	}

	transactionsA, err := repo.ListByPedagang(ctx, pedagangA.String(), today, today)
	if err != nil {
		t.Fatalf("list pedagang A transactions: %v", err)
	}
	if len(transactionsA) != 2 {
		t.Fatalf("ownership filter returned %d transactions, want 2", len(transactionsA))
	}
	for _, txn := range transactionsA {
		if txn.PedagangID != pedagangA {
			t.Fatalf("ownership leak: got transaction for %s", txn.PedagangID)
		}
	}

	tomorrow := time.Now().UTC().AddDate(0, 0, 1).Format("2006-01-02")
	empty, err := repo.ListByPedagang(ctx, pedagangA.String(), tomorrow, tomorrow)
	if err != nil {
		t.Fatalf("list future transactions: %v", err)
	}
	if len(empty) != 0 {
		t.Fatalf("date filter returned %d transactions, want 0", len(empty))
	}

	revenue, err := repo.GetDailyTotal(ctx, pedagangA.String(), today)
	if err != nil {
		t.Fatalf("get daily revenue: %v", err)
	}
	if revenue != 150000 {
		t.Fatalf("daily revenue = %v, want 150000", revenue)
	}

	expense, err := repo.GetDailyExpenseTotal(ctx, pedagangA.String(), today)
	if err != nil {
		t.Fatalf("get daily expense: %v", err)
	}
	if expense != 40000 {
		t.Fatalf("daily expense = %v, want 40000", expense)
	}

	byMethod, err := repo.GetDailyByPaymentMethod(ctx, pedagangA.String(), today)
	if err != nil {
		t.Fatalf("get totals by payment method: %v", err)
	}
	if byMethod[string(models.PayMethodCash)] != 150000 {
		t.Fatalf("cash total = %v, want 150000", byMethod[string(models.PayMethodCash)])
	}
}

func createTransactionTestSchema(t *testing.T, ctx context.Context, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(ctx, `
		CREATE TABLE users (
			id uuid PRIMARY KEY
		);
		CREATE TABLE transactions (
			id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
			pedagang_id uuid NOT NULL REFERENCES users(id),
			pelanggan_id uuid REFERENCES users(id),
			order_id uuid,
			debt_id uuid,
			type varchar(20) NOT NULL,
			amount numeric(14,2) NOT NULL CHECK (amount > 0),
			payment_method varchar(20) NOT NULL,
			payment_gateway varchar(50),
			gateway_transaction_id varchar(150),
			gateway_status varchar(50),
			status varchar(20) NOT NULL,
			notes text,
			created_at timestamptz NOT NULL DEFAULT now(),
			updated_at timestamptz NOT NULL DEFAULT now()
		);
	`)
	if err != nil {
		t.Fatalf("create transaction test tables: %v", err)
	}
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
