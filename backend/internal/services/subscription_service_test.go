package services

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"go.uber.org/zap"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
)

// --- Mock repositories --------------------------------------------------------

type mockSubscriptionRepo struct {
	subs           map[string]*models.Subscription
	pkgSubCounts   map[string]int
	nextID         int
	pauseErr       error
	resumeErr      error
	cancelErr      error
	createErr      error
}

func newMockSubscriptionRepo() *mockSubscriptionRepo {
	return &mockSubscriptionRepo{
		subs:         make(map[string]*models.Subscription),
		pkgSubCounts: make(map[string]int),
		nextID:       1,
	}
}

func (m *mockSubscriptionRepo) Create(ctx context.Context, sub *models.Subscription) error {
	if m.createErr != nil {
		return m.createErr
	}
	sub.ID = fmt.Sprintf("sub-%d", m.nextID)
	m.nextID++
	sub.CreatedAt = time.Now()
	sub.UpdatedAt = time.Now()
	m.subs[sub.ID] = sub
	m.pkgSubCounts[sub.PackageID]++
	return nil
}

func (m *mockSubscriptionRepo) GetByID(ctx context.Context, id string) (*models.Subscription, error) {
	sub, ok := m.subs[id]
	if !ok {
		return nil, repository.ErrSubscriptionNotFound
	}
	return sub, nil
}

func (m *mockSubscriptionRepo) GetActiveByPelangganAndPackage(ctx context.Context, pelangganID, packageID string) (*models.Subscription, error) {
	for _, sub := range m.subs {
		if sub.PelangganID == pelangganID && sub.PackageID == packageID && sub.Status == "active" {
			return sub, nil
		}
	}
	return nil, nil
}

func (m *mockSubscriptionRepo) UpdateStatus(ctx context.Context, id string, status string) error {
	sub, ok := m.subs[id]
	if !ok {
		return repository.ErrSubscriptionNotFound
	}
	sub.Status = status
	return nil
}

func (m *mockSubscriptionRepo) Pause(ctx context.Context, id string, reason string) error {
	if m.pauseErr != nil {
		return m.pauseErr
	}
	sub, ok := m.subs[id]
	if !ok {
		return repository.ErrSubscriptionNotFound
	}
	if sub.Status != "active" {
		return repository.ErrSubscriptionNotFound
	}
	sub.Status = "paused"
	sub.PauseReason = &reason
	now := time.Now()
	sub.PausedAt = &now
	return nil
}

func (m *mockSubscriptionRepo) Resume(ctx context.Context, id string) error {
	if m.resumeErr != nil {
		return m.resumeErr
	}
	sub, ok := m.subs[id]
	if !ok {
		return repository.ErrSubscriptionNotFound
	}
	if sub.Status != "paused" {
		return repository.ErrSubscriptionNotFound
	}
	sub.Status = "active"
	sub.PauseReason = nil
	sub.PausedAt = nil
	return nil
}

func (m *mockSubscriptionRepo) Cancel(ctx context.Context, id string, reason string) error {
	if m.cancelErr != nil {
		return m.cancelErr
	}
	sub, ok := m.subs[id]
	if !ok {
		return repository.ErrSubscriptionNotFound
	}
	if sub.Status != "active" && sub.Status != "paused" {
		return repository.ErrSubscriptionNotFound
	}
	sub.Status = "cancelled"
	sub.CancelReason = &reason
	now := time.Now()
	sub.CancelledAt = &now
	return nil
}

func (m *mockSubscriptionRepo) ListByPedagang(ctx context.Context, pedagangID string, status string) ([]models.Subscription, error) {
	var result []models.Subscription
	for _, sub := range m.subs {
		if sub.PedagangID == pedagangID {
			if status == "" || sub.Status == status {
				result = append(result, *sub)
			}
		}
	}
	return result, nil
}

func (m *mockSubscriptionRepo) ListByPelanggan(ctx context.Context, pelangganID string, status string) ([]models.Subscription, error) {
	var result []models.Subscription
	for _, sub := range m.subs {
		if sub.PelangganID == pelangganID {
			if status == "" || sub.Status == status {
				result = append(result, *sub)
			}
		}
	}
	return result, nil
}

