package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/sayurpintar/api/internal/config"
)

// SMSService provides a generic HTTP-based SMS gateway interface.
// Works with common Indonesian SMS gateways (Nusasms, Zenziva, Raja SMS, etc.)
type SMSService struct {
	apiURL     string
	apiKey     string
	sender     string
	httpClient *http.Client
	logger     *zap.Logger
}

// NewSMSService creates an SMSService from config.
func NewSMSService(cfg *config.Config, logger *zap.Logger) *SMSService {
	return &SMSService{
		apiURL: cfg.SMS.APIURL,
		apiKey: cfg.SMS.APIKey,
		sender: cfg.SMS.Sender,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		logger: logger.Named("sms"),
	}
}

// --- request / response helpers ------------------------------------------------

// smsRequest represents a generic SMS gateway request.
// Most Indonesian gateways accept JSON or form-encoded payloads.
type smsRequest struct {
	Phone    string `json:"phone"`
	Message  string `json:"message"`
	Sender   string `json:"sender,omitempty"`
	APIKey   string `json:"api_key,omitempty"`
}

// smsResponse represents a generic SMS gateway response.
type smsResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	Data    struct {
		MessageID string `json:"message_id,omitempty"`
	} `json:"data,omitempty"`
	// Some gateways use different field names
	ID      string `json:"id,omitempty"`
	Error   string `json:"error,omitempty"`
}

// --- helpers -------------------------------------------------------------------

func normalizeSMSPhone(phone string) string {
	phone = strings.TrimSpace(phone)
	phone = strings.TrimPrefix(phone, "+")
	if strings.HasPrefix(phone, "0") {
		phone = "62" + phone[1:]
	}
	return phone
}

func (s *SMSService) doRequest(ctx context.Context, phone string, message string) (string, error) {
	// Build request payload as form-encoded (most Indonesian gateways prefer this)
	form := url.Values{}
	form.Set("phone", phone)
	form.Set("message", message)
	form.Set("sender", s.sender)
	form.Set("api_key", s.apiKey)

	endpoint := s.apiURL

	s.logger.Debug("sending SMS request",
		zap.String("endpoint", endpoint),
		zap.String("phone", phone),
		zap.Int("message_length", len(message)),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		s.logger.Error("SMS gateway request failed", zap.Error(err))
		return "", fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response body: %w", err)
	}

	s.logger.Debug("SMS gateway response",
		zap.Int("status", resp.StatusCode),
		zap.ByteString("body", body),
	)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("SMS gateway error (status %d): %s", resp.StatusCode, string(body))
	}

	// Try to parse JSON response for message ID
	var smsResp smsResponse
	if jsonErr := json.Unmarshal(body, &smsResp); jsonErr == nil {
		if smsResp.Error != "" {
			return "", fmt.Errorf("SMS gateway error: %s", smsResp.Error)
		}
		if smsResp.Data.MessageID != "" {
			return smsResp.Data.MessageID, nil
		}
		if smsResp.ID != "" {
			return smsResp.ID, nil
		}
	}

	// Fallback: also try JSON with the raw body as a generic struct
	var raw map[string]interface{}
	if jsonErr := json.Unmarshal(body, &raw); jsonErr == nil {
		if errMsg, ok := raw["error"].(string); ok && errMsg != "" {
			return "", fmt.Errorf("SMS gateway error: %s", errMsg)
		}
	}

	return fmt.Sprintf("sms_%s_%d", phone, time.Now().UnixMilli()), nil
}

// --- public methods ------------------------------------------------------------

// SendOTP sends an OTP code via SMS.
// Message format: "Kode verifikasi SayurPintar Anda: {otp}. Berlaku 5 menit."
func (s *SMSService) SendOTP(ctx context.Context, phone string, otp string) (string, error) {
	phone = normalizeSMSPhone(phone)
	message := fmt.Sprintf("Kode verifikasi SayurPintar Anda: %s. Berlaku 5 menit.", otp)

	s.logger.Info("sending OTP via SMS",
		zap.String("phone", phone),
		zap.String("otp_length", fmt.Sprintf("%d", len(otp))),
	)

	return s.doRequest(ctx, phone, message)
}

// SendNotification sends a generic text message via SMS.
func (s *SMSService) SendNotification(ctx context.Context, phone string, message string) (string, error) {
	phone = normalizeSMSPhone(phone)

	s.logger.Info("sending notification via SMS",
		zap.String("phone", phone),
		zap.Int("message_length", len(message)),
	)

	return s.doRequest(ctx, phone, message)
}
