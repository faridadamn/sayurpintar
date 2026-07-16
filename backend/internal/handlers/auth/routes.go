package auth

import (
	"github.com/gofiber/fiber/v2"
)

// RegisterRoutes registers all auth-related routes on the Fiber app.
func RegisterRoutes(app fiber.Router, handler *AuthHandler, authMiddleware fiber.Handler) {
	auth := app.Group("/auth")

	// Public routes
	auth.Post("/register", handler.Register)
	auth.Post("/otp/send", handler.SendOTP)
	auth.Post("/otp/verify", handler.VerifyOTP)
	auth.Post("/token/refresh", handler.RefreshToken)

	// Protected routes (require authentication)
	protected := auth.Group("", authMiddleware)
	protected.Post("/role", handler.SetRole)
	protected.Get("/me", handler.GetProfile)
	protected.Put("/me", handler.UpdateProfile)
	protected.Post("/logout", handler.Logout)
}
