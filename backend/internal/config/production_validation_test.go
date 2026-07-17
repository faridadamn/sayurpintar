package config

import (
	"strings"
	"testing"
)

func validProductionConfig() *Config {
	return &Config{
		App: AppConfig{Env: "production"},
		JWT: JWTConfig{Secret: "0123456789abcdef0123456789abcdef"},
		Database: DatabaseConfig{
			Postgres: PostgresConfig{
				Host:     "ep-example.aws.neon.tech",
				User:     "sayurpintar_runtime",
				Password: "strong-postgres-password",
				SSLMode:  "require",
			},
			Redis: RedisConfig{Password: "strong-redis-password"},
			Mongo: MongoConfig{
				User:     "sayurpintar_runtime",
				Password: "strong-mongo-password",
			},
		},
		CORS: CORSConfig{AllowedOrigins: []string{"https://app.sayurpintar.id"}},
	}
}

func TestValidateProductionAllowsDevelopmentDefaultsOutsideProduction(t *testing.T) {
	cfg := &Config{App: AppConfig{Env: "development"}}
	if err := ValidateProduction(cfg); err != nil {
		t.Fatalf("development config should not be rejected: %v", err)
	}
}

func TestValidateProductionAcceptsSecureConfiguration(t *testing.T) {
	if err := ValidateProduction(validProductionConfig()); err != nil {
		t.Fatalf("secure production config rejected: %v", err)
	}
}

func TestValidateProductionRejectsDevelopmentDefaults(t *testing.T) {
	cfg := validProductionConfig()
	cfg.JWT.Secret = defaultJWTSecret
	cfg.Database.Postgres.Host = "localhost"
	cfg.Database.Postgres.User = "sp_dev"
	cfg.Database.Postgres.Password = defaultPostgresPassword
	cfg.Database.Postgres.SSLMode = "disable"
	cfg.Database.Redis.Password = ""
	cfg.Database.Mongo.User = "sp_dev"
	cfg.Database.Mongo.Password = defaultMongoPassword
	cfg.CORS.AllowedOrigins = []string{"http://localhost:3000"}

	err := ValidateProduction(cfg)
	if err == nil {
		t.Fatal("expected unsafe production config to be rejected")
	}

	message := err.Error()
	for _, expected := range []string{
		"JWT_SECRET",
		"POSTGRES_HOST",
		"POSTGRES_USER",
		"POSTGRES_PASSWORD",
		"POSTGRES_SSLMODE",
		"REDIS_PASSWORD",
		"MONGO_USER",
		"MONGO_PASSWORD",
		"CORS origin",
	} {
		if !strings.Contains(message, expected) {
			t.Errorf("error does not mention %s: %s", expected, message)
		}
	}
}
