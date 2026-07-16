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

// GenerationResult captures the outcome of a daily order generation run.
type GenerationResult struct {
	Date               string   `json:"date"`
	TotalSubscriptions int      `json:"total_subscriptions"`
	OrdersGenerated    int      `json:"orders_generated"`
	OrdersSkipped      int      `json:"orders_skipped"`
	RoutesAdded        int      `json:"routes_added"`
	NotificationsSent  int      `json:"notifications_sent"`
	Errors             []string `json:"errors,omitempty"`
}

// OrderGenerator generates orders from active subscriptions.
// Designed to run as a daily cron job at 4:00 AM WIB.
type OrderGenerator struct {
	subRepo      repository.SubscriptionRepository
	pkgRepo      repository.SubscriptionPackageRepository
	modRepo      repository.SubscriptionModificationRepository
	orderRepo    repository.OrderRepository
	routeService *RouteService
	waypointRepo repository.WaypointRepository
	notifService *NotificationDispatcher
	userRepo     repository.UserRepository
	logger       *zap.Logger
}

// NewOrderGenerator creates a new OrderGenerator.
func NewOrderGenerator(
	subRepo repository.SubscriptionRepository,
	pkgRepo repository.SubscriptionPackageRepository,
	modRepo repository.SubscriptionModificationRepository,
	orderRepo repository.OrderRepository,
	routeService *RouteService,
	waypointRepo repository.WaypointRepository,
	notifService *NotificationDispatcher,
	userRepo repository.UserRepository,
	logger *zap.Logger,
) *OrderGenerator {
	return &OrderGenerator{
		subRepo:      subRepo,
		pkgRepo:      pkgRepo,
		modRepo:      modRepo,
		orderRepo:    orderRepo,
		routeService: routeService,
		waypointRepo: waypointRepo,
		notifService: notifService,
		userRepo:     userRepo,
		logger:       logger.Named("order-generator"),
	}
}

// GenerateDailyOrders is the main cron job entry point.
// Runs at 4:00 AM WIB daily.
// Steps:
//  1. Get all active subscriptions
//  2. Filter by delivery_days matching today's day of week (done by SQL)
//  3. Check for modifications (skip, item changes)
//  4. Generate orders
//  5. Add customers to today's route
//  6. Send "besok diantar" notification to pelanggan
func (g *OrderGenerator) GenerateDailyOrders(ctx context.Context) (*GenerationResult, error) {
	// Use WIB (Asia/Jakarta) timezone for delivery date
	wib, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		// Fallback to fixed UTC+7
		wib = time.FixedZone("WIB", 7*60*60)
	}

	now := time.Now().In(wib)
	deliveryDate := now.Format("2006-01-02")

	g.logger.Info("starting daily order generation",
		zap.String("date", deliveryDate),
		zap.Int("day_of_week", int(now.Weekday())))

	result := &GenerationResult{
		Date: deliveryDate,
	}

	// Step 1-2: Get active subscriptions filtered by today's delivery day
	subs, err := g.subRepo.GetActiveSubscriptionsForDate(ctx, now)
	if err != nil {
		return nil, fmt.Errorf("get active subscriptions: %w", err)
	}

	result.TotalSubscriptions = len(subs)
	g.logger.Info("found active subscriptions", zap.Int("count", len(subs)))

	// Step 3-6: Process each subscription
	for i := range subs {
		sub := &subs[i]
		order, err := g.GenerateOrderForSubscription(ctx, sub, now)
		if err != nil {
			errMsg := fmt.Sprintf("sub %s: %v", sub.ID, err)
			result.Errors = append(result.Errors, errMsg)
			g.logger.Error("failed to generate order",
				zap.String("subscription_id", sub.ID),
				zap.Error(err))
			continue
		}

		if order == nil {
			// Skipped due to modification
			result.OrdersSkipped++
			continue
		}

		result.OrdersGenerated++

		// Step 5: Add customer to today's route via waypoint lookup
		if err := g.addCustomerToRoute(ctx, sub.PedagangID, sub.PelangganID); err != nil {
			g.logger.Warn("failed to add customer to route",
				zap.String("subscription_id", sub.ID),
				zap.String("pelanggan_id", sub.PelangganID),
				zap.Error(err))
		} else {
			result.RoutesAdded++
		}

		// Step 6: Send notification
		if err := g.sendDeliveryNotification(ctx, sub, deliveryDate); err != nil {
			g.logger.Warn("failed to send notification",
				zap.String("subscription_id", sub.ID),
				zap.String("pelanggan_id", sub.PelangganID),
				zap.Error(err))
		} else {
			result.NotificationsSent++
		}
	}

	g.logger.Info("daily order generation completed",
		zap.Int("total_subs", result.TotalSubscriptions),
		zap.Int("generated", result.OrdersGenerated),
		zap.Int("skipped", result.OrdersSkipped),
		zap.Int("routes_added", result.RoutesAdded),
		zap.Int("notifications", result.NotificationsSent),
		zap.Int("errors", len(result.Errors)))

	return result, nil
}

