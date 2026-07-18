package repository

import (
	"context"
	"fmt"

	"github.com/sayurpintar/api/internal/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// GetDistinctProductIDs returns product IDs that have submissions in an area.
func (r *PriceRepository) GetDistinctProductIDs(ctx context.Context, area string) ([]string, error) {
	values, err := r.col.Distinct(ctx, "product_id", bson.M{"area": area})
	if err != nil {
		return nil, fmt.Errorf("distinct product ids: %w", err)
	}

	ids := make([]string, 0, len(values))
	for _, value := range values {
		if id, ok := value.(string); ok && id != "" {
			ids = append(ids, id)
		}
	}
	return ids, nil
}

// GetPricesForProductArea returns submissions from the requested date onward,
// newest first so callers can use the final item as the earliest sample.
func (r *PriceRepository) GetPricesForProductArea(
	ctx context.Context,
	productID string,
	area string,
	fromDate string,
) ([]models.PriceSubmission, error) {
	filter := bson.M{
		"product_id": productID,
		"area":       area,
		"date":       bson.M{"$gte": fromDate},
	}
	opts := options.Find().SetSort(bson.D{{Key: "date", Value: -1}, {Key: "created_at", Value: -1}})

	cursor, err := r.col.Find(ctx, filter, opts)
	if err != nil {
		return nil, fmt.Errorf("find product area prices: %w", err)
	}
	defer cursor.Close(ctx)

	var submissions []models.PriceSubmission
	if err := cursor.All(ctx, &submissions); err != nil {
		return nil, fmt.Errorf("decode product area prices: %w", err)
	}
	if submissions == nil {
		submissions = []models.PriceSubmission{}
	}
	return submissions, nil
}

// GetProductName returns the most recently submitted non-empty product name.
func (r *PriceRepository) GetProductName(ctx context.Context, productID string) (string, error) {
	var submission models.PriceSubmission
	err := r.col.FindOne(
		ctx,
		bson.M{"product_id": productID, "product_name": bson.M{"$ne": ""}},
		options.FindOne().SetSort(bson.D{{Key: "created_at", Value: -1}}),
	).Decode(&submission)
	if err != nil {
		return "", fmt.Errorf("get product name: %w", err)
	}
	return submission.ProductName, nil
}
