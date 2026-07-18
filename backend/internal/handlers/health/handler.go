package health

import (
	"context"

	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/database"
	"github.com/sayurpintar/api/internal/utils"
	"go.mongodb.org/mongo-driver/mongo"
)

type Handler struct {
	pgPool *pgxpool.Pool
	redis  *redis.Client
	mongo  *mongo.Client
}

func NewHandler(pgPool *pgxpool.Pool, redis *redis.Client, mongo *mongo.Client) *Handler {
	return &Handler{
		pgPool: pgPool,
		redis:  redis,
		mongo:  mongo,
	}
}

// Liveness returns 200 if the server is running.
func (h *Handler) Liveness(c *fiber.Ctx) error {
	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"status": "alive",
	}, nil)
}

// Readiness checks all database connections.
func (h *Handler) Readiness(c *fiber.Ctx) error {
	ctx := context.Background()

	checks := fiber.Map{}
	allHealthy := true

	if err := database.PostgresHealthCheck(ctx, h.pgPool); err != nil {
		checks["postgres"] = fiber.Map{"status": "unhealthy", "error": err.Error()}
		allHealthy = false
	} else {
		checks["postgres"] = fiber.Map{"status": "healthy"}
	}

	if err := database.RedisHealthCheck(ctx, h.redis); err != nil {
		checks["redis"] = fiber.Map{"status": "unhealthy", "error": err.Error()}
		allHealthy = false
	} else {
		checks["redis"] = fiber.Map{"status": "healthy"}
	}

	if err := database.MongoHealthCheck(ctx, h.mongo); err != nil {
		checks["mongodb"] = fiber.Map{"status": "unhealthy", "error": err.Error()}
		allHealthy = false
	} else {
		checks["mongodb"] = fiber.Map{"status": "healthy"}
	}

	if !allHealthy {
		return utils.ErrorResponse(c, fiber.StatusServiceUnavailable, "One or more services unhealthy", checks)
	}

	return utils.SuccessResponse(c, fiber.StatusOK, fiber.Map{
		"status": "ready",
		"checks": checks,
	}, nil)
}