func (m *mockSubscriptionRepo) CountByPackage(ctx context.Context, packageID string) (int, error) {
	return m.pkgSubCounts[packageID], nil
}

// --- Mock package repo ---

type mockPackageRepo struct {
	packages map[string]*models.SubscriptionPackage
}

func newMockPackageRepo() *mockPackageRepo {
	return &mockPackageRepo{
		packages: make(map[string]*models.SubscriptionPackage),
	}
}

func (m *mockPackageRepo) GetByID(ctx context.Context, id string) (*models.SubscriptionPackage, error) {
	pkg, ok := m.packages[id]
	if !ok {
		return nil, repository.ErrSubscriptionPackageNotFound
	}
	return pkg, nil
}

// --- Mock modification repo ---

type mockModificationRepo struct {
	mods   []models.SubscriptionModification
	nextID int
}

func newMockModificationRepo() *mockModificationRepo {
	return &mockModificationRepo{nextID: 1}
}

func (m *mockModificationRepo) Create(ctx context.Context, mod *models.SubscriptionModification) error {
	mod.ID = fmt.Sprintf("mod-%d", m.nextID)
	m.nextID++
	mod.CreatedAt = time.Now()
	m.mods = append(m.mods, *mod)
	return nil
}

func (m *mockModificationRepo) GetBySubscriptionAndDate(ctx context.Context, subscriptionID, deliveryDate string) (*models.SubscriptionModification, error) {
	for _, mod := range m.mods {
		if mod.SubscriptionID == subscriptionID && mod.DeliveryDate == deliveryDate {
			return &mod, nil
		}
	}
	return nil, nil
}

func (m *mockModificationRepo) ListBySubscription(ctx context.Context, subscriptionID string, limit int) ([]models.SubscriptionModification, error) {
	var result []models.SubscriptionModification
	for _, mod := range m.mods {
		if mod.SubscriptionID == subscriptionID {
			result = append(result, mod)
		}
	}
	if limit > 0 && len(result) > limit {
		result = result[:limit]
	}
	return result, nil
}

// --- Mock order repo ---

type mockOrderRepo struct {
	cancelledSubIDs []string
	nextDelivery    *string
	deliveryCount   int
	totalSpent      float64
}

func newMockOrderRepo() *mockOrderRepo {
	return &mockOrderRepo{}
}

func (m *mockOrderRepo) CancelPendingBySubscription(ctx context.Context, subscriptionID string, fromDate time.Time) (int, error) {
	m.cancelledSubIDs = append(m.cancelledSubIDs, subscriptionID)
	return 3, nil
}

func (m *mockOrderRepo) ListBySubscriptionAndDateRange(ctx context.Context, subscriptionID string, from, to time.Time) ([]models.Order, error) {
	return nil, nil
}

func (m *mockOrderRepo) CountDeliveredBySubscription(ctx context.Context, subscriptionID string) (int, error) {
	return m.deliveryCount, nil
}

func (m *mockOrderRepo) SumSpentBySubscription(ctx context.Context, subscriptionID string) (float64, error) {
	return m.totalSpent, nil
}

func (m *mockOrderRepo) GetNextDeliveryDate(ctx context.Context, subscriptionID string) (*string, error) {
	return m.nextDelivery, nil
}

// --- Test helpers ---

func testLogger() *zap.Logger {
	logger, _ := zap.NewDevelopment()
	return logger
}

func setupTestService() (*SubscriptionService, *mockSubscriptionRepo, *mockPackageRepo, *mockModificationRepo, *mockOrderRepo) {
	subRepo := newMockSubscriptionRepo()
	pkgRepo := newMockPackageRepo()
	modRepo := newMockModificationRepo()
	orderRepo := newMockOrderRepo()
	logger := testLogger()

	// Create a notifier with a nil dispatcher (notifications won't actually send)
	notifier := &SubscriptionNotifier{
		notifDispatcher: nil,
		subRepo:         subRepo,
		logger:          logger.Named("sub_notifier"),
	}

	svc := NewSubscriptionService(subRepo, pkgRepo, modRepo, orderRepo, notifier, logger)
	return svc, subRepo, pkgRepo, modRepo, orderRepo
}

