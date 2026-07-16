package services

import (
	"context"
	"fmt"
	"time"

	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// CreateGroupRequest holds the input for creating a group order.
type CreateGroupRequest struct {
	SupplierID    string  `json:"supplier_id"`
	ProductID     string  `json:"product_id"`
	ProductName   string  `json:"product_name"`
	TargetQty     float64 `json:"target_qty"`
	GroupPrice    float64 `json:"group_price"`
	RegularPrice  float64 `json:"regular_price"`
	Unit          string  `json:"unit"`
	Deadline      string  `json:"deadline"`       // RFC3339 or YYYY-MM-DD HH:MM
	DeliveryDate  string  `json:"delivery_date"`  // YYYY-MM-DD
	DeliveryPoint string  `json:"delivery_point"`
}

// JoinGroupRequest holds the input for joining a group order.
type JoinGroupRequest struct {
	Qty float64 `json:"qty"`
}

// GroupOrderService orchestrates group buying (GrosirKu) operations.
type GroupOrderService struct {
	groupRepo    repository.GroupOrderRepository
	notifService *NotificationService
	logger       *zap.Logger
}

// NewGroupOrderService creates a new GroupOrderService.
func NewGroupOrderService(
	groupRepo repository.GroupOrderRepository,
	notifService *NotificationService,
	logger *zap.Logger,
) *GroupOrderService {
	return &GroupOrderService{
		groupRepo:    groupRepo,
		notifService: notifService,
		logger:       logger.Named("group_order_service"),
	}
}

// CreateGroup starts a new group buying order.
func (s *GroupOrderService) CreateGroup(ctx context.Context, organizerID string, req CreateGroupRequest) (*models.GroupOrder, error) {
	if req.ProductID == "" {
		return nil, fmt.Errorf("product_id is required")
	}
	if req.ProductName == "" {
		return nil, fmt.Errorf("product_name is required")
	}
	if req.TargetQty <= 0 {
		return nil, fmt.Errorf("target_qty must be greater than 0")
	}
	if req.GroupPrice <= 0 {
		return nil, fmt.Errorf("group_price must be greater than 0")
	}
	if req.RegularPrice <= 0 {
		return nil, fmt.Errorf("regular_price must be greater than 0")
	}
	if req.GroupPrice >= req.RegularPrice {
		return nil, fmt.Errorf("group_price must be less than regular_price")
	}
	if req.Unit == "" {
		return nil, fmt.Errorf("unit is required")
	}
	if req.DeliveryDate == "" {
		return nil, fmt.Errorf("delivery_date is required")
	}
	if req.DeliveryPoint == "" {
		return nil, fmt.Errorf("delivery_point is required")
	}

	// Parse deadline
	deadline, err := time.Parse(time.RFC3339, req.Deadline)
	if err != nil {
		// Try YYYY-MM-DD HH:MM format
		deadline, err = time.Parse("2006-01-02 15:04", req.Deadline)
		if err != nil {
			return nil, fmt.Errorf("invalid deadline format, use RFC3339 or YYYY-MM-DD HH:MM: %w", err)
		}
	}
	if deadline.Before(time.Now()) {
		return nil, fmt.Errorf("deadline must be in the future")
	}

	group := &models.GroupOrder{
		OrganizerID:   organizerID,
		SupplierID:    req.SupplierID,
		ProductID:     req.ProductID,
		ProductName:   req.ProductName,
		TargetQty:     req.TargetQty,
		CurrentQty:    0,
		GroupPrice:    req.GroupPrice,
		RegularPrice:  req.RegularPrice,
		Unit:          req.Unit,
		Deadline:      deadline,
		DeliveryDate:  req.DeliveryDate,
		DeliveryPoint: req.DeliveryPoint,
		Status:        models.GroupStatusOpen,
	}

	if err := s.groupRepo.CreateGroup(ctx, group); err != nil {
		return nil, fmt.Errorf("create group: %w", err)
	}

	s.logger.Info("Group order created",
		zap.String("group_id", group.ID),
		zap.String("organizer_id", organizerID),
		zap.String("product", req.ProductName),
		zap.Float64("target_qty", req.TargetQty),
	)

	return group, nil
}

// JoinGroup adds a pedagang to an existing group order.
func (s *GroupOrderService) JoinGroup(ctx context.Context, pedagangID, groupID string, qty float64) error {
	if qty <= 0 {
		return fmt.Errorf("qty must be greater than 0")
	}

	// Get group
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		return fmt.Errorf("get group: %w", err)
	}

	// Validate group state
	if group.Status != models.GroupStatusOpen {
		return repository.ErrGroupNotOpen
	}
	if group.Deadline.Before(time.Now()) {
		return repository.ErrDeadlinePassed
	}

	// Check if already joined
	existing, _ := s.groupRepo.GetParticipant(ctx, groupID, pedagangID)
	if existing != nil {
		return repository.ErrAlreadyJoined
	}

	// Calculate total price for this participant
	totalPrice := qty * group.GroupPrice

	participant := &models.GroupParticipant{
		GroupOrderID: groupID,
		PedagangID:   pedagangID,
		Qty:          qty,
		TotalPrice:   totalPrice,
		Status:       models.ParticipantJoined,
	}

	if err := s.groupRepo.JoinGroup(ctx, participant); err != nil {
		return fmt.Errorf("join group: %w", err)
	}

	// Update current quantity
	if err := s.groupRepo.UpdateCurrentQty(ctx, groupID); err != nil {
		s.logger.Error("Failed to update current qty after join", zap.Error(err))
	}

	// Check if target reached
	if err := s.CheckAndFinalize(ctx, groupID); err != nil {
		s.logger.Error("Failed to check finalize after join", zap.Error(err))
	}

	s.logger.Info("Pedagang joined group",
		zap.String("group_id", groupID),
		zap.String("pedagang_id", pedagangID),
		zap.Float64("qty", qty),
	)

	return nil
}

