package group_order

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
	"go.uber.org/zap"
)

// Handler handles group order (GrosirKu) HTTP requests.
type Handler struct {
	service *services.GroupOrderService
	logger  *zap.Logger
}

// NewHandler creates a new group order Handler.
func NewHandler(service *services.GroupOrderService, logger *zap.Logger) *Handler {
	return &Handler{
		service: service,
		logger:  logger.Named("group_order_handler"),
	}
}

// CreateGroup creates a new group buying order.
// POST /groups
func (h *Handler) CreateGroup(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	var req services.CreateGroupRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	group, err := h.service.CreateGroup(c.Context(), userID, req)
	if err != nil {
		h.logger.Error("Failed to create group", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, group, nil)
}

// ListGroups lists open group orders.
// GET /groups
func (h *Handler) ListGroups(c *fiber.Ctx) error {
	area := c.Query("area", "")

	groups, err := h.service.GetAvailableGroups(c.Context(), area)
	if err != nil {
		h.logger.Error("Failed to list groups", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list group orders", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, groups, nil)
}

// GetGroup returns a single group order by ID.
// GET /groups/:id
func (h *Handler) GetGroup(c *fiber.Ctx) error {
	groupID := c.Params("id")
	if groupID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Group ID is required", nil)
	}

	group, err := h.service.GetGroupDetail(c.Context(), groupID)
	if err != nil {
		if err == repository.ErrGroupOrderNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Group order not found", nil)
		}
		h.logger.Error("Failed to get group", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get group order", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, group, nil)
}

// JoinGroup adds the authenticated pedagang to a group order.
// POST /groups/:id/join
func (h *Handler) JoinGroup(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	groupID := c.Params("id")
	if groupID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Group ID is required", nil)
	}

	var req services.JoinGroupRequest
	if err := c.BodyParser(&req); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if req.Qty <= 0 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "qty must be greater than 0", nil)
	}

	err := h.service.JoinGroup(c.Context(), userID, groupID, req.Qty)
	if err != nil {
		switch err {
		case repository.ErrGroupOrderNotFound:
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Group order not found", nil)
		case repository.ErrGroupNotOpen:
			return utils.ErrorResponse(c, fiber.StatusConflict, "Group order is not open for joining", nil)
		case repository.ErrAlreadyJoined:
			return utils.ErrorResponse(c, fiber.StatusConflict, "You have already joined this group", nil)
		case repository.ErrDeadlinePassed:
			return utils.ErrorResponse(c, fiber.StatusConflict, "Group order deadline has passed", nil)
		}
		h.logger.Error("Failed to join group", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Successfully joined group order",
	}, nil)
}

// LeaveGroup removes the authenticated pedagang from a group order.
// DELETE /groups/:id/leave
func (h *Handler) LeaveGroup(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	groupID := c.Params("id")
	if groupID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Group ID is required", nil)
	}

	err := h.service.LeaveGroup(c.Context(), userID, groupID)
	if err != nil {
		switch err {
		case repository.ErrGroupOrderNotFound:
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Group order not found", nil)
		case repository.ErrGroupNotOpen:
			return utils.ErrorResponse(c, fiber.StatusConflict, "Cannot leave a group that is not open", nil)
		case repository.ErrParticipantNotFound:
			return utils.ErrorResponse(c, fiber.StatusNotFound, "You are not a participant in this group", nil)
		}
		h.logger.Error("Failed to leave group", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to leave group", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Successfully left group order",
	}, nil)
}

// ListParticipants returns participants of a group order.
// GET /groups/:id/participants
func (h *Handler) ListParticipants(c *fiber.Ctx) error {
	groupID := c.Params("id")
	if groupID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Group ID is required", nil)
	}

	participants, err := h.service.ListParticipants(c.Context(), groupID)
	if err != nil {
		h.logger.Error("Failed to list participants", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list participants", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, participants, nil)
}

// FinalizeGroup confirms the group order (organizer only).
// POST /groups/:id/finalize
func (h *Handler) FinalizeGroup(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	groupID := c.Params("id")
	if groupID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Group ID is required", nil)
	}

	err := h.service.FinalizeGroup(c.Context(), userID, groupID)
	if err != nil {
		h.logger.Error("Failed to finalize group", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Group order finalized successfully",
	}, nil)
}

// ListSuppliers returns all active suppliers.
// GET /suppliers
func (h *Handler) ListSuppliers(c *fiber.Ctx) error {
	suppliers, err := h.service.ListSuppliers(c.Context())
	if err != nil {
		h.logger.Error("Failed to list suppliers", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list suppliers", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, suppliers, nil)
}

// CreateSupplier adds a new supplier.
// POST /suppliers
func (h *Handler) CreateSupplier(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	var body struct {
		Name    string   `json:"name"`
		Address string   `json:"address"`
		Phone   string   `json:"phone"`
		Lat     *float64 `json:"lat"`
		Lng     *float64 `json:"lng"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	supplier := &models.Supplier{
		Name:    body.Name,
		Address: body.Address,
		Phone:   body.Phone,
	}
	if body.Lat != nil && body.Lng != nil {
		supplier.Location = &models.Point{Latitude: *body.Lat, Longitude: *body.Lng}
	}

	if err := h.service.CreateSupplier(c.Context(), supplier); err != nil {
		h.logger.Error("Failed to create supplier", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusBadRequest, err.Error(), nil)
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, supplier, nil)
}

// RateSupplier rates a supplier.
// POST /suppliers/:id/rate
func (h *Handler) RateSupplier(c *fiber.Ctx) error {
	userID := middleware.GetUserID(c)
	if userID == "" {
		return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
	}

	supplierID := c.Params("id")
	if supplierID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Supplier ID is required", nil)
	}

	var body struct {
		Rating float64 `json:"rating"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Rating < 0 || body.Rating > 5 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Rating must be between 0 and 5", nil)
	}

	if err := h.service.RateSupplier(c.Context(), supplierID, body.Rating); err != nil {
		if err == repository.ErrSupplierNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Supplier not found", nil)
		}
		h.logger.Error("Failed to rate supplier", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to rate supplier", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"message": "Supplier rated successfully",
	}, nil)
}
