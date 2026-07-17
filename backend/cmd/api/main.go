package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
	"github.com/sayurpintar/api/internal/config"
	"github.com/sayurpintar/api/internal/database"
	"github.com/sayurpintar/api/internal/handlers/analytics"
	"github.com/sayurpintar/api/internal/handlers/auth"
	debtHandler "github.com/sayurpintar/api/internal/handlers/debt"
	"github.com/sayurpintar/api/internal/handlers/group_order"
	"github.com/sayurpintar/api/internal/handlers/health"
	"github.com/sayurpintar/api/internal/handlers/notification"
	"github.com/sayurpintar/api/internal/handlers/order"
	paymentHandler "github.com/sayurpintar/api/internal/handlers/payment"
	"github.com/sayurpintar/api/internal/handlers/price"
	"github.com/sayurpintar/api/internal/handlers/route"
	"github.com/sayurpintar/api/internal/handlers/subscription"
	"github.com/sayurpintar/api/internal/handlers/transaction"
	"github.com/sayurpintar/api/internal/middleware"
	"github.com/sayurpintar/api/internal/repository"
	"github.com/sayurpintar/api/internal/services"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	cfg, err := config.Load()
	if err != nil { log.Fatalf("Failed to load config: %v", err) }
	logger, err := initLogger(cfg.Log)
	if err != nil { log.Fatalf("Failed to init logger: %v", err) }
	defer logger.Sync()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pgPool, err := database.NewPostgresPool(ctx, cfg.Database.Postgres, logger)
	if err != nil { logger.Fatal("Failed to connect to PostgreSQL", zap.Error(err)) }
	defer pgPool.Close()
	redisClient, err := database.NewRedisClient(ctx, cfg.Database.Redis, logger)
	if err != nil { logger.Fatal("Failed to connect to Redis", zap.Error(err)) }
	defer redisClient.Close()
	mongoClient, err := database.NewMongoClient(ctx, cfg.Database.Mongo, logger)
	if err != nil { logger.Fatal("Failed to connect to MongoDB", zap.Error(err)) }
	defer mongoClient.Disconnect(ctx)
	mongoDB := mongoClient.Database(cfg.Database.Mongo.DB)

	userRepo := repository.NewUserRepository(pgPool)
	waypointRepo := repository.NewWaypointRepository(pgPool)
	routeRepo := repository.NewRouteRepository(pgPool)
	subRepo := repository.NewSubscriptionRepository(pgPool)
	pkgRepo := repository.NewSubscriptionPackageRepository(pgPool)
	modRepo := repository.NewSubscriptionModificationRepository(pgPool)
	orderRepo := repository.NewOrderRepository(pgPool)
	visitRepo := repository.NewVisitRepository(pgPool)
	txnRepo := repository.NewTransactionRepository(pgPool)
	notifRepo := repository.NewNotificationRepository(pgPool)
	priceRepo := repository.NewPriceRepository(mongoDB, logger)
	productRepo := repository.NewProductRepository(pgPool)
	groupOrderRepo := repository.NewGroupOrderRepository(pgPool)
	debtRepo := repository.NewDebtRepository(pgPool)

	jwtService := services.NewJWTService(cfg)
	otpService := services.NewOTPService(redisClient, cfg)
	whatsappSvc := services.NewWhatsAppService(cfg, logger)
	smsSvc := services.NewSMSService(cfg, logger)
	notifDispatcher := services.NewNotificationDispatcher(whatsappSvc, smsSvc, redisClient, logger)
	authService := services.NewAuthService(userRepo, otpService, jwtService, notifDispatcher, redisClient, cfg)
	osrmService := services.NewOSRMService(cfg, redisClient, logger)
	routeOptimizer := services.NewRouteOptimizer(osrmService, logger)
	routeService := services.NewRouteService(routeRepo, waypointRepo, routeOptimizer, osrmService, logger)
	visitService := services.NewVisitService(visitRepo, routeRepo, waypointRepo, logger)
	trackingHub := services.NewTrackingHub(redisClient, logger)
	priceService := services.NewPriceService(priceRepo, productRepo, notifDispatcher, redisClient, logger)
	priceAnomaly := services.NewPriceAnomalyDetector(priceRepo, logger)
	priceAggregator := services.NewPriceAggregator(priceRepo, redisClient, logger)
	subNotifier := services.NewSubscriptionNotifier(notifDispatcher, subRepo, logger)
	subService := services.NewSubscriptionService(subRepo, pkgRepo, modRepo, orderRepo, subNotifier, logger)
	orderService := services.NewOrderService(orderRepo, subRepo, routeService, logger)
	orderGenerator := services.NewOrderGenerator(subRepo, pkgRepo, modRepo, orderRepo, routeService, waypointRepo, notifDispatcher, userRepo, logger)
	paymentGW := services.NewPaymentGateway(&cfg.Payment, logger)
	invoiceSvc := services.NewInvoiceService(orderRepo, logger)
	notifService := services.NewNotificationService(notifRepo, notifDispatcher, redisClient, logger)
	debtService := services.NewDebtService(debtRepo, orderRepo, txnRepo, userRepo, notifService, notifDispatcher, logger)
	analyticsService := services.NewAnalyticsService(pgPool, orderRepo, subRepo, routeRepo, visitRepo, priceRepo, userRepo, redisClient, logger)
	insightService := services.NewInsightService(orderRepo, subRepo, routeRepo, visitRepo, priceRepo, userRepo, logger)
	rewardService := services.NewRewardService(userRepo, redisClient, logger)
	groupOrderService := services.NewGroupOrderService(groupOrderRepo, notifService, logger)

	scheduler := services.NewScheduler(orderGenerator, priceAggregator, priceService, notifService, paymentGW, orderRepo, logger)
	scheduler.Start()
	defer scheduler.Stop()

	healthHandler := health.NewHandler(pgPool, redisClient, mongoClient)
	authHandler := auth.NewAuthHandler(authService)
	routeHandler := route.NewHandler(routeService)
	visitHandler := route.NewVisitHandler(visitService)
	routeHandler.SetVisitHandler(visitHandler)
	subHandler := subscription.NewHandler(subService)
	priceHandler := price.NewPriceHandler(priceService, logger)
	orderHandler := order.NewHandler(orderService)
	txnHandler := transaction.NewHandler()
	analyticsHandler := analytics.NewAnalyticsHandler(analyticsService)
	notifHandler := notification.NewNotificationHandler(notifRepo)
	insightHandler := analytics.NewInsightHandler(insightService)
	rewardHandler := analytics.NewRewardHandler(rewardService)
	payHandler := paymentHandler.NewHandler(paymentGW, invoiceSvc)
	debtH := debtHandler.NewHandler(debtService)
	groupOrderHandler := group_order.NewHandler(groupOrderService, logger)
	_ = priceAnomaly

	authMiddleware := middleware.AuthMiddleware(jwtService, authService)
	corsMiddleware := middleware.CORSMiddleware(cfg)
	requestIDMiddleware := middleware.RequestID()
	loggerMiddleware := middleware.Logger(logger)
	recoverMiddleware := middleware.Recover(logger)

	app := fiber.New(fiber.Config{
		AppName: "SayurPintar API", ReadTimeout: cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout, IdleTimeout: cfg.Server.IdleTimeout,
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code, message := fiber.StatusInternalServerError, "Internal server error"
			if e, ok := err.(*fiber.Error); ok { code, message = e.Code, e.Message }
			logger.Error("unhandled request error", zap.Error(err), zap.Int("status", code))
			return c.Status(code).JSON(fiber.Map{"success":false, "error":fiber.Map{"code":code, "message":message}})
		},
	})
	app.Use(recoverMiddleware, requestIDMiddleware, loggerMiddleware, corsMiddleware)
	app.Get("/health", healthHandler.Liveness)
	app.Get("/ready", healthHandler.Readiness)
	v1 := app.Group("/api/v1")
	auth.RegisterRoutes(v1, authHandler, authMiddleware)
	route.RegisterRoutes(v1, routeHandler, authMiddleware)
	visitGroup := v1.Group("/routes/visits", authMiddleware)
	visitGroup.Get("/today", visitHandler.GetTodayVisits)
	visitGroup.Get("/summary", visitHandler.GetVisitSummary)
	visitGroup.Post("/:id/arrive", visitHandler.MarkVisitArrived)
	visitGroup.Post("/:id/complete", visitHandler.MarkVisitCompleted)
	visitGroup.Post("/:id/skip", visitHandler.MarkVisitSkipped)
	trackGroup := v1.Group("/routes/track", authMiddleware)
	trackGroup.Get("/:pedagang_id", route.GetPedagangLocation(trackingHub))
	trackGroup.Get("/ws", func(c *fiber.Ctx) error { if websocket.IsWebSocketUpgrade(c) { return c.Next() }; return fiber.ErrUpgradeRequired }, route.HandleTrackingWebSocket(trackingHub))
	subscription.RegisterRoutes(v1, subHandler, authMiddleware)
	price.RegisterRoutes(v1, priceHandler, authMiddleware)
	order.RegisterRoutes(v1, orderHandler, authMiddleware)
	protected := v1.Group("", authMiddleware)
	txnGroup := protected.Group("/transactions")
	txnGroup.Get("/", txnHandler.GetTransactions)
	txnGroup.Post("/", txnHandler.CreateTransaction)
	txnGroup.Get("/summary", txnHandler.GetTransactionSummary)
	analytics.RegisterRoutes(v1, analyticsHandler, authMiddleware)
	notification.RegisterRoutes(v1, notifHandler, authMiddleware)
	analytics.RegisterInsightRoutes(v1, insightHandler, authMiddleware)
	analytics.RegisterRewardRoutes(v1, rewardHandler, authMiddleware)
	paymentHandler.RegisterRoutes(v1, payHandler, authMiddleware)
	debtHandler.RegisterRoutes(v1, debtH, authMiddleware)
	group_order.RegisterRoutes(v1, groupOrderHandler, authMiddleware)

	addr := fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port)
	go func() { logger.Info("Starting server", zap.String("address", addr)); if err := app.Listen(addr); err != nil { logger.Fatal("Server failed to start", zap.Error(err)) } }()
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("Shutting down server...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := app.ShutdownWithContext(shutdownCtx); err != nil { logger.Error("Server forced to shutdown", zap.Error(err)) }
	logger.Info("Server exited")
}

func initLogger(cfg config.LogConfig) (*zap.Logger, error) {
	var zapCfg zap.Config
	if cfg.Format == "json" { zapCfg = zap.NewProductionConfig() } else { zapCfg = zap.NewDevelopmentConfig(); zapCfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder }
	level, err := zapcore.ParseLevel(cfg.Level)
	if err != nil { level = zapcore.DebugLevel }
	zapCfg.Level = zap.NewAtomicLevelAt(level)
	return zapCfg.Build()
}