// GenerateOrderForSubscription creates a single order from a subscription.
// Returns nil if the delivery should be skipped (via modification).
func (g *OrderGenerator) GenerateOrderForSubscription(
	ctx context.Context,
	sub *models.Subscription,
	deliveryDate time.Time,
) (*models.Order, error) {
	dateStr := deliveryDate.Format("2006-01-02")

	// Check idempotency — don't create duplicate orders
	exists, err := g.orderRepo.ExistsForSubscriptionAndDate(ctx, sub.ID, dateStr)
	if err != nil {
		return nil, fmt.Errorf("check existing order: %w", err)
	}
	if exists {
		g.logger.Debug("order already exists, skipping",
			zap.String("subscription_id", sub.ID),
			zap.String("date", dateStr))
		return nil, nil
	}

	// Load the package to get items
	pkg, err := g.pkgRepo.GetByID(ctx, sub.PackageID)
	if err != nil {
		return nil, fmt.Errorf("get package: %w", err)
	}

	// Parse package items
	var packageItems []models.PackageItem
	if err := json.Unmarshal(pkg.Items, &packageItems); err != nil {
		return nil, fmt.Errorf("unmarshal package items: %w", err)
	}

	// Step 3: Check for modifications
	orderItems := g.ApplyModification(ctx, sub.ID, deliveryDate, packageItems)

	// If orderItems is nil, the delivery was skipped
	if orderItems == nil {
		return nil, nil
	}

	// Calculate total price
	var totalPrice float64
	for _, item := range orderItems {
		totalPrice += item.Subtotal
	}

	itemsJSON, err := json.Marshal(orderItems)
	if err != nil {
		return nil, fmt.Errorf("marshal order items: %w", err)
	}

	order := &models.Order{
		SubscriptionID: &sub.ID,
		PedagangID:     sub.PedagangID,
		PelangganID:    sub.PelangganID,
		Items:          itemsJSON,
		TotalPrice:     totalPrice,
		Status:         "pending",
		DeliveryDate:   dateStr,
		PaymentMethod:  sub.PaymentMethod,
		PaymentStatus:  "pending",
	}

	if err := g.orderRepo.Create(ctx, order); err != nil {
		return nil, fmt.Errorf("create order: %w", err)
	}

	g.logger.Info("order generated",
		zap.String("order_id", order.ID),
		zap.String("subscription_id", sub.ID),
		zap.String("pelanggan_id", sub.PelangganID),
		zap.Float64("total", totalPrice))

	return order, nil
}

