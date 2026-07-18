package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/sayurpintar/api/internal/config"
)

// WhatsAppService integrates with the WhatsApp Cloud API (Meta Business Platform).
type WhatsAppService struct {
	apiURL     string
	token      string
	phoneID    string
	httpClient *http.Client
	logger     *zap.Logger
}

// NewWhatsAppService creates a WhatsAppService from config.
func NewWhatsAppService(cfg *config.Config, logger *zap.Logger) *WhatsAppService {
	return &WhatsAppService{
		apiURL:  cfg.WhatsApp.APIURL,
		token:   cfg.WhatsApp.Token,
		phoneID: cfg.WhatsApp.PhoneID,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		logger: logger.Named("whatsapp"),
	}
}

// --- request / response helpers ------------------------------------------------

type waRequestBody struct {
	MessagingProduct string      `json:"messaging_product"`
	To               string      `json:"to"`
	Type             string      `json:"type"`
	Text             *waText     `json:"text,omitempty"`
	Template         *waTemplate `json:"template,omitempty"`
}

type waText struct {
	Body string `json:"body"`
}

type waTemplate struct {
	Name       string        `json:"name"`
	Language   waLanguage    `json:"language"`
	Components []waComponent `json:"components,omitempty"`
}

type waLanguage struct {
	Code string `json:"code"`
}

type waComponent struct {
	Type       string        `json:"type"`
	Parameters []waParameter `json:"parameters,omitempty"`
}

type waParameter struct {
	Type string `json:"type"`
	Text string `json:"text,omitempty"`
}

type waSendMessageResponse struct {
	MessagingProduct string      `json:"messaging_product"`
	Contacts         []waContact `json:"contacts"`
	Messages         []waMessage `json:"messages"`
}

type waContact struct {
	Input string `json:"input"`
	WaID  string `json:"wa_id"`
}

type waMessage struct {
	ID string `json:"id"`
}

type waErrorResponse struct {
	Error waError `json:"error"`
}

type waError struct {
	Message      string `json:"message"`
	Type         string `json:"type"`
	Code         int    `json:"code"`
	ErrorSubcode int    `json:"error_subcode"`
	FBTraceID    string `json:"fbtrace_id"`
}

type waMessageStatusResponse struct {
	ID          string `json:"id"`
	Status      string `json:"status"`
	Timestamp   string `json:"timestamp"`
	RecipientID string `json:"recipient_id"`
}

// --- helpers -------------------------------------------------------------------

// normalizePhone ensures the phone number is in international format without + prefix.
func normalizePhone(phone string) string {
	phone = strings.TrimSpace(phone)
	phone = strings.TrimPrefix(phone, "+")
	// If starts with 0, assume Indonesian number and replace with 62
	if strings.HasPrefix(phone, "0") {
		phone = "62" + phone[1:]
	}
	return phone
}

func (s *WhatsAppService) endpoint() string {
	return fmt.Sprintf("%s/%s/messages", s.apiURL, s.phoneID)
}

func (s *WhatsAppService) doRequest(ctx context.Context, body interface{}) (*http.Response, []byte, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal request body: %w", err)
	}

	s.logger.Debug("sending WhatsApp API request",
		zap.String("endpoint", s.endpoint()),
		zap.ByteString("body", payload),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.endpoint(), bytes.NewReader(payload))
	if err != nil {
		return nil, nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+s.token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		s.logger.Error("WhatsApp API request failed", zap.Error(err))
		return nil, nil, fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp, nil, fmt.Errorf("read response body: %w", err)
	}

	s.logger.Debug("WhatsApp API response",
		zap.Int("status", resp.StatusCode),
		zap.ByteString("body", respBody),
	)

	return resp, respBody, nil
}

