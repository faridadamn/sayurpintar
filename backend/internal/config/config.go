package config

import (
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	JWT      JWTConfig
	WhatsApp WhatsAppConfig
	SMS      SMSConfig
	Maps     MapsConfig
	OTP      OTPConfig
	RateLimit RateLimitConfig
	CORS     CORSConfig
	Log      LogConfig
	App      AppConfig
	OSRM     OSRMConfig
	Payment  PaymentConfig
}

type ServerConfig struct {
	Host         string
	Port         int
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
}

type DatabaseConfig struct {
	Postgres PostgresConfig
	Redis    RedisConfig
	Mongo    MongoConfig
	Meili    MeiliConfig
}

type PostgresConfig struct {
	Host           string
	Port           int
	DB             string
	User           string
	Password       string
	SSLMode        string
	MaxConnections int32
	MinConnections int32
}

type RedisConfig struct {
	Host     string
	Port     int
	Password string
	DB       int
}

type MongoConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DB       string
}

type MeiliConfig struct {
	Host      string
	MasterKey string
}

type JWTConfig struct {
	Secret        string
	AccessExpiry  time.Duration
	RefreshExpiry time.Duration
}

type WhatsAppConfig struct {
	APIURL      string `mapstructure:"WHATSAPP_API_URL"`
	Token       string `mapstructure:"WHATSAPP_TOKEN"`
	PhoneID     string `mapstructure:"WHATSAPP_PHONE_ID"`
	VerifyToken string `mapstructure:"WHATSAPP_VERIFY_TOKEN"`
}

type SMSConfig struct {
	APIURL string `mapstructure:"SMS_API_URL"`
	APIKey string `mapstructure:"SMS_API_KEY"`
	Sender string `mapstructure:"SMS_SENDER"`
}

type MapsConfig struct {
	APIKey   string
	Provider string
}

type OSRMConfig struct {
	BaseURL string
}

type PaymentConfig struct {
	Midtrans MidtransConfig
	Xendit   XenditConfig
}

type MidtransConfig struct {
	ServerKey   string
	ClientKey   string
	MerchantID  string
	Environment string // "sandbox" or "production"
	CallbackURL string
}

type XenditConfig struct {
	SecretKey   string
	CallbackURL string
}

type OTPConfig struct {
	Length          int
	Expiry          time.Duration
	MaxAttempts     int
	ResendCooldown  time.Duration
}

type RateLimitConfig struct {
	AuthPerMin  int
	AnonPerMin  int
}

type CORSConfig struct {
	AllowedOrigins []string
}

type LogConfig struct {
	Level  string
	Format string
}

type AppConfig struct {
	Env string
}