func addTestPackage(pkgRepo *mockPackageRepo, id, pedagangID, name string, price float64, maxSubs int, deliveryDays []int, active bool) {
	pkgRepo.packages[id] = &models.SubscriptionPackage{
		ID:             id,
		PedagangID:     pedagangID,
		Name:           name,
		Price:          price,
		Frequency:      "weekly",
		DeliveryDays:   deliveryDays,
		MaxSubscribers: maxSubs,
		IsActive:       active,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}
}

// --- Tests --------------------------------------------------------------------

func TestSubscribe_HappyPath(t *testing.T) {
	svc, subRepo, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if sub.ID == "" {
		t.Error("expected subscription ID to be set")
	}
	if sub.Status != "active" {
		t.Errorf("expected status active, got %s", sub.Status)
	}
	if sub.PelangganID != "pelanggan-1" {
		t.Errorf("expected pelanggan-1, got %s", sub.PelangganID)
	}
	if sub.PedagangID != "pedagang-1" {
		t.Errorf("expected pedagang-1, got %s", sub.PedagangID)
	}
	if sub.PaymentMethod != "cash" {
		t.Errorf("expected cash, got %s", sub.PaymentMethod)
	}
	if sub.PaymentFrequency != "per_delivery" {
		t.Errorf("expected per_delivery, got %s", sub.PaymentFrequency)
	}

	// Verify stored in repo
	if len(subRepo.subs) != 1 {
		t.Errorf("expected 1 subscription in repo, got %d", len(subRepo.subs))
	}
	if subRepo.pkgSubCounts["pkg-1"] != 1 {
		t.Errorf("expected 1 subscriber for pkg-1, got %d", subRepo.pkgSubCounts["pkg-1"])
	}
}

func TestSubscribe_DuplicateSubscription(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	// First subscription succeeds
	_, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("first subscribe unexpected error: %v", err)
	}

	// Second subscription with same pelanggan and package should fail
	_, err = svc.Subscribe(ctx, "pelanggan-1", req)
	if err == nil {
		t.Fatal("expected error for duplicate subscription, got nil")
	}
}

func TestSubscribe_MaxSubscribersReached(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 1, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	// First subscriber succeeds
	_, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("first subscribe unexpected error: %v", err)
	}

	// Second subscriber should fail (max = 1)
	_, err = svc.Subscribe(ctx, "pelanggan-2", req)
	if err == nil {
		t.Fatal("expected max subscribers error, got nil")
	}
}

func TestSubscribe_InactivePackage(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, false)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	_, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err == nil {
		t.Fatal("expected inactive package error, got nil")
	}
}

func TestSubscribe_PackageNotFound(t *testing.T) {
	svc, _, _, _, _ := setupTestService()
	ctx := context.Background()

	req := SubscribeRequest{
		PackageID:     "nonexistent",
		PaymentMethod: "cash",
	}

	_, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err == nil {
		t.Fatal("expected package not found error, got nil")
	}
}

func TestPauseSubscription_HappyPath(t *testing.T) {
	svc, subRepo, pkgRepo, _, orderRepo := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-1", "liburan")
	if err != nil {
		t.Fatalf("pause error: %v", err)
	}

	// Verify state
	stored := subRepo.subs[sub.ID]
	if stored.Status != "paused" {
		t.Errorf("expected status paused, got %s", stored.Status)
	}
	if stored.PauseReason == nil || *stored.PauseReason != "liburan" {
		t.Errorf("expected pause reason 'liburan', got %v", stored.PauseReason)
	}
	if stored.PausedAt == nil {
		t.Error("expected paused_at to be set")
	}

	// Verify pending orders were cancelled
	if len(orderRepo.cancelledSubIDs) != 1 || orderRepo.cancelledSubIDs[0] != sub.ID {
		t.Errorf("expected pending orders cancelled for sub %s, got %v", sub.ID, orderRepo.cancelledSubIDs)
	}
}

