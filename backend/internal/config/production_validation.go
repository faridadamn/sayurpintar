package config

import (
	"fmt"
	"net/url"
	"strings"
)

const (
	defaultJWTSecret        = "change-this-to-a-secure-random-string"
	defaultPostgresPassword = "sp_dev_password"
	defaultMongoPassword    = "sp_dev_password"
)

// ValidateProduction rejects development defaults and insecure connection
// settings before the application opens any external connections.
func ValidateProduction(cfg *Config) error {
	if cfg == nil {
		return fmt.Errorf("config is required")
	}
	if !strings.EqualFold(strings.TrimSpace(cfg.App.Env), "production") {
		return nil
	}

	var problems []string
	jwtSecret := strings.TrimSpace(cfg.JWT.Secret)
	if jwtSecret == "" || jwtSecret == defaultJWTSecret || len(jwtSecret) < 32 {
		problems = append(problems, "JWT_SECRET must be a non-default secret of at least 32 characters")
	}

	pg := cfg.Database.Postgres
	if isLocalHost(pg.Host) {
		problems = append(problems, "POSTGRES_HOST must not point to localhost in production")
	}
	if strings.TrimSpace(pg.User) == "" || strings.EqualFold(strings.TrimSpace(pg.User), "sp_dev") {
		problems = append(problems, "POSTGRES_USER must be a dedicated production role")
	}
	if strings.TrimSpace(pg.Password) == "" || pg.Password == defaultPostgresPassword {
		problems = append(problems, "POSTGRES_PASSWORD must be set to a non-default value")
	}
	sslMode := strings.ToLower(strings.TrimSpace(pg.SSLMode))
	if sslMode != "require" && sslMode != "verify-ca" && sslMode != "verify-full" {
		problems = append(problems, "POSTGRES_SSLMODE must be require, verify-ca, or verify-full")
	}

	redis := cfg.Database.Redis
	if strings.TrimSpace(redis.Password) == "" {
		problems = append(problems, "REDIS_PASSWORD is required in production")
	}

	mongo := cfg.Database.Mongo
	if strings.TrimSpace(mongo.User) == "" || strings.EqualFold(strings.TrimSpace(mongo.User), "sp_dev") {
		problems = append(problems, "MONGO_USER must be a dedicated production user")
	}
	if strings.TrimSpace(mongo.Password) == "" || mongo.Password == defaultMongoPassword {
		problems = append(problems, "MONGO_PASSWORD must be set to a non-default value")
	}

	if len(cfg.CORS.AllowedOrigins) == 0 {
		problems = append(problems, "CORS_ALLOWED_ORIGINS must contain at least one HTTPS origin")
	}
	for _, rawOrigin := range cfg.CORS.AllowedOrigins {
		origin := strings.TrimSpace(rawOrigin)
		parsed, err := url.Parse(origin)
		if err != nil || parsed.Scheme != "https" || parsed.Host == "" || isLocalHost(parsed.Hostname()) {
			problems = append(problems, fmt.Sprintf("CORS origin %q must be a valid non-local HTTPS origin", origin))
		}
	}

	if len(problems) > 0 {
		return fmt.Errorf("unsafe production configuration: %s", strings.Join(problems, "; "))
	}
	return nil
}

func isLocalHost(host string) bool {
	host = strings.ToLower(strings.TrimSpace(host))
	return host == "" || host == "localhost" || host == "127.0.0.1" || host == "::1"
}