func Load() (*Config, error) {
	viper.SetConfigFile(".env")
	viper.AutomaticEnv()

	// Set defaults
	viper.SetDefault("SERVER_HOST", "0.0.0.0")
	viper.SetDefault("SERVER_PORT", 8080)
	viper.SetDefault("SERVER_READ_TIMEOUT", "30s")
	viper.SetDefault("SERVER_WRITE_TIMEOUT", "30s")
	viper.SetDefault("SERVER_IDLE_TIMEOUT", "120s")
	viper.SetDefault("POSTGRES_HOST", "localhost")
	viper.SetDefault("POSTGRES_PORT", 5432)
	viper.SetDefault("POSTGRES_DB", "sayurpintar")
	viper.SetDefault("POSTGRES_USER", "sp_dev")
	viper.SetDefault("POSTGRES_PASSWORD", "sp_dev_password")
	viper.SetDefault("POSTGRES_SSLMODE", "disable")
	viper.SetDefault("POSTGRES_MAX_CONNECTIONS", 25)
	viper.SetDefault("POSTGRES_MIN_CONNECTIONS", 5)
	viper.SetDefault("REDIS_HOST", "localhost")
	viper.SetDefault("REDIS_PORT", 6379)
	viper.SetDefault("REDIS_PASSWORD", "")
	viper.SetDefault("REDIS_DB", 0)
	viper.SetDefault("MONGO_HOST", "localhost")
	viper.SetDefault("MONGO_PORT", 27017)
	viper.SetDefault("MONGO_USER", "sp_dev")
	viper.SetDefault("MONGO_PASSWORD", "sp_dev_password")
	viper.SetDefault("MONGO_DB", "sayurpintar")
	viper.SetDefault("MEILI_HOST", "http://localhost:7700")
	viper.SetDefault("MEILI_MASTER_KEY", "sp_meili_dev_key")
	viper.SetDefault("JWT_SECRET", "change-this-to-a-secure-random-string")
	viper.SetDefault("JWT_ACCESS_EXPIRY", "15m")
	viper.SetDefault("JWT_REFRESH_EXPIRY", "168h")
	viper.SetDefault("WHATSAPP_API_URL", "https://graph.facebook.com/v18.0")
	viper.SetDefault("SMS_SENDER", "SayurPintar")
	viper.SetDefault("OTP_LENGTH", 6)
	viper.SetDefault("OTP_EXPIRY", "5m")
	viper.SetDefault("OTP_MAX_ATTEMPTS", 5)
	viper.SetDefault("OTP_RESEND_COOLDOWN", "60s")
	viper.SetDefault("RATE_LIMIT_AUTH_PER_MIN", 120)
	viper.SetDefault("RATE_LIMIT_ANON_PER_MIN", 30)
	viper.SetDefault("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080")
	viper.SetDefault("LOG_LEVEL", "debug")
	viper.SetDefault("LOG_FORMAT", "console")
	viper.SetDefault("APP_ENV", "development")
	viper.SetDefault("OSRM_BASE_URL", "https://router.project-osrm.org")
	viper.SetDefault("MIDTRANS_SERVER_KEY", "")
	viper.SetDefault("MIDTRANS_CLIENT_KEY", "")
	viper.SetDefault("MIDTRANS_MERCHANT_ID", "")
	viper.SetDefault("MIDTRANS_ENVIRONMENT", "sandbox")
	viper.SetDefault("MIDTRANS_CALLBACK_URL", "")

	_ = viper.ReadInConfig() // ignore if .env not found

	readTimeout, _ := time.ParseDuration(viper.GetString("SERVER_READ_TIMEOUT"))
	writeTimeout, _ := time.ParseDuration(viper.GetString("SERVER_WRITE_TIMEOUT"))
	idleTimeout, _ := time.ParseDuration(viper.GetString("SERVER_IDLE_TIMEOUT"))
	accessExpiry, _ := time.ParseDuration(viper.GetString("JWT_ACCESS_EXPIRY"))
	refreshExpiry, _ := time.ParseDuration(viper.GetString("JWT_REFRESH_EXPIRY"))
	otpExpiry, _ := time.ParseDuration(viper.GetString("OTP_EXPIRY"))
	otpResendCooldown, _ := time.ParseDuration(viper.GetString("OTP_RESEND_COOLDOWN"))

	cfg := &Config{
		Server: ServerConfig{
			Host:         viper.GetString("SERVER_HOST"),
			Port:         viper.GetInt("SERVER_PORT"),
			ReadTimeout:  readTimeout,
			WriteTimeout: writeTimeout,
			IdleTimeout:  idleTimeout,
		},
		Database: DatabaseConfig{
			Postgres: PostgresConfig{
				Host:           viper.GetString("POSTGRES_HOST"),
				Port:           viper.GetInt("POSTGRES_PORT"),
				DB:             viper.GetString("POSTGRES_DB"),
				User:           viper.GetString("POSTGRES_USER"),
				Password:       viper.GetString("POSTGRES_PASSWORD"),
				SSLMode:        viper.GetString("POSTGRES_SSLMODE"),
				MaxConnections: int32(viper.GetInt("POSTGRES_MAX_CONNECTIONS")),
				MinConnections: int32(viper.GetInt("POSTGRES_MIN_CONNECTIONS")),
			},
			Redis: RedisConfig{
				Host:     viper.GetString("REDIS_HOST"),
				Port:     viper.GetInt("REDIS_PORT"),
				Password: viper.GetString("REDIS_PASSWORD"),
				DB:       viper.GetInt("REDIS_DB"),
			},
			Mongo: MongoConfig{
				Host:     viper.GetString("MONGO_HOST"),
				Port:     viper.GetInt("MONGO_PORT"),
				User:     viper.GetString("MONGO_USER"),
				Password: viper.GetString("MONGO_PASSWORD"),
				DB:       viper.GetString("MONGO_DB"),
			},
			Meili: MeiliConfig{
				Host:      viper.GetString("MEILI_HOST"),
				MasterKey: viper.GetString("MEILI_MASTER_KEY"),
			},
		},
		JWT: JWTConfig{
			Secret:        viper.GetString("JWT_SECRET"),
			AccessExpiry:  accessExpiry,
			RefreshExpiry: refreshExpiry,
		},
		WhatsApp: WhatsAppConfig{
			APIURL:      viper.GetString("WHATSAPP_API_URL"),
			Token:       viper.GetString("WHATSAPP_TOKEN"),
			PhoneID:     viper.GetString("WHATSAPP_PHONE_ID"),
			VerifyToken: viper.GetString("WHATSAPP_VERIFY_TOKEN"),
		},
		SMS: SMSConfig{
			APIURL: viper.GetString("SMS_API_URL"),
			APIKey: viper.GetString("SMS_API_KEY"),
			Sender: viper.GetString("SMS_SENDER"),
		},
		Maps: MapsConfig{
			APIKey:   viper.GetString("MAPS_API_KEY"),
			Provider: viper.GetString("MAPS_PROVIDER"),
		},
		OTP: OTPConfig{
			Length:         viper.GetInt("OTP_LENGTH"),
			Expiry:         otpExpiry,
			MaxAttempts:    viper.GetInt("OTP_MAX_ATTEMPTS"),
			ResendCooldown: otpResendCooldown,
		},
		RateLimit: RateLimitConfig{
			AuthPerMin: viper.GetInt("RATE_LIMIT_AUTH_PER_MIN"),
			AnonPerMin: viper.GetInt("RATE_LIMIT_ANON_PER_MIN"),
		},
		CORS: CORSConfig{
			AllowedOrigins: viper.GetStringSlice("CORS_ALLOWED_ORIGINS"),
		},
		Log: LogConfig{
			Level:  viper.GetString("LOG_LEVEL"),
			Format: viper.GetString("LOG_FORMAT"),
		},
		App: AppConfig{
			Env: viper.GetString("APP_ENV"),
		},
		OSRM: OSRMConfig{
			BaseURL: viper.GetString("OSRM_BASE_URL"),
		},
		Payment: PaymentConfig{
			Midtrans: MidtransConfig{
				ServerKey:   viper.GetString("MIDTRANS_SERVER_KEY"),
				ClientKey:   viper.GetString("MIDTRANS_CLIENT_KEY"),
				MerchantID:  viper.GetString("MIDTRANS_MERCHANT_ID"),
				Environment: viper.GetString("MIDTRANS_ENVIRONMENT"),
				CallbackURL: viper.GetString("MIDTRANS_CALLBACK_URL"),
			},
			Xendit: XenditConfig{
				SecretKey:   viper.GetString("XENDIT_SECRET_KEY"),
				CallbackURL: viper.GetString("XENDIT_CALLBACK_URL"),
			},
		},
	}

	return cfg, nil
}