func TestPauseSubscription_AlreadyPaused(t *testing.T) {
	svc, subRepo, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	// First pause succeeds
	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-1", "alasan 1")
	if err != nil {
		t.Fatalf("first pause error: %v", err)
	}

	// Second pause should fail
	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-1", "alasan 2")
	if err == nil {
		t.Fatal("expected error for double pause, got nil")
	}

	_ = subRepo // avoid unused
}

func TestPauseSubscription_NotActive(t *testing.T) {
	svc, subRepo, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	// Cancel first, then try to pause
	subRepo.subs[sub.ID].Status = "cancelled"

	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-1", "alasan")
	if err == nil {
		t.Fatal("expected error for pausing cancelled subscription, got nil")
	}
}

func TestPauseSubscription_WrongPelanggan(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-2", "alasan")
	if err == nil {
		t.Fatal("expected error for wrong pelanggan, got nil")
	}
}

func TestResumeSubscription_HappyPath(t *testing.T) {
	svc, subRepo, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	// Pause first
	err = svc.PauseSubscription(ctx, sub.ID, "pelanggan-1", "liburan")
	if err != nil {
		t.Fatalf("pause error: %v", err)
	}

	// Resume
	err = svc.ResumeSubscription(ctx, sub.ID, "pelanggan-1")
	if err != nil {
		t.Fatalf("resume error: %v", err)
	}

	stored := subRepo.subs[sub.ID]
	if stored.Status != "active" {
		t.Errorf("expected status active, got %s", stored.Status)
	}
	if stored.PauseReason != nil {
		t.Errorf("expected pause reason cleared, got %v", stored.PauseReason)
	}
	if stored.PausedAt != nil {
		t.Errorf("expected paused_at cleared, got %v", stored.PausedAt)
	}
}

func TestResumeSubscription_NotPaused(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	// Try to resume an active subscription
	err = svc.ResumeSubscription(ctx, sub.ID, "pelanggan-1")
	if err == nil {
		t.Fatal("expected error for resuming active subscription, got nil")
	}
}

func TestCancelSubscription_HappyPath(t *testing.T) {
	svc, subRepo, pkgRepo, _, orderRepo := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	err = svc.CancelSubscription(ctx, sub.ID, "pelanggan-1", "pindah rumah")
	if err != nil {
		t.Fatalf("cancel error: %v", err)
	}

	stored := subRepo.subs[sub.ID]
	if stored.Status != "cancelled" {
		t.Errorf("expected status cancelled, got %s", stored.Status)
	}
	if stored.CancelReason == nil || *stored.CancelReason != "pindah rumah" {
		t.Errorf("expected cancel reason 'pindah rumah', got %v", stored.CancelReason)
	}
	if stored.CancelledAt == nil {
		t.Error("expected cancelled_at to be set")
	}

	// Verify pending orders cancelled
	if len(orderRepo.cancelledSubIDs) != 1 {
		t.Errorf("expected 1 cancelled subscription orders, got %d", len(orderRepo.cancelledSubIDs))
	}
}

func TestCancelSubscription_NotActive(t *testing.T) {
	svc, subRepo, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	// Set to already cancelled
	subRepo.subs[sub.ID].Status = "cancelled"

	err = svc.CancelSubscription(ctx, sub.ID, "pelanggan-1", "reason")
	if err == nil {
		t.Fatal("expected error for cancelling already cancelled subscription, got nil")
	}
}

