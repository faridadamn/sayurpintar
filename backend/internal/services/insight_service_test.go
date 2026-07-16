package services

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// ── Mock Repositories ──────────────────────────────────────────────────────

type mockOrderRepo struct {
	orders map[string][]models.Order // date → orders
}

func (m *mockOrderRepo) Create(ctx context.Context, order *models.Order) error {
	return nil
}
func (m *mockOrderRepo) CreateBatch(ctx context.Context, orders []models.Order) error {
	return nil
}
func (m *mockOrderRepo) GetByID(ctx context.Context, id string) (*models.Order, error) {
	return nil, nil
}
func (m *mockOrderRepo) ListByPedagangAndDate(ctx context.Context, pedagangID string, date string) ([]models.Order, error) {
	if m.orders == nil {
		return []models.Order{}, nil
	}
	orders, ok := m.orders[date]
	if !ok {
		return []models.Order{}, nil
	}
	return orders, nil
}
func (m *mockOrderRepo) ListByPelanggan(ctx context.Context, pelangganID string, limit int) ([]models.Order, error) {
	return []models.Order{}, nil
}
func (m *mockOrderRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	return nil
}
func (m *mockOrderRepo) MarkDelivered(ctx context.Context, id string) error {
	return nil
}
func (m *mockOrderRepo) MarkCancelled(ctx context.Context, id string, reason string) error {
	return nil
}
func (m *mockOrderRepo) AddRating(ctx context.Context, id string, rating int, comment string) error {
	return nil
}
func (m *mockOrderRepo) UpdatePayment(ctx context.Context, id string, paymentStatus string, paymentMethod string) error {
	return nil
}
func (m *mockOrderRepo) GetTodayOrders(ctx context.Context, pedagangID string) ([]models.Order, error) {
	return []models.Order{}, nil
}
func (m *mockOrderRepo) GetOrderSummary(ctx context.Context, pedagangID string, date string) (*repository.OrderSummary, error) {
	return &repository.OrderSummary{}, nil
}
func (m *mockOrderRepo) ExistsForSubscriptionAndDate(ctx context.Context, subscriptionID string, date string) (bool, error) {
	return false, nil
}

type mockSubRepo struct {
	subs []models.Subscription
}

func (m *mockSubRepo) Create(ctx context.Context, sub *models.Subscription) error { return nil }
func (m *mockSubRepo) GetByID(ctx context.Context, id string) (*models.Subscription, error) {
	return nil, nil
}
func (m *mockSubRepo) GetActiveByPelangganAndPackage(ctx context.Context, pelangganID, packageID string) (*models.Subscription, error) {
	return nil, nil
}
func (m *mockSubRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	return nil
}
func (m *mockSubRepo) Pause(ctx context.Context, id string, reason string) error  { return nil }
func (m *mockSubRepo) Resume(ctx context.Context, id string) error                { return nil }
func (m *mockSubRepo) Cancel(ctx context.Context, id string, reason string) error { return nil }
func (m *mockSubRepo) ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Subscription, error) {
	return m.subs, nil
}
func (m *mockSubRepo) ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Subscription, error) {
	return []models.Subscription{}, nil
}
func (m *mockSubRepo) CountByPackage(ctx context.Context, packageID string) (int, error) {
	return 0, nil
}
func (m *mockSubRepo) GetActiveSubscriptionsForDate(ctx context.Context, date time.Time) ([]models.Subscription, error) {
	return []models.Subscription{}, nil
}

type mockRouteRepo struct {
	routes []models.Route
}

func (m *mockRouteRepo) Create(ctx context.Context, route *models.Route) error { return nil }
func (m *mockRouteRepo) GetByID(ctx context.Context, id string) (*models.Route, error) {
	return nil, repository.ErrRouteNotFound
}
func (m *mockRouteRepo) GetByPedagangAndDate(ctx context.Context, pedagangID string, date string) (*models.Route, error) {
	return nil, repository.ErrRouteNotFound
}
func (m *mockRouteRepo) Update(ctx context.Context, route *models.Route) error { return nil }
func (m *mockRouteRepo) UpdateStatus(ctx context.Context, routeID string, status string) error {
	return nil
}
func (m *mockRouteRepo) ListByPedagang(ctx context.Context, pedagangID string, from, to string) ([]models.Route, error) {
	return m.routes, nil
}
func (m *mockRouteRepo) Delete(ctx context.Context, id string) error { return nil }

