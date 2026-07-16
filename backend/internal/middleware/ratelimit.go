package middleware

import (
	"context"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/redis/go-redis/v9"
	"github.com/sayurpintar/api/internal/utils"
	"go.uber.org/zap"
)

// RateLimit creates a Redis-based rate limiter using a sliding window algorithm.
// Identifies requests by IP for anonymous users and by user_id for authenticated users.
// Key format: ratelimit:{identifier}:{path}
func RateLimit(rdb *redis.Client, maxRequests int, window time.Duration, logger *zap.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx := context.Background()

		// Identifier: prefer authenticated user ID, fall back to IP
		identifier := c.IP()
		if userID := GetUserID(c); userID != "" {
			identifier = "user:" + userID
		}

		key := fmt.Sprintf("ratelimit:%s:%s", identifier, c.Path())

		now := time.Now()
		windowStart := now.Add(-window)

		// Sliding window: remove expired entries, add current request, count, set TTL
		pipe := rdb.Pipeline()
		pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", windowStart.UnixNano()))
		pipe.ZAdd(ctx, key, redis.Z{Score: float64(now.UnixNano()), Member: now.UnixNano()})
		countCmd := pipe.ZCard(ctx, key)
		pipe.Expire(ctx, key, window)

		if _, err := pipe.Exec(ctx); err != nil {
			logger.Error("rate limit redis error", zap.Error(err))
			return c.Next()
		}

		count := countCmd.Val()
		remaining := int64(maxRequests) - count
		if remaining < 0 {
			remaining = 0
		}

		c.Set("X-RateLimit-Limit", fmt.Sprintf("%d", maxRequests))
		c.Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

		if count > int64(maxRequests) {
			// Calculate retry-after from oldest entry in window
			oldest, _ := rdb.ZRange(ctx, key, 0, 0).Result()
			if len(oldest) > 0 {
				retryAfter := window - now.Sub(windowStart)
				if retryAfter < 0 {
					retryAfter = time.Second
				}
				c.Set("Retry-After", fmt.Sprintf("%d", int(retryAfter.Seconds())))
			}
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Rate limit exceeded", nil)
		}

		return c.Next()
	}
}

// AuthRateLimit creates a rate limiter specifically for authenticated endpoints.
// Uses the user ID as the primary identifier.
func AuthRateLimit(rdb *redis.Client, maxRequests int, window time.Duration, logger *zap.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx := context.Background()

		userID := GetUserID(c)
		if userID == "" {
			return utils.ErrorResponse(c, fiber.StatusUnauthorized, "Authentication required", nil)
		}

		key := fmt.Sprintf("ratelimit:user:%s:%s", userID, c.Path())

		now := time.Now()
		windowStart := now.Add(-window)

		pipe := rdb.Pipeline()
		pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", windowStart.UnixNano()))
		pipe.ZAdd(ctx, key, redis.Z{Score: float64(now.UnixNano()), Member: now.UnixNano()})
		countCmd := pipe.ZCard(ctx, key)
		pipe.Expire(ctx, key, window)

		if _, err := pipe.Exec(ctx); err != nil {
			logger.Error("auth rate limit redis error", zap.Error(err))
			return c.Next()
		}

		count := countCmd.Val()
		remaining := int64(maxRequests) - count
		if remaining < 0 {
			remaining = 0
		}

		c.Set("X-RateLimit-Limit", fmt.Sprintf("%d", maxRequests))
		c.Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

		if count > int64(maxRequests) {
			return utils.ErrorResponse(c, fiber.StatusTooManyRequests, "Rate limit exceeded", nil)
		}

		return c.Next()
	}
}