func TestModifyNextDelivery_HappyPath(t *testing.T) {
	svc, _, pkgRepo, modRepo, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	tomorrow := time.Now().AddDate(0, 0, 1).Format("2006-01-02")

	modReq := ModifyRequest{
		DeliveryDate: tomorrow,
		Items: []models.PackageItem{
			{ProductID: "prod-1", Name: "Bayam", Qty: 2, Unit: "ikat"},
		},
		Reason: "ganti sayuran",
	}

	err = svc.ModifyNextDelivery(ctx, sub.ID, "pelanggan-1", modReq)
	if err != nil {
		t.Fatalf("modify error: %v", err)
	}

	if len(modRepo.mods) != 1 {
		t.Fatalf("expected 1 modification, got %d", len(modRepo.mods))
	}

	mod := modRepo.mods[0]
	if mod.SubscriptionID != sub.ID {
		t.Errorf("expected subscription_id %s, got %s", sub.ID, mod.SubscriptionID)
	}
	if mod.DeliveryDate != tomorrow {
		t.Errorf("expected delivery_date %s, got %s", tomorrow, mod.DeliveryDate)
	}
	if mod.SkipDelivery {
		t.Error("expected skip_delivery false")
	}
	if mod.Reason != "ganti sayuran" {
		t.Errorf("expected reason 'ganti sayuran', got %s", mod.Reason)
	}
}

func TestModifyNextDelivery_SkipDelivery(t *testing.T) {
	svc, _, pkgRepo, modRepo, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	tomorrow := time.Now().AddDate(0, 0, 1).Format("2006-01-02")

	modReq := ModifyRequest{
		DeliveryDate: tomorrow,
		SkipDelivery: true,
		Reason:       "tidak di rumah",
	}

	err = svc.ModifyNextDelivery(ctx, sub.ID, "pelanggan-1", modReq)
	if err != nil {
		t.Fatalf("modify error: %v", err)
	}

	mod := modRepo.mods[0]
	if !mod.SkipDelivery {
		t.Error("expected skip_delivery true")
	}
}

func TestModifyNextDelivery_PastDate(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")

	modReq := ModifyRequest{
		DeliveryDate: yesterday,
		Reason:       "test",
	}

	err = svc.ModifyNextDelivery(ctx, sub.ID, "pelanggan-1", modReq)
	if err == nil {
		t.Fatal("expected error for past date, got nil")
	}
}

func TestShouldDeliverToday(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	today := int(time.Now().Weekday())

	// Package that delivers today
	addTestPackage(pkgRepo, "pkg-today", "pedagang-1", "Paket Hari Ini", 50000, 10, []int{today}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-today",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	result, err := svc.ShouldDeliverToday(ctx, sub.ID)
	if err != nil {
		t.Fatalf("ShouldDeliverToday error: %v", err)
	}
	if !result {
		t.Error("expected true for today's delivery day")
	}
}

func TestShouldDeliverToday_NoDelivery(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	// Find a day that is NOT today
	today := int(time.Now().Weekday())
	otherDay := (today + 1) % 7

	addTestPackage(pkgRepo, "pkg-other", "pedagang-1", "Paket Lain", 50000, 10, []int{otherDay}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-other",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	result, err := svc.ShouldDeliverToday(ctx, sub.ID)
	if err != nil {
		t.Fatalf("ShouldDeliverToday error: %v", err)
	}
	if result {
		t.Error("expected false for non-delivery day")
	}
}

func TestValidateDeliveryDay(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	// Package delivers Mon, Wed, Fri
	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket", 50000, 10, []int{1, 3, 5}, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	tests := []struct {
		name     string
		date     string
		expected bool
	}{
		{"Monday", nextWeekday(time.Monday), true},
		{"Tuesday", nextWeekday(time.Tuesday), false},
		{"Wednesday", nextWeekday(time.Wednesday), true},
		{"Thursday", nextWeekday(time.Thursday), false},
		{"Friday", nextWeekday(time.Friday), true},
		{"Saturday", nextWeekday(time.Saturday), false},
		{"Sunday", nextWeekday(time.Sunday), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := svc.ValidateDeliveryDay(ctx, sub.ID, tt.date)
			if err != nil {
				t.Fatalf("ValidateDeliveryDay error: %v", err)
			}
			if result != tt.expected {
				t.Errorf("expected %v for %s, got %v", tt.expected, tt.name, result)
			}
		})
	}
}