// CheckAndFinalize checks if target quantity is met and updates status to "full".
func (s *GroupOrderService) CheckAndFinalize(ctx context.Context, groupID string) error {
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		return fmt.Errorf("get group: %w", err)
	}

	if group.Status != models.GroupStatusOpen {
		return nil // Already finalized or cancelled
	}

	if group.CurrentQty >= group.TargetQty {
		if err := s.groupRepo.UpdateGroupStatus(ctx, groupID, models.GroupStatusFull); err != nil {
			return fmt.Errorf("update status to full: %w", err)
		}

		s.logger.Info("Group order reached target",
			zap.String("group_id", groupID),
			zap.Float64("current_qty", group.CurrentQty),
			zap.Float64("target_qty", group.TargetQty),
		)

		// Notify organizer
		if s.notifService != nil {
			_ = s.notifService.Create(ctx, group.OrganizerID, "group_order",
				"Grup Penuh!",
				fmt.Sprintf("Grup GrosirKu untuk %s sudah mencapai target. Siap dipesan!", group.ProductName),
				map[string]string{"group_order_id": groupID},
			)
		}
	}

	return nil
}

// AutoFinalizeExpired closes groups that have passed their deadline without reaching target.
func (s *GroupOrderService) AutoFinalizeExpired(ctx context.Context) (int, error) {
	// Find all open groups past deadline
	groups, err := s.groupRepo.ListOpenGroups(ctx, "")
	if err != nil {
		return 0, fmt.Errorf("list open groups: %w", err)
	}

	count := 0
	now := time.Now()
	for _, g := range groups {
		if g.Deadline.Before(now) {
			newStatus := models.GroupStatusCancelled
			if g.CurrentQty >= g.TargetQty {
				newStatus = models.GroupStatusFull
			}

			if err := s.groupRepo.UpdateGroupStatus(ctx, g.ID, newStatus); err != nil {
				s.logger.Error("Failed to finalize expired group",
					zap.String("group_id", g.ID),
					zap.Error(err),
				)
				continue
			}

			count++

			// Notify organizer
			if s.notifService != nil {
				title := "GrosirKu Dibatalkan"
				body := fmt.Sprintf("Grup GrosirKu untuk %s tidak mencapai target dan telah dibatalkan.", g.ProductName)
				if newStatus == models.GroupStatusFull {
					title = "GrosirKu Penuh"
					body = fmt.Sprintf("Grup GrosirKu untuk %s sudah penuh!", g.ProductName)
				}
				_ = s.notifService.Create(ctx, g.OrganizerID, "group_order", title, body,
					map[string]string{"group_order_id": g.ID})
			}
		}
	}

	if count > 0 {
		s.logger.Info("Auto-finalized expired groups", zap.Int("count", count))
	}
	return count, nil
}