type mockVisitRepo struct{}

func (m *mockVisitRepo) Create(ctx context.Context, visit *models.Visit) error { return nil }
func (m *mockVisitRepo) CreateBatch(ctx context.Context, visits []models.Visit) error {
	return nil
}
func (m *mockVisitRepo) GetByID(ctx context.Context, id string) (*models.Visit, error) {
	return nil, repository.ErrVisitNotFound
}
func (m *mockVisitRepo) ListByRoute(ctx context.Context, routeID string) ([]models.Visit, error) {
	return []models.Visit{}, nil
}
func (m *mockVisitRepo) Update(ctx context.Context, visit *models.Visit) error { return nil }
func (m *mockVisitRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	return nil
}
func (m *mockVisitRepo) MarkArrived(ctx context.Context, id string) error { return nil }
func (m *mockVisitRepo) MarkCompleted(ctx context.Context, id string, items json.RawMessage, amount float64, paymentMethod string) error {
	return nil
}
func (m *mockVisitRepo) MarkSkipped(ctx context.Context, id string, reason string) error {
	return nil
}
func (m *mockVisitRepo) GetVisitHistory(ctx context.Context, pelangganID string, limit int) ([]models.Visit, error) {
	return []models.Visit{}, nil
}
func (m *mockVisitRepo) GetStatsByPedagang(ctx context.Context, pedagangID string, from, to string) (*repository.VisitStats, error) {
	return &repository.VisitStats{}, nil
}

type mockUserRepo struct {
	user *models.User
}

func (m *mockUserRepo) Create(ctx context.Context, user *models.User) error { return nil }
func (m *mockUserRepo) GetByID(ctx context.Context, id string) (*models.User, error) {
	if m.user != nil {
		return m.user, nil
	}
	return &models.User{ID: id, Name: "Test Pedagang"}, nil
}
func (m *mockUserRepo) GetByPhone(ctx context.Context, phone string) (*models.User, error) {
	return nil, repository.ErrUserNotFound
}
func (m *mockUserRepo) Update(ctx context.Context, user *models.User) error { return nil }
func (m *mockUserRepo) UpdateOTP(ctx context.Context, phone string, otp string, expiresAt time.Time) error {
	return nil
}
func (m *mockUserRepo) VerifyOTP(ctx context.Context, phone string, otp string) (*models.User, error) {
	return nil, nil
}
func (m *mockUserRepo) UpdateLastLogin(ctx context.Context, userID string) error { return nil }
func (m *mockUserRepo) UpdateProfile(ctx context.Context, userID string, name string, address string, avatarURL string) error {
	return nil
}
func (m *mockUserRepo) UpdateLocation(ctx context.Context, userID string, lat float64, lng float64) error {
	return nil
}
func (m *mockUserRepo) SetVerified(ctx context.Context, userID string) error { return nil }

// ── Test Helpers ───────────────────────────────────────────────────────────

func newTestInsightService(
	orderRepo repository.OrderRepository,
	subRepo repository.SubscriptionRepository,
	routeRepo repository.RouteRepository,
	visitRepo repository.VisitRepository,
	priceRepo *repository.PriceRepository,
	userRepo repository.UserRepository,
) *InsightService {
	logger, _ := zap.NewDevelopment()
	return NewInsightService(orderRepo, subRepo, routeRepo, visitRepo, priceRepo, userRepo, logger)
}