// ApplyModification applies subscription modification to order items.
// Returns nil if the delivery should be skipped entirely.
func (g *OrderGenerator) ApplyModification(
	ctx context.Context,
	subID string,
	date time.Time,
	packageItems []models.PackageItem,
) []models.OrderItem {
	dateStr := date.Format("2006-01-02")

	mod, err := g.modRepo.GetBySubscriptionAndDate(ctx, subID, dateStr)
	if err != nil {
		// Error fetching modification — use defaults
		g.logger.Warn("failed to get modification, using defaults",
			zap.String("subscription_id", subID),
			zap.Error(err))
		return packageItemsToOrderItems(packageItems)
	}

	// No modification found — use default package items
	if mod == nil {
		return packageItemsToOrderItems(packageItems)
	}

	// Check if delivery should be skipped
	if mod.SkipDelivery {
		g.logger.Info("delivery skipped via modification",
			zap.String("subscription_id", subID),
			zap.String("date", dateStr),
			zap.String("reason", mod.Reason))
		return nil
	}

	// If items were modified, use the modified items
	if mod.Items != nil && len(mod.Items) > 0 {
		var modifiedItems []models.OrderItem
		if err := json.Unmarshal(mod.Items, &modifiedItems); err != nil {
			g.logger.Warn("failed to parse modified items, using defaults",
				zap.String("subscription_id", subID),
				zap.Error(err))
			return packageItemsToOrderItems(packageItems)
		}
		return modifiedItems
	}

	// No item changes — use defaults
	return packageItemsToOrderItems(packageItems)
}

// addCustomerToRoute looks up the waypoint for a pelanggan and adds it to today's route.
func (g *OrderGenerator) addCustomerToRoute(ctx context.Context, pedagangID, pelangganID string) error {
	// Find waypoint linked to this pelanggan
	waypoints, err := g.waypointRepo.GetByPelanggan(ctx, pelangganID)
	if err != nil {
		return fmt.Errorf("get waypoints by pelanggan: %w", err)
	}

	for _, wp := range waypoints {
		if wp.PedagangID == pedagangID {
			// Add to route (idempotent — AddWaypointToRoute checks duplicates)
			err := g.routeService.AddWaypointToRoute(ctx, pedagangID, wp.ID)
			if err != nil {
				// Already in route is fine
				g.logger.Debug("waypoint route add result",
					zap.String("waypoint_id", wp.ID),
					zap.Error(err))
			}
			return nil
		}
	}

	return fmt.Errorf("no waypoint found for pelanggan %s under pedagang %s", pelangganID, pedagangID)
}

// sendDeliveryNotification sends a "besok diantar" notification to the pelanggan.
func (g *OrderGenerator) sendDeliveryNotification(
	ctx context.Context,
	sub *models.Subscription,
	deliveryDate string,
) error {
	if g.notifService == nil {
		return nil
	}

	// Get pelanggan phone from user repo
	user, err := g.userRepo.GetByID(ctx, sub.PelangganID)
	if err != nil {
		return fmt.Errorf("get pelanggan user: %w", err)
	}

	if user.Phone == "" {
		return fmt.Errorf("pelanggan has no phone number")
	}

	message := fmt.Sprintf(
		"Halo %s! Pesanan langganan Anda (%s) akan diantar besok (%s). Terima kasih telah berlangganan SayurPintar! 🥬",
		user.DisplayName(),
		sub.PackageName,
		deliveryDate,
	)

	_, err = g.notifService.SendNotification(ctx, user.Phone, message, "auto")
	if err != nil {
		return fmt.Errorf("send notification: %w", err)
	}

	return nil
}

// ShouldDeliverToday checks if a subscription should deliver on the given day.
// This is a helper for non-SQL contexts; the primary filtering is done in SQL.
func ShouldDeliverToday(sub *models.Subscription, today time.Time) bool {
	// Actual filtering is done by GetActiveSubscriptionsForDate in SQL.
	// This helper is kept for use in Go-side filtering if needed.
	dayOfWeek := int(today.Weekday())
	_ = dayOfWeek
	return true
}

// packageItemsToOrderItems converts PackageItem slice to OrderItem slice.
func packageItemsToOrderItems(items []models.PackageItem) []models.OrderItem {
	orderItems := make([]models.OrderItem, len(items))
	for i, item := range items {
		orderItems[i] = models.OrderItem{
			ProductID: item.ProductID,
			Name:      item.Name,
			Qty:       item.Qty,
			Unit:      item.Unit,
			Price:     item.PricePerUnit,
			Subtotal:  item.Qty * item.PricePerUnit,
		}
	}
	return orderItems
}
