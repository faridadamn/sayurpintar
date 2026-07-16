package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// OrderService handles order business logic.
type OrderService struct {
	orderRepo    repository.OrderRepository
	subRepo      repository.SubscriptionRepository
	routeService *RouteService
	logger       *zap.Logger
}

// NewOrderService creates a new OrderService.
func NewOrderService(
	orderRepo repository.OrderRepository,
	subRepo repository.SubscriptionRepository,
	routeService *RouteService,
	logger *zap.Logger,
) *OrderService {
	return &OrderService{
		orderRepo:    orderRepo,
		subRepo:      subRepo,
		routeService: routeService,
		logger:       logger.Named("order"),
	}
}

// GetTodayOrders returns today's orders for a pedagang.
func (s *OrderService) GetTodayOrders(ctx context.Context, pedagangID string) ([]models.Order, error) {
	orders, err := s.orderRepo.GetTodayOrders(ctx, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("get today orders: %w", err)
	}
	return orders, nil
}

// GetOrderDetail returns a single order by ID.
func (s *OrderService) GetOrderDetail(ctx context.Context, orderID string) (*models.Order, error) {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return nil, fmt.Errorf("get order detail: %w", err)
	}
	return order, nil
}

// UpdateOrderStatus updates order status with valid state transitions.
func (s *OrderService) UpdateOrderStatus(ctx context.Context, orderID string, status string) error {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}

	if err := validateStatusTransition(order.Status, status); err != nil {
		return err
	}

	if err := s.orderRepo.UpdateStatus(ctx, orderID, status); err != nil {
		return fmt.Errorf("update status: %w", err)
	}

	s.logger.Info("order status updated",
		zap.String("order_id", orderID),
		zap.String("from", order.Status),
		zap.String("to", status))
	return nil
}

// MarkDelivered marks an order as delivered.
func (s *OrderService) MarkDelivered(ctx context.Context, orderID string) error {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}

	if order.Status == "delivered" {
		return fmt.Errorf("order already delivered")
	}
	if order.Status == "cancelled" {
		return fmt.Errorf("cannot deliver a cancelled order")
	}

	if err := s.orderRepo.MarkDelivered(ctx, orderID); err != nil {
		return fmt.Errorf("mark delivered: %w", err)
	}

	s.logger.Info("order delivered", zap.String("order_id", orderID))
	return nil
}

// CancelOrder cancels an order with a reason.
func (s *OrderService) CancelOrder(ctx context.Context, orderID string, reason string) error {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}

	if order.Status == "delivered" {
		return fmt.Errorf("cannot cancel a delivered order")
	}
	if order.Status == "cancelled" {
		return fmt.Errorf("order already cancelled")
	}

	if reason == "" {
		reason = "No reason provided"
	}

	if err := s.orderRepo.MarkCancelled(ctx, orderID, reason); err != nil {
		return fmt.Errorf("mark cancelled: %w", err)
	}

	s.logger.Info("order cancelled",
		zap.String("order_id", orderID),
		zap.String("reason", reason))
	return nil
}

// AddRating adds a customer rating to a delivered order.
func (s *OrderService) AddRating(ctx context.Context, orderID string, rating int, comment string) error {
	if rating < 1 || rating > 5 {
		return fmt.Errorf("rating must be between 1 and 5")
	}

	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}

	if order.Status != "delivered" {
		return fmt.Errorf("can only rate delivered orders")
	}
	if order.Rating != nil {
		return fmt.Errorf("order already rated")
	}

	if err := s.orderRepo.AddRating(ctx, orderID, rating, comment); err != nil {
		return fmt.Errorf("add rating: %w", err)
	}

	s.logger.Info("order rated",
		zap.String("order_id", orderID),
		zap.Int("rating", rating))
	return nil
}

// GetOrderSummary returns daily order summary for a pedagang.
func (s *OrderService) GetOrderSummary(ctx context.Context, pedagangID string, date string) (*repository.OrderSummary, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}

	summary, err := s.orderRepo.GetOrderSummary(ctx, pedagangID, date)
	if err != nil {
		return nil, fmt.Errorf("get order summary: %w", err)
	}
	return summary, nil
}

// CreateOneTimeOrder creates a non-subscription order for ad-hoc deliveries.
func (s *OrderService) CreateOneTimeOrder(
	ctx context.Context,
	pedagangID string,
	pelangganID string,
	items []models.OrderItem,
	deliveryDate string,
) (*models.Order, error) {
	if len(items) == 0 {
		return nil, fmt.Errorf("order must have at least one item")
	}

	if deliveryDate == "" {
		deliveryDate = time.Now().Format("2006-01-02")
	}

	// Calculate total price
	var totalPrice float64
	for i := range items {
		items[i].Subtotal = items[i].Qty * items[i].Price
		totalPrice += items[i].Subtotal
	}

	itemsJSON, err := json.Marshal(items)
	if err != nil {
		return nil, fmt.Errorf("marshal items: %w", err)
	}

	order := &models.Order{
		PedagangID:    pedagangID,
		PelangganID:   pelangganID,
		Items:         itemsJSON,
		TotalPrice:    totalPrice,
		Status:        "pending",
		DeliveryDate:  deliveryDate,
		PaymentMethod: "cash",
		PaymentStatus: "pending",
	}

	if err := s.orderRepo.Create(ctx, order); err != nil {
		return nil, fmt.Errorf("create order: %w", err)
	}

	s.logger.Info("one-time order created",
		zap.String("order_id", order.ID),
		zap.String("pedagang_id", pedagangID),
		zap.String("pelanggan_id", pelangganID),
		zap.Float64("total", totalPrice))

	return order, nil
}

// ListByPedagangAndDate returns orders for a pedagang on a given date.
func (s *OrderService) ListByPedagangAndDate(ctx context.Context, pedagangID string, date string) ([]models.Order, error) {
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	return s.orderRepo.ListByPedagangAndDate(ctx, pedagangID, date)
}

// ListByPelanggan returns recent orders for a pelanggan.
func (s *OrderService) ListByPelanggan(ctx context.Context, pelangganID string, limit int) ([]models.Order, error) {
	return s.orderRepo.ListByPelanggan(ctx, pelangganID, limit)
}

// UpdatePayment updates the payment status of an order.
func (s *OrderService) UpdatePayment(ctx context.Context, orderID string, paymentStatus string, paymentMethod string) error {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}

	if err := s.orderRepo.UpdatePayment(ctx, orderID, paymentStatus, paymentMethod); err != nil {
		return fmt.Errorf("update payment: %w", err)
	}

	s.logger.Info("order payment updated",
		zap.String("order_id", orderID),
		zap.String("from", order.PaymentStatus),
		zap.String("to", paymentStatus))
	return nil
}

// validateStatusTransition checks if a status change is valid.
func validateStatusTransition(from, to string) error {
	validTransitions := map[string][]string{
		"pending":    {"preparing", "cancelled", "skipped"},
		"preparing":  {"delivering", "cancelled"},
		"delivering": {"delivered", "cancelled"},
		"delivered":  {},
		"cancelled":  {},
		"skipped":    {},
	}

	allowed, ok := validTransitions[from]
	if !ok {
		return fmt.Errorf("unknown current status: %s", from)
	}

	for _, s := range allowed {
		if s == to {
			return nil
		}
	}

	return fmt.Errorf("invalid status transition from '%s' to '%s'", from, to)
}