func TestGetActiveSubscriptions_Pelanggan(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket 1", 50000, 10, []int{1}, true)
	addTestPackage(pkgRepo, "pkg-2", "pedagang-1", "Paket 2", 75000, 10, []int{3}, true)

	// Subscribe to both
	svc.Subscribe(ctx, "pelanggan-1", SubscribeRequest{PackageID: "pkg-1", PaymentMethod: "cash"})
	svc.Subscribe(ctx, "pelanggan-1", SubscribeRequest{PackageID: "pkg-2", PaymentMethod: "qris"})

	subs, err := svc.GetActiveSubscriptions(ctx, "pelanggan-1", "pelanggan")
	if err != nil {
		t.Fatalf("GetActiveSubscriptions error: %v", err)
	}
	if len(subs) != 2 {
		t.Errorf("expected 2 subscriptions, got %d", len(subs))
	}
}

func TestGetActiveSubscriptions_Pedagang(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket 1", 50000, 10, []int{1}, true)

	svc.Subscribe(ctx, "pelanggan-1", SubscribeRequest{PackageID: "pkg-1", PaymentMethod: "cash"})
	svc.Subscribe(ctx, "pelanggan-2", SubscribeRequest{PackageID: "pkg-1", PaymentMethod: "transfer"})

	subs, err := svc.GetActiveSubscriptions(ctx, "pedagang-1", "pedagang")
	if err != nil {
		t.Fatalf("GetActiveSubscriptions error: %v", err)
	}
	if len(subs) != 2 {
		t.Errorf("expected 2 subscriptions, got %d", len(subs))
	}
}

func TestGetSubscriptionDetail(t *testing.T) {
	svc, _, pkgRepo, _, orderRepo := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Hemat", 50000, 10, []int{1, 3, 5}, true)

	nextDel := "2026-07-20"
	orderRepo.nextDelivery = &nextDel
	orderRepo.deliveryCount = 5
	orderRepo.totalSpent = 250000

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	detail, err := svc.GetSubscriptionDetail(ctx, sub.ID)
	if err != nil {
		t.Fatalf("GetSubscriptionDetail error: %v", err)
	}

	if detail.Package == nil {
		t.Fatal("expected package to be populated")
	}
	if detail.Package.Name != "Paket Hemat" {
		t.Errorf("expected package name 'Paket Hemat', got %s", detail.Package.Name)
	}
	if detail.DeliveryCount != 5 {
		t.Errorf("expected delivery_count 5, got %d", detail.DeliveryCount)
	}
	if detail.TotalSpent != 250000 {
		t.Errorf("expected total_spent 250000, got %f", detail.TotalSpent)
	}
	if detail.NextDelivery != "2026-07-20" {
		t.Errorf("expected next_delivery '2026-07-20', got %s", detail.NextDelivery)
	}
}

func TestGetUpcomingDeliveries(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	// Package delivers every day
	allDays := []int{0, 1, 2, 3, 4, 5, 6}
	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket Harian", 50000, 10, allDays, true)

	req := SubscribeRequest{
		PackageID:     "pkg-1",
		PaymentMethod: "cash",
	}

	sub, err := svc.Subscribe(ctx, "pelanggan-1", req)
	if err != nil {
		t.Fatalf("subscribe error: %v", err)
	}

	dates, err := svc.GetUpcomingDeliveries(ctx, sub.ID, 5)
	if err != nil {
		t.Fatalf("GetUpcomingDeliveries error: %v", err)
	}

	if len(dates) != 5 {
		t.Errorf("expected 5 dates, got %d", len(dates))
	}

	// All dates should be valid and in the future
	for _, d := range dates {
		parsed, err := time.Parse("2006-01-02", d)
		if err != nil {
			t.Errorf("invalid date format: %s", d)
			continue
		}
		if parsed.Before(time.Now().Truncate(24 * time.Hour)) {
			t.Errorf("date %s is in the past", d)
		}
	}
}

