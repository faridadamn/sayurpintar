package services

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"

	"github.com/sayurpintar/api/internal/config"
)

// --- test helpers --------------------------------------------------------------

func newTestLogger() *zap.Logger {
	logger, _ := zap.NewDevelopment()
	return logger
}

func newTestConfig(waURL string, smsURL string) *config.Config {
	return &config.Config{
		WhatsApp: config.WhatsAppConfig{
			APIURL:  waURL,
			Token:   "test-token",
			PhoneID: "123456",
		},
		SMS: config.SMSConfig{
			APIURL: smsURL,
			APIKey: "test-sms-key",
			Sender: "SayurPintar",
		},
	}
}

// --- WhatsAppService tests ----------------------------------------------------

func TestWhatsAppService_SendOTP_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify auth header
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Errorf("expected Bearer test-token, got %s", r.Header.Get("Authorization"))
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"messaging_product":"whatsapp","contacts":[{"input":"628123456789","wa_id":"628123456789"}],"messages":[{"id":"msg_123"}]}`)
	}))
	defer server.Close()

	cfg := newTestConfig(server.URL, "")
	logger := newTestLogger()
	svc := NewWhatsAppService(cfg, logger)

	msgID, err := svc.SendOTP(context.Background(), "08123456789", "123456")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if msgID != "msg_123" {
		t.Errorf("expected msg_123, got %s", msgID)
	}
}

func TestWhatsAppService_SendOTP_TemplateNotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, `{"error":{"message":"Template not found","type":"OAuthException","code":131026}}`)
	}))
	defer server.Close()

	cfg := newTestConfig(server.URL, "")
	logger := newTestLogger()
	svc := NewWhatsAppService(cfg, logger)

	_, err := svc.SendOTP(context.Background(), "08123456789", "123456")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if expected := "WhatsApp template not found"; !contains(err.Error(), expected) {
		t.Errorf("expected error containing %q, got %q", expected, err.Error())
	}
}

func TestWhatsAppService_SendOTP_InvalidPhone(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, `{"error":{"message":"Invalid phone number","type":"OAuthException","code":131051}}`)
	}))
	defer server.Close()

	cfg := newTestConfig(server.URL, "")
	logger := newTestLogger()
	svc := NewWhatsAppService(cfg, logger)

	_, err := svc.SendOTP(context.Background(), "invalid", "123456")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if expected := "WhatsApp invalid phone number"; !contains(err.Error(), expected) {
		t.Errorf("expected error containing %q, got %q", expected, err.Error())
	}
}

func TestWhatsAppService_SendOTP_RateLimit(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusTooManyRequests)
		fmt.Fprint(w, `{"error":{"message":"Rate limit exceeded","type":"OAuthException","code":4}}`)
	}))
	defer server.Close()

	cfg := newTestConfig(server.URL, "")
	logger := newTestLogger()
	svc := NewWhatsAppService(cfg, logger)

	_, err := svc.SendOTP(context.Background(), "08123456789", "123456")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if expected := "WhatsApp rate limited"; !contains(err.Error(), expected) {
		t.Errorf("expected error containing %q, got %q", expected, err.Error())
	}
}

// --- SMSService tests ---------------------------------------------------------

func TestSMSService_SendOTP_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Fatalf("failed to parse form: %v", err)
		}
		if r.FormValue("api_key") != "test-sms-key" {
			t.Errorf("expected api_key=test-sms-key, got %s", r.FormValue("api_key"))
		}
		if r.FormValue("sender") != "SayurPintar" {
			t.Errorf("expected sender=SayurPintar, got %s", r.FormValue("sender"))
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"success","data":{"message_id":"sms_456"}}`)
	}))
	defer server.Close()

	cfg := newTestConfig("", server.URL)
	logger := newTestLogger()
	svc := NewSMSService(cfg, logger)

	msgID, err := svc.SendOTP(context.Background(), "08123456789", "123456")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if msgID != "sms_456" {
		t.Errorf("expected sms_456, got %s", msgID)
	}
}

func TestSMSService_SendOTP_GatewayError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, `{"error":"Invalid phone number"}`)
	}))
	defer server.Close()

	cfg := newTestConfig("", server.URL)
	logger := newTestLogger()
	svc := NewSMSService(cfg, logger)

	_, err := svc.SendOTP(context.Background(), "08123456789", "123456")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

// --- NotificationDispatcher tests ----------------------------------------------