func (s *WhatsAppService) parseSendResponse(resp *http.Response, body []byte) (string, error) {
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		var result waSendMessageResponse
		if err := json.Unmarshal(body, &result); err != nil {
			return "", fmt.Errorf("unmarshal success response: %w", err)
		}
		if len(result.Messages) == 0 {
			return "", fmt.Errorf("no message ID in response")
		}
		return result.Messages[0].ID, nil
	}

	// Handle error responses
	var errResp waErrorResponse
	if jsonErr := json.Unmarshal(body, &errResp); jsonErr != nil {
		return "", fmt.Errorf("WhatsApp API error (status %d): %s", resp.StatusCode, string(body))
	}

	switch resp.StatusCode {
	case http.StatusTooManyRequests:
		return "", fmt.Errorf("WhatsApp rate limited (429): %s", errResp.Error.Message)
	case http.StatusBadRequest:
		if errResp.Error.Code == 131026 {
			return "", fmt.Errorf("WhatsApp template not found: %s", errResp.Error.Message)
		}
		if errResp.Error.Code == 131051 || errResp.Error.Code == 131031 {
			return "", fmt.Errorf("WhatsApp invalid phone number: %s", errResp.Error.Message)
		}
		return "", fmt.Errorf("WhatsApp bad request: %s", errResp.Error.Message)
	case http.StatusUnauthorized:
		return "", fmt.Errorf("WhatsApp unauthorized: %s", errResp.Error.Message)
	default:
		return "", fmt.Errorf("WhatsApp API error (status %d, code %d): %s",
			resp.StatusCode, errResp.Error.Code, errResp.Error.Message)
	}
}

// --- public methods ------------------------------------------------------------

// SendOTP sends an OTP code via WhatsApp template message.
// Uses the "otp_verification" template with the OTP code as {{1}} parameter.
// Returns the WhatsApp message ID on success.
func (s *WhatsAppService) SendOTP(ctx context.Context, phone string, otp string) (string, error) {
	phone = normalizePhone(phone)

	body := waRequestBody{
		MessagingProduct: "whatsapp",
		To:               phone,
		Type:             "template",
		Template: &waTemplate{
			Name:     "otp_verification",
			Language: waLanguage{Code: "id"},
			Components: []waComponent{
				{
					Type: "body",
					Parameters: []waParameter{
						{Type: "text", Text: otp},
					},
				},
			},
		},
	}

	s.logger.Info("sending OTP via WhatsApp",
		zap.String("phone", phone),
		zap.String("otp_length", fmt.Sprintf("%d", len(otp))),
	)

	resp, respBody, err := s.doRequest(ctx, body)
	if err != nil {
		return "", err
	}
	return s.parseSendResponse(resp, respBody)
}

// SendNotification sends a plain text message via WhatsApp.
// Used for reminders, order updates, etc.
func (s *WhatsAppService) SendNotification(ctx context.Context, phone string, message string) (string, error) {
	phone = normalizePhone(phone)

	body := waRequestBody{
		MessagingProduct: "whatsapp",
		To:               phone,
		Type:             "text",
		Text:             &waText{Body: message},
	}

	s.logger.Info("sending notification via WhatsApp",
		zap.String("phone", phone),
		zap.Int("message_length", len(message)),
	)

	resp, respBody, err := s.doRequest(ctx, body)
	if err != nil {
		return "", err
	}
	return s.parseSendResponse(resp, respBody)
}

// SendTemplateMessage sends a template-based message with the given parameters.
// For structured notifications like order confirmation, debt reminders, etc.
func (s *WhatsAppService) SendTemplateMessage(ctx context.Context, phone string, templateName string, params []string) (string, error) {
	phone = normalizePhone(phone)

	parameters := make([]waParameter, len(params))
	for i, p := range params {
		parameters[i] = waParameter{Type: "text", Text: p}
	}

	body := waRequestBody{
		MessagingProduct: "whatsapp",
		To:               phone,
		Type:             "template",
		Template: &waTemplate{
			Name:     templateName,
			Language: waLanguage{Code: "id"},
			Components: []waComponent{
				{
					Type:       "body",
					Parameters: parameters,
				},
			},
		},
	}

	s.logger.Info("sending template message via WhatsApp",
		zap.String("phone", phone),
		zap.String("template", templateName),
		zap.Int("param_count", len(params)),
	)

	resp, respBody, err := s.doRequest(ctx, body)
	if err != nil {
		return "", err
	}
	return s.parseSendResponse(resp, respBody)
}

// GetMessageStatus checks the delivery status of a previously sent message.
func (s *WhatsAppService) GetMessageStatus(ctx context.Context, messageID string) (string, error) {
	url := fmt.Sprintf("%s/%s?fields=status", s.apiURL, messageID)

	s.logger.Debug("checking WhatsApp message status",
		zap.String("message_id", messageID),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("WhatsApp API error (status %d): %s", resp.StatusCode, string(body))
	}

	var statusResp waMessageStatusResponse
	if err := json.Unmarshal(body, &statusResp); err != nil {
		return "", fmt.Errorf("unmarshal status response: %w", err)
	}

	return statusResp.Status, nil
}