func TestGetSubscriberStats(t *testing.T) {
	svc, _, pkgRepo, _, _ := setupTestService()
	ctx := context.Background()

	addTestPackage(pkgRepo, "pkg-1", "pedagang-1", "Paket 1", 50000, 10, []int{1, 3, 5}, true)
	addTestPackage(pkgRepo, "pkg-2", "pedagang-1", "Paket 2", 75000, 10, []int{2, 4}, true)

	// Create 3 subscriptions: 2 active, 1 will be paused
	svc.Subscribe(ctx, "pelanggan-1", SubscribeRequest{PackageID: "pkg-1", PaymentMethod: "cash"})
	sub2, _ := svc.Subscribe(ctx, "pelanggan-2", SubscribeRequest{PackageID: "pkg-1", PaymentMethod: "cash"})
	svc.Subscribe(ctx, "pelanggan-3", SubscribeRequest{PackageID: "pkg-2", PaymentMethod: "qris"})

	// Pause one
	svc.PauseSubscription(ctx, sub2.ID, "pelanggan-2", "alasan")

	stats, err := svc.GetSubscriberStats(ctx, "pedagang-1")
	if err != nil {
		t.Fatalf("GetSubscriberStats error: %v", err)
	}

	if stats.TotalSubscribers != 3 {
		t.Errorf("expected total_subscribers 3, got %d", stats.TotalSubscribers)
	}
	if stats.ActiveSubscribers != 2 {
		t.Errorf("expected active_subscribers 2, got %d", stats.ActiveSubscribers)
	}
	if stats.PausedSubscribers != 1 {
		t.Errorf("expected paused_subscribers 1, got %d", stats.PausedSubscribers)
	}
	if stats.MonthlyRevenue <= 0 {
		t.Errorf("expected monthly_revenue > 0, got %f", stats.MonthlyRevenue)
	}
}

// --- Notifier tests ---

func TestBuildWhatsAppMessage(t *testing.T) {
	logger := testLogger()
	notifier := &SubscriptionNotifier{logger: logger}

	template := "Halo {nama}, pesanan Anda dari {pedagang} total Rp {harga}."
	params := map[string]string{
		"nama":     "Budi",
		"pedagang": "Pak Joko",
		"harga":    "50.000",
	}

	result := notifier.buildWhatsAppMessage(template, params)
	expected := "Halo Budi, pesanan Anda dari Pak Joko total Rp 50.000."
	if result != expected {
		t.Errorf("expected %q, got %q", expected, result)
	}
}

func TestDayNameID(t *testing.T) {
	tests := []struct {
		day      time.Weekday
		expected string
	}{
		{time.Sunday, "Minggu"},
		{time.Monday, "Senin"},
		{time.Tuesday, "Selasa"},
		{time.Wednesday, "Rabu"},
		{time.Thursday, "Kamis"},
		{time.Friday, "Jumat"},
		{time.Saturday, "Sabtu"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := dayNameID(tt.day)
			if result != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, result)
			}
		})
	}
}

func TestFormatRupiah(t *testing.T) {
	tests := []struct {
		amount   float64
		expected string
	}{
		{0, "0"},
		{1000, "1.000"},
		{50000, "50.000"},
		{1500000, "1.500.000"},
		{250000, "250.000"},
		{999999, "999.999"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := formatRupiah(tt.amount)
			if result != tt.expected {
				t.Errorf("formatRupiah(%f) = %s, expected %s", tt.amount, result, tt.expected)
			}
		})
	}
}

func TestDeliveryDaysToString(t *testing.T) {
	tests := []struct {
		days     []int
		expected string
	}{
		{[]int{1, 3, 5}, "Senin, Rabu, Jumat"},
		{[]int{0}, "Minggu"},
		{[]int{}, "jadwal"},
		{[]int{2, 4}, "Selasa, Kamis"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := deliveryDaysToString(tt.days)
			if result != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, result)
			}
		})
	}
}

// --- helpers ---

func nextWeekday(day time.Weekday) string {
	today := time.Now().Truncate(24 * time.Hour)
	daysUntil := (int(day) - int(today.Weekday()) + 7) % 7
	if daysUntil == 0 {
		daysUntil = 7 // next week
	}
	return today.AddDate(0, 0, daysUntil).Format("2006-01-02")
}

// Ensure unused imports are consumed.
var _ = json.RawMessage{}