func makeOrder(pelangganID, pelangganName, date, status, paymentStatus string, totalPrice float64) models.Order {
	return models.Order{
		ID:            "order-" + pelangganID + "-" + date,
		PedagangID:    "pedagang-1",
		PelangganID:   pelangganID,
		PelangganName: pelangganName,
		Items:         json.RawMessage(`[{"product_id":"p1","nama":"Bayam","qty":1,"satuan":"ikat","harga":5000,"subtotal":5000}]`),
		TotalPrice:    totalPrice,
		Status:        status,
		DeliveryDate:  date,
		PaymentStatus: paymentStatus,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
}

// ── Tests ──────────────────────────────────────────────────────────────────

func TestFindPotentialSubscribers(t *testing.T) {
	now := time.Now()
	orders := make(map[string][]models.Order)

	// Customer "cust-1" ordered 4 times in the last 7 days
	for i := 0; i < 4; i++ {
		date := now.AddDate(0, 0, -i).Format("2006-01-02")
		orders[date] = append(orders[date], makeOrder("cust-1", "Budi", date, "delivered", "paid", 10000))
	}

	// Customer "cust-2" ordered 2 times — should NOT trigger
	for i := 0; i < 2; i++ {
		date := now.AddDate(0, 0, -i).Format("2006-01-02")
		orders[date] = append(orders[date], makeOrder("cust-2", "Ani", date, "delivered", "paid", 8000))
	}

	// Customer "cust-3" ordered 5 times but IS subscribed — should NOT trigger
	for i := 0; i < 5; i++ {
		date := now.AddDate(0, 0, -i).Format("2006-01-02")
		orders[date] = append(orders[date], makeOrder("cust-3", "Dina", date, "delivered", "paid", 12000))
	}

	svc := newTestInsightService(
		&mockOrderRepo{orders: orders},
		&mockSubRepo{subs: []models.Subscription{
			{PelangganID: "cust-3", Status: "active"},
		}},
		&mockRouteRepo{},
		&mockVisitRepo{},
		nil,
		&mockUserRepo{},
	)

	ctx := context.Background()
	insights, err := svc.findPotentialSubscribers(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(insights) != 1 {
		t.Fatalf("expected 1 insight, got %d", len(insights))
	}

	insight := insights[0]
	if insight.Type != InsightTypePotentialSubscriber {
		t.Errorf("expected type %s, got %s", InsightTypePotentialSubscriber, insight.Type)
	}
	if insight.Priority != "high" {
		t.Errorf("expected priority high, got %s", insight.Priority)
	}
	if insight.ActionData["pelanggan_id"] != "cust-1" {
		t.Errorf("expected pelanggan_id cust-1, got %s", insight.ActionData["pelanggan_id"])
	}
	if insight.ActionData["order_count"] != "4" {
		t.Errorf("expected order_count 4, got %s", insight.ActionData["order_count"])
	}
}

func TestFindPriceOpportunities(t *testing.T) {
	// Price opportunity detection requires market price data from MongoDB.
	// This test is intentionally skipped when PriceRepository is nil (no MongoDB).
	// To test fully, run integration tests with a real MongoDB instance.
	t.Skip("price opportunity requires MongoDB integration — test with real data")
}

func TestFindRouteSavings(t *testing.T) {
	now := time.Now()
	actualDist := 12.0 // actual distance

	routes := []models.Route{
		{
			ID:               "route-1",
			PedagangID:       "pedagang-1",
			Date:             now.Format("2006-01-02"),
			TotalDistanceKm:  8.0, // optimal
			ActualDistanceKm: &actualDist,
			Status:           "completed",
		},
		{
			ID:               "route-2",
			PedagangID:       "pedagang-1",
			Date:             now.AddDate(0, 0, -1).Format("2006-01-02"),
			TotalDistanceKm:  7.0,
			ActualDistanceKm: &actualDist,
			Status:           "completed",
		},
	}

	svc := newTestInsightService(
		&mockOrderRepo{},
		&mockSubRepo{},
		&mockRouteRepo{routes: routes},
		&mockVisitRepo{},
		nil,
		&mockUserRepo{},
	)

	ctx := context.Background()
	insights, err := svc.findRouteSavings(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(insights) != 1 {
		t.Fatalf("expected 1 insight, got %d", len(insights))
	}

	insight := insights[0]
	if insight.Type != InsightTypeRouteSavings {
		t.Errorf("expected type %s, got %s", InsightTypeRouteSavings, insight.Type)
	}
	if insight.Priority != "medium" {
		t.Errorf("expected priority medium, got %s", insight.Priority)
	}
}

func TestFindAtRiskCustomers(t *testing.T) {
	now := time.Now()
	orders := make(map[string][]models.Order)

	// Customer active 20 days ago, but not in last 14 days
	oldDate := now.AddDate(0, 0, -20).Format("2006-01-02")
	orders[oldDate] = append(orders[oldDate], makeOrder("cust-4", "Rina", oldDate, "delivered", "paid", 15000))

	// Customer active today — should NOT trigger
	today := now.Format("2006-01-02")
	orders[today] = append(orders[today], makeOrder("cust-5", "Joko", today, "delivered", "paid", 9000))

	svc := newTestInsightService(
		&mockOrderRepo{orders: orders},
		&mockSubRepo{},
		&mockRouteRepo{},
		&mockVisitRepo{},
		nil,
		&mockUserRepo{},
	)

	ctx := context.Background()
	insights, err := svc.findAtRiskCustomers(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(insights) != 1 {
		t.Fatalf("expected 1 insight, got %d", len(insights))
	}

	insight := insights[0]
	if insight.Type != InsightTypeCustomerAtRisk {
		t.Errorf("expected type %s, got %s", InsightTypeCustomerAtRisk, insight.Type)
	}
	if insight.ActionData["pelanggan_id"] != "cust-4" {
		t.Errorf("expected pelanggan_id cust-4, got %s", insight.ActionData["pelanggan_id"])
	}
}

func TestFindBestSellerAlerts(t *testing.T) {
	now := time.Now()
	orders := make(map[string][]models.Order)

	// This week: product "Bayam" sold 20 units over 7 days
	for i := 0; i < 7; i++ {
		date := now.AddDate(0, 0, -i).Format("2006-01-02")
		items := json.RawMessage(`[{"product_id":"p1","nama":"Bayam","qty":3,"satuan":"ikat","harga":5000,"subtotal":15000}]`)
		orders[date] = append(orders[date], models.Order{
			ID:            "order-" + date,
			PedagangID:    "pedagang-1",
			PelangganID:   "cust-1",
			Items:         items,
			TotalPrice:    15000,
			Status:        "delivered",
			DeliveryDate:  date,
			PaymentStatus: "paid",
			CreatedAt:     time.Now(),
			UpdatedAt:     time.Now(),
		})
	}

	// Previous week: product "Bayam" sold 7 units over 7 days
	for i := 7; i < 14; i++ {
		date := now.AddDate(0, 0, -i).Format("2006-01-02")
		items := json.RawMessage(`[{"product_id":"p1","nama":"Bayam","qty":1,"satuan":"ikat","harga":5000,"subtotal":5000}]`)
		orders[date] = append(orders[date], models.Order{
			ID:            "order-prev-" + date,
			PedagangID:    "pedagang-1",
			PelangganID:   "cust-1",
			Items:         items,
			TotalPrice:    5000,
			Status:        "delivered",
			DeliveryDate:  date,
			PaymentStatus: "paid",
			CreatedAt:     time.Now(),
			UpdatedAt:     time.Now(),
		})
	}

	svc := newTestInsightService(
		&mockOrderRepo{orders: orders},
		&mockSubRepo{},
		&mockRouteRepo{},
		&mockVisitRepo{},
		nil,
		&mockUserRepo{},
	)

	ctx := context.Background()
	insights, err := svc.findBestSellerAlerts(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(insights) != 1 {
		t.Fatalf("expected 1 insight, got %d", len(insights))
	}

	insight := insights[0]
	if insight.Type != InsightTypeBestSeller {
		t.Errorf("expected type %s, got %s", InsightTypeBestSeller, insight.Type)
	}
	if insight.Icon != "🔥" {
		t.Errorf("expected icon 🔥, got %s", insight.Icon)
	}
}

func TestNoInsightsWhenDataDoesntMatchRules(t *testing.T) {
	// Empty data — no orders, no routes, no subscriptions
	svc := newTestInsightService(
		&mockOrderRepo{},
		&mockSubRepo{},
		&mockRouteRepo{},
		&mockVisitRepo{},
		nil,
		&mockUserRepo{},
	)

	ctx := context.Background()
	insights, err := svc.GenerateInsights(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Should return empty slice, not nil
	if insights == nil {
		t.Fatal("expected non-nil empty slice")
	}
	if len(insights) != 0 {
		t.Errorf("expected 0 insights for empty data, got %d", len(insights))
	}
}

func TestFormatPrice(t *testing.T) {
	tests := []struct {
		input    float64
		expected string
	}{
		{0, "0"},
		{1000, "1.000"},
		{150000, "150.000"},
		{1500000, "1.500.000"},
		{12345678, "12.345.678"},
		{999, "999"},
		{10000, "10.000"},
	}

	for _, tt := range tests {
		result := formatPrice(tt.input)
		if result != tt.expected {
			t.Errorf("formatPrice(%v) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}