// GetAvailableGroups returns open group orders in an area.
func (s *GroupOrderService) GetAvailableGroups(ctx context.Context, area string) ([]models.GroupOrder, error) {
	return s.groupRepo.ListOpenGroups(ctx, area)
}

// GetGroupDetail returns a group order by ID.
func (s *GroupOrderService) GetGroupDetail(ctx context.Context, groupID string) (*models.GroupOrder, error) {
	return s.groupRepo.GetGroupByID(ctx, groupID)
}

// ListByOrganizer returns group orders for a specific organizer.
func (s *GroupOrderService) ListByOrganizer(ctx context.Context, organizerID string) ([]models.GroupOrder, error) {
	return s.groupRepo.ListByOrganizer(ctx, organizerID)
}

// LeaveGroup removes a pedagang from a group order.
func (s *GroupOrderService) LeaveGroup(ctx context.Context, pedagangID, groupID string) error {
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		return fmt.Errorf("get group: %w", err)
	}
	if group.Status != models.GroupStatusOpen {
		return repository.ErrGroupNotOpen
	}

	if err := s.groupRepo.LeaveGroup(ctx, groupID, pedagangID); err != nil {
		return fmt.Errorf("leave group: %w", err)
	}

	// Recalculate qty
	if err := s.groupRepo.UpdateCurrentQty(ctx, groupID); err != nil {
		s.logger.Error("Failed to update qty after leave", zap.Error(err))
	}

	s.logger.Info("Pedagang left group",
		zap.String("group_id", groupID),
		zap.String("pedagang_id", pedagangID),
	)
	return nil
}

// ListParticipants returns all participants of a group order.
func (s *GroupOrderService) ListParticipants(ctx context.Context, groupID string) ([]models.GroupParticipant, error) {
	return s.groupRepo.ListParticipants(ctx, groupID)
}

// FinalizeGroup marks the group as "ordered" (organizer confirms the order).
func (s *GroupOrderService) FinalizeGroup(ctx context.Context, organizerID, groupID string) error {
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		return fmt.Errorf("get group: %w", err)
	}

	if group.OrganizerID != organizerID {
		return fmt.Errorf("only the organizer can finalize the group")
	}

	if group.Status != models.GroupStatusFull && group.Status != models.GroupStatusOpen {
		return fmt.Errorf("group cannot be finalized in status: %s", group.Status)
	}

	if err := s.groupRepo.UpdateGroupStatus(ctx, groupID, models.GroupStatusOrdered); err != nil {
		return fmt.Errorf("update status: %w", err)
	}

	// Notify all participants
	participants, _ := s.groupRepo.ListParticipants(ctx, groupID)
	for _, p := range participants {
		if s.notifService != nil {
			_ = s.notifService.Create(ctx, p.PedagangID, "group_order",
				"Pesanan GrosirKu Dipesan",
				fmt.Sprintf("Pesanan grup untuk %s telah dipesan ke supplier. Tunggu info pengiriman.", group.ProductName),
				map[string]string{"group_order_id": groupID},
			)
		}
	}

	s.logger.Info("Group order finalized",
		zap.String("group_id", groupID),
		zap.String("organizer_id", organizerID),
	)
	return nil
}

// CalculateSavings returns how much a pedagang saves per unit by joining the group.
func (s *GroupOrderService) CalculateSavings(ctx context.Context, groupID string) (float64, error) {
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		return 0, fmt.Errorf("get group: %w", err)
	}
	return group.RegularPrice - group.GroupPrice, nil
}

// ListSuppliers returns all active suppliers.
func (s *GroupOrderService) ListSuppliers(ctx context.Context) ([]models.Supplier, error) {
	return s.groupRepo.ListSuppliers(ctx)
}

// CreateSupplier adds a new supplier.
func (s *GroupOrderService) CreateSupplier(ctx context.Context, supplier *models.Supplier) error {
	if supplier.Name == "" {
		return fmt.Errorf("supplier name is required")
	}
	if supplier.Phone == "" {
		return fmt.Errorf("supplier phone is required")
	}
	return s.groupRepo.CreateSupplier(ctx, supplier)
}

// RateSupplier rates a supplier.
func (s *GroupOrderService) RateSupplier(ctx context.Context, supplierID string, rating float64) error {
	if rating < 0 || rating > 5 {
		return fmt.Errorf("rating must be between 0 and 5")
	}
	return s.groupRepo.RateSupplier(ctx, supplierID, rating)
}