func TestDispatcher_WhatsAppSuccess(t *testing.T) {
	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"messaging_product":"whatsapp","contacts":[{"input":"628123456789","wa_id":"628123456789"}],"messages":[{"id":"wa_msg_1"}]}`)
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("SMS server should not be called when WhatsApp succeeds")
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, nil, logger)

	result, err := dispatcher.SendOTP(context.Background(), "08123456789", "123456")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Channel != "whatsapp" {
		t.Errorf("expected channel whatsapp, got %s", result.Channel)
	}
	if result.Status != "sent" {
		t.Errorf("expected status sent, got %s", result.Status)
	}
	if result.MessageID != "wa_msg_1" {
		t.Errorf("expected message_id wa_msg_1, got %s", result.MessageID)
	}
}

func TestDispatcher_FallbackToSMS(t *testing.T) {
	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, `{"error":{"message":"Internal error","type":"OAuthException","code":1}}`)
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"success","data":{"message_id":"sms_msg_2"}}`)
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, nil, logger)

	result, err := dispatcher.SendOTP(context.Background(), "08123456789", "123456")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Channel != "sms" {
		t.Errorf("expected channel sms, got %s", result.Channel)
	}
	if result.Status != "fallback" {
		t.Errorf("expected status fallback, got %s", result.Status)
	}
	if result.MessageID != "sms_msg_2" {
		t.Errorf("expected message_id sms_msg_2, got %s", result.MessageID)
	}
	if result.Error == "" {
		t.Error("expected error field to contain WhatsApp error")
	}
}

func TestDispatcher_BothFail(t *testing.T) {
	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, `{"error":{"message":"WA down","type":"OAuthException","code":1}}`)
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprint(w, `{"error":"SMS gateway down"}`)
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, nil, logger)

	result, err := dispatcher.SendOTP(context.Background(), "08123456789", "123456")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if result.Status != "failed" {
		t.Errorf("expected status failed, got %s", result.Status)
	}
	if result.Channel != "none" {
		t.Errorf("expected channel none, got %s", result.Channel)
	}
}

func TestDispatcher_RateLimit(t *testing.T) {
	// Set up a real Redis for rate limit testing
	// Skip if Redis is not available
	rdb := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
		DB:   15, // use a high DB number for tests
	})
	defer rdb.Close()

	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		t.Skip("Redis not available, skipping rate limit test")
	}
	// Clean up test keys
	rdb.Del(ctx, "notif:rate:+628999999999")

	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"messaging_product":"whatsapp","contacts":[{"input":"628999999999","wa_id":"628999999999"}],"messages":[{"id":"msg_ok"}]}`)
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"success","data":{"message_id":"sms_ok"}}`)
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, rdb, logger)

	phone := "08999999999"

	// First 3 should succeed
	for i := 0; i < 3; i++ {
		result, err := dispatcher.SendOTP(ctx, phone, "123456")
		if err != nil {
			t.Fatalf("attempt %d: unexpected error: %v", i+1, err)
		}
		if result.Status != "sent" {
			t.Errorf("attempt %d: expected status sent, got %s", i+1, result.Status)
		}
	}

	// 4th should be rate limited
	_, err := dispatcher.SendOTP(ctx, phone, "123456")
	if err == nil {
		t.Fatal("expected rate limit error on 4th attempt, got nil")
	}
	if expected := "rate limit exceeded"; !contains(err.Error(), expected) {
		t.Errorf("expected error containing %q, got %q", expected, err.Error())
	}

	// Cleanup
	rdb.Del(ctx, "notif:rate:+628999999999", "notif:delivery:+628999999999")
}

// --- Notification channel selection tests --------------------------------------

func TestDispatcher_SendNotification_WhatsAppChannel(t *testing.T) {
	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"messaging_product":"whatsapp","contacts":[{"input":"628123456789","wa_id":"628123456789"}],"messages":[{"id":"wa_notif"}]}`)
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("SMS server should not be called when channel is whatsapp")
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, nil, logger)

	result, err := dispatcher.SendNotification(context.Background(), "08123456789", "Hello!", "whatsapp")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Channel != "whatsapp" {
		t.Errorf("expected channel whatsapp, got %s", result.Channel)
	}
}

func TestDispatcher_SendNotification_SMSChannel(t *testing.T) {
	waServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("WhatsApp server should not be called when channel is sms")
	}))
	defer waServer.Close()

	smsServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"success","data":{"message_id":"sms_notif"}}`)
	}))
	defer smsServer.Close()

	cfg := newTestConfig(waServer.URL, smsServer.URL)
	logger := newTestLogger()
	waSvc := NewWhatsAppService(cfg, logger)
	smsSvc := NewSMSService(cfg, logger)
	dispatcher := NewNotificationDispatcher(waSvc, smsSvc, nil, logger)

	result, err := dispatcher.SendNotification(context.Background(), "08123456789", "Hello!", "sms")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Channel != "sms" {
		t.Errorf("expected channel sms, got %s", result.Channel)
	}
}

// --- utility -------------------------------------------------------------------

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsSubstring(s, substr))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
