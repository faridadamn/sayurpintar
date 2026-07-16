package price

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/sayurpintar/api/internal/services"
	"github.com/sayurpintar/api/internal/utils"
)

// AnalyticsHandler provides additional price analytics endpoints.
type AnalyticsHandler struct {
	priceService *services.PriceService
	priceAgg     *services.PriceAggregator
}

// NewAnalyticsHandler creates a new AnalyticsHandler.
func NewAnalyticsHandler(priceService *services.PriceService, priceAgg *services.PriceAggregator) *AnalyticsHandler {
	return &AnalyticsHandler{
		priceService: priceService,
		priceAgg:     priceAgg,
	}
}

// GetAreaStats handles GET /prices/stats/area
// Returns price statistics for a specific area.
//
//	@Summary		Get area price statistics
//	@Description	Returns price statistics including total products, avg submissions/day, most submitted product
//	@Tags			prices
//	@Accept			json
//	@Produce		json
//	@Param			area	query		string	true	"Area name"
//	@Success		200		{object}	utils.SuccessResponse{data=services.AreaPriceStats}
//	@Failure		400		{object}	utils.ErrorResponse
//	@Router			/prices/stats/area [get]
func (h *AnalyticsHandler) GetAreaStats(c *fiber.Ctx) error {
	area := c.Query("area")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	stats, err := h.priceService.GetAreaPriceStats(c.Context(), area)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "failed to get area stats", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, stats, nil)
}

// GetTopMovers handles GET /prices/top-movers
// Returns products with the biggest price changes today.
//
//	@Summary		Get top price movers
//	@Description	Returns products with biggest price changes for an area
//	@Tags			prices
//	@Accept			json
//	@Produce		json
//	@Param			area	query		string	true	"Area name"
//	@Param			limit	query		int		false	"Number of results (default 10)"
//	@Success		200		{object}	utils.SuccessResponse{data=[]models.AggregatedPrice}
//	@Failure		400		{object}	utils.ErrorResponse
//	@Router			/prices/top-movers [get]
func (h *AnalyticsHandler) GetTopMovers(c *fiber.Ctx) error {
	area := c.Query("area")
	if area == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "area query parameter is required", nil)
	}

	limit := 10
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 50 {
			limit = parsed
		}
	}

	movers, err := h.priceAgg.GetTopMovers(c.Context(), area, limit)
	if err != nil {
		return utils.ErrorResponse(c, fiber.StatusInternalServerError, "failed to get top movers", err.Error())
	}

	return utils.SuccessResponse(c, fiber.StatusOK, movers, nil)
}

// CompareRequest is the input for price comparison across areas.
type CompareRequest struct {
	ProductID string   `json:"product_id" validate:"required"`
	Areas     []string `json:"areas" validate:"required,min=2,max=10"`
}

// CompareResult holds price comparison data for one area.
type CompareResult struct {
	Area        string  `json:"area"`
	MedianPrice float64 `json:"median_price"`
	MinPrice    float64 `json:"min_price"`
	MaxPrice    float64 `json:"max_price"`
	SampleSize  int     `json:"sample_size"`
	Trend       string  `json:"trend"`
	ChangePct   float64 `json:"change_pct"`
}

// CompareResponse is the response for price comparison.
type CompareResponse struct {
	ProductID   string          `json:"product_id"`
	ProductName string          `json:"product_name"`
	Areas       []CompareResult `json:"areas"`
}

// ComparePrices handles GET /prices/compare
// Compares prices for a product across multiple areas.
//
//	@Summary		Compare prices across areas
//	@Description	Compares current prices for a product across specified areas
//	@Tags			prices
//	@Accept			json
//	@Produce		json
//	@Param			product_id	query		string		true	"Product ID"
//	@Param			areas		query		string		true	"Comma-separated area names"
//	@Success		200			{object}	utils.SuccessResponse{data=CompareResponse}
//	@Failure		400			{object}	utils.ErrorResponse
//	@Router			/prices/compare [get]
func (h *AnalyticsHandler) ComparePrices(c *fiber.Ctx) error {
	productID := c.Query("product_id")
	if productID == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "product_id query parameter is required", nil)
	}

	areasParam := c.Query("areas")
	if areasParam == "" {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "areas query parameter is required (comma-separated)", nil)
	}

	areas := splitAndTrim(areasParam)
	if len(areas) < 2 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "at least 2 areas required for comparison", nil)
	}
	if len(areas) > 10 {
		return utils.ErrorResponse(c, fiber.StatusBadRequest, "maximum 10 areas allowed for comparison", nil)
	}

	var results []CompareResult
	productName := ""

	today := time.Now().Format("2006-01-02")
	for _, area := range areas {
		prices, err := h.priceService.GetCurrentPrices(c.Context(), area, today)
		if err != nil {
			continue
		}

		found := false
		for _, p := range prices {
			if p.ProductID == productID {
				if productName == "" {
					productName = p.ProductName
				}
				results = append(results, CompareResult{
					Area:        area,
					MedianPrice: p.MedianPrice,
					MinPrice:    p.MinPrice,
					MaxPrice:    p.MaxPrice,
					SampleSize:  p.SampleSize,
					Trend:       p.Trend,
					ChangePct:   p.ChangePct,
				})
				found = true
				break
			}
		}

		if !found {
			results = append(results, CompareResult{
				Area: area,
			})
		}
	}

	response := CompareResponse{
		ProductID:   productID,
		ProductName: productName,
		Areas:       results,
	}

	return utils.SuccessResponse(c, fiber.StatusOK, response, nil)
}

// RegisterAnalyticsRoutes registers the analytics routes on the given router.
func RegisterAnalyticsRoutes(router fiber.Router, analyticsHandler *AnalyticsHandler) {
	priceGroup := router.Group("/prices")
	priceGroup.Get("/stats/area", analyticsHandler.GetAreaStats)
	priceGroup.Get("/top-movers", analyticsHandler.GetTopMovers)
	priceGroup.Get("/compare", analyticsHandler.ComparePrices)
}

// splitAndTrim splits a comma-separated string and trims whitespace.
func splitAndTrim(s string) []string {
	var result []string
	current := ""
	for _, c := range s {
		if c == ',' {
			if trimmed := trimSpace(current); trimmed != "" {
				result = append(result, trimmed)
			}
			current = ""
		} else {
			current += string(c)
		}
	}
	if trimmed := trimSpace(current); trimmed != "" {
		result = append(result, trimmed)
	}
	return result
}

func trimSpace(s string) string {
	start, end := 0, len(s)
	for start < end && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r') {
		start++
	}
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t' || s[end-1] == '\n' || s[end-1] == '\r') {
		end--
	}
	return s[start:end]
}
