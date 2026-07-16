package price

import (
	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/utils"
	"go.uber.org/zap"
)

// ListProducts returns the product catalog.
// GET /products?category=sayur_hijau&search=bayam&active_only=true
func (h *PriceHandler) ListProducts(c *fiber.Ctx) error {
	category := c.Query("category", "")
	search := c.Query("search", "")
	activeOnly := c.Query("active_only", "true") == "true"

	products, err := h.service.ListProducts(c.Context(), category, search, activeOnly)
	if err != nil {
		h.logger.Error("Failed to list products", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to list products", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, products, nil)
}

// GetProduct returns a single product by ID.
// GET /products/:id
func (h *PriceHandler) GetProduct(c *fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Product ID is required", nil)
	}

	product, err := h.service.GetProduct(c.Context(), id)
	if err != nil {
		if err == repository.ErrProductNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Product not found", nil)
		}
		h.logger.Error("Failed to get product", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get product", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, product, nil)
}

// GetCategories returns all product categories with item counts.
// GET /products/categories
func (h *PriceHandler) GetCategories(c *fiber.Ctx) error {
	categories, err := h.service.GetCategories(c.Context())
	if err != nil {
		h.logger.Error("Failed to get categories", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to get categories", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, categories, nil)
}

// CreateProduct creates a new product (admin only).
// POST /products
func (h *PriceHandler) CreateProduct(c *fiber.Ctx) error {
	role := middleware.GetUserRole(c)
	if role != "admin" {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Admin access required", nil)
	}

	var body struct {
		Name        string  `json:"name"`
		Category    string  `json:"category"`
		DefaultUnit string  `json:"default_unit"`
		ImageURL    *string `json:"image_url"`
	}

	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	if body.Name == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "name is required", nil)
	}
	if body.Category == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "category is required", nil)
	}
	if body.DefaultUnit == "" {
		body.DefaultUnit = "kg"
	}

	product := &models.Product{
		Name:        body.Name,
		Category:    body.Category,
		DefaultUnit: body.DefaultUnit,
		ImageURL:    body.ImageURL,
		IsActive:    true,
	}

	if err := h.service.CreateProduct(c.Context(), product); err != nil {
		h.logger.Error("Failed to create product", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to create product", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusCreated, product, nil)
}

// UpdateProduct updates an existing product (admin only).
// PUT /products/:id
func (h *PriceHandler) UpdateProduct(c *fiber.Ctx) error {
	role := middleware.GetUserRole(c)
	if role != "admin" {
		return utils.ErrorResponse(c, fiber.StatusForbidden, "Admin access required", nil)
	}

	id := c.Params("id")
	if id == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Product ID is required", nil)
	}

	// Fetch existing product first
	existing, err := h.service.GetProduct(c.Context(), id)
	if err != nil {
		if err == repository.ErrProductNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Product not found", nil)
		}
		h.logger.Error("Failed to get product for update", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to update product", nil)
	}

	var body struct {
		Name        *string `json:"name"`
		Category    *string `json:"category"`
		DefaultUnit *string `json:"default_unit"`
		ImageURL    *string `json:"image_url"`
		IsActive    *bool   `json:"is_active"`
	}

	if err := c.BodyParser(&body); err != nil {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "Invalid request body", err.Error())
	}

	// Apply partial updates
	if body.Name != nil {
		existing.Name = *body.Name
	}
	if body.Category != nil {
		existing.Category = *body.Category
	}
	if body.DefaultUnit != nil {
		existing.DefaultUnit = *body.DefaultUnit
	}
	if body.ImageURL != nil {
		existing.ImageURL = body.ImageURL
	}
	if body.IsActive != nil {
		existing.IsActive = *body.IsActive
	}

	if err := h.service.UpdateProduct(c.Context(), existing); err != nil {
		if err == repository.ErrProductNotFound {
			return utils.ErrorResponse(c, fiber.StatusNotFound, "Product not found", nil)
		}
		h.logger.Error("Failed to update product", zap.Error(err))
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "Failed to update product", nil)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, existing, nil)
}
