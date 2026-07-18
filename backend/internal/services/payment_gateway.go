package services

import (
	"bytes"
	"context"
	"crypto/sha512"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/sayurpintar/api/internal/config"
	"go.uber.org/zap"
)

// PaymentGateway handles Midtrans payment gateway integration.
type PaymentGateway struct {
	cfg        *config.PaymentConfig
	httpClient *http.Client
	logger     *zap.Logger
}

// NewPaymentGateway creates a new PaymentGateway.
func NewPaymentGateway(cfg *config.PaymentConfig, logger *zap.Logger) *PaymentGateway {
	return &PaymentGateway{
		cfg: cfg,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		logger: logger.Named("payment_gateway"),
	}
}

// TransactionRequest holds data for creating a Snap/QRIS transaction.
type TransactionRequest struct {
	OrderID     string         `json:"order_id"`
	GrossAmount float64        `json:"gross_amount"`
	Customer    CustomerDetail `json:"customer"`
	ItemDetails []ItemDetail   `json:"item_details"`
	PaymentType string         `json:"payment_type"` // "qris", "gopay", "bank_transfer", "credit_card"
}

// CustomerDetail holds customer info for payment.
type CustomerDetail struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Phone string `json:"phone"`
}

// ItemDetail holds a line item for payment.
type ItemDetail struct {
	ID       string  `json:"id"`
	Price    float64 `json:"price"`
	Quantity int     `json:"quantity"`
	Name     string  `json:"name"`
}

// TransactionResponse holds the result of creating a transaction.
type TransactionResponse struct {
	Token       string   `json:"token"`
	RedirectURL string   `json:"redirect_url"`
	QRCode      string   `json:"qr_code,omitempty"`
	Actions     []Action `json:"actions,omitempty"`
}

// Action represents a Midtrans action (e.g. redirect, QR code).
type Action struct {
	Name   string `json:"name"`
	Method string `json:"method"`
	URL    string `json:"url"`
}

// NotificationResult holds the parsed Midtrans webhook notification.
type NotificationResult struct {
	TransactionID string  `json:"transaction_id"`
	OrderID       string  `json:"order_id"`
	Status        string  `json:"status"` // "capture", "settlement", "pending", "deny", "cancel", "expire", "refund"
	FraudStatus   string  `json:"fraud_status"`
	Amount        float64 `json:"amount"`
}

// QRISRequest holds data for creating a QRIS payment.
type QRISRequest struct {
	OrderID     string  `json:"order_id"`
	Amount      float64 `json:"amount"`
	CallbackURL string  `json:"callback_url"`
}

// QRISResponse holds the result of creating a QRIS payment.
type QRISResponse struct {
	QRCode        string `json:"qr_code"` // base64 encoded image
	TransactionID string `json:"transaction_id"`
	ExpiryTime    string `json:"expiry_time"`
}

// midtransSnapRequest is the internal request format for Midtrans Snap API.
type midtransSnapRequest struct {
	TransactionDetails midtransTransactionDetails `json:"transaction_details"`
	CustomerDetails    *midtransCustomerDetails   `json:"customer_details,omitempty"`
	Items              []midtransItemDetail       `json:"item_details,omitempty"`
}

// midtransTransactionDetails identifies the order and amount.
type midtransTransactionDetails struct {
	OrderID     string `json:"order_id"`
	GrossAmount int64  `json:"gross_amount"`
}

// midtransCustomerDetails holds customer info for Midtrans.
type midtransCustomerDetails struct {
	FirstName string `json:"first_name"`
	Email     string `json:"email,omitempty"`
	Phone     string `json:"phone,omitempty"`
}

// midtransItemDetail is a line item for Midtrans.
type midtransItemDetail struct {
	ID       string `json:"id"`
	Price    int64  `json:"price"`
	Quantity int    `json:"quantity"`
	Name     string `json:"name"`
}

// midtransSnapResponse is the response from Midtrans Snap API.
type midtransSnapResponse struct {
	Token       string `json:"token"`
	RedirectURL string `json:"redirect_url"`
	ErrorMsg    string `json:"error_message,omitempty"`
}

// midtransNotificationPayload is the webhook payload from Midtrans.
type midtransNotificationPayload struct {
	TransactionTime   string `json:"transaction_time"`
	TransactionStatus string `json:"transaction_status"`
	TransactionID     string `json:"transaction_id"`
	StatusMessage     string `json:"status_message"`
	StatusCode        string `json:"status_code"`
	SignatureKey      string `json:"signature_key"`
	PaymentType       string `json:"payment_type"`
	OrderID           string `json:"order_id"`
	MerchantID        string `json:"merchant_id"`
	GrossAmount       string `json:"gross_amount"`
	FraudStatus       string `json:"fraud_status"`
	Currency          string `json:"currency"`
}

// midtransStatusResponse is the response from Midtrans status check.
type midtransStatusResponse struct {
	TransactionTime   string `json:"transaction_time"`
	TransactionStatus string `json:"transaction_status"`
	TransactionID     string `json:"transaction_id"`
	StatusMessage     string `json:"status_message"`
	StatusCode        string `json:"status_code"`
	PaymentType       string `json:"payment_type"`
	OrderID           string `json:"order_id"`
	GrossAmount       string `json:"gross_amount"`
	FraudStatus       string `json:"fraud_status"`
}

// midtransQRISRequest is the request body for Midtrans QRIS via e-wallet API.
type midtransQRISRequest struct {
	PaymentType        string                     `json:"payment_type"`
	TransactionDetails midtransTransactionDetails `json:"transaction_details"`
	CustomerDetails    *midtransCustomerDetails   `json:"customer_details,omitempty"`
}

// midtransQRISResponse is the response from Midtrans QRIS creation.
type midtransQRISResponse struct {
	TransactionID     string               `json:"transaction_id"`
	OrderID           string               `json:"order_id"`
	GrossAmount       string               `json:"gross_amount"`
	Currency          string               `json:"currency"`
	PaymentType       string               `json:"payment_type"`
	TransactionStatus string               `json:"transaction_status"`
	StatusMessage     string               `json:"status_message"`
	StatusCode        string               `json:"status_code"`
	Actions           []midtransQRISAction `json:"actions,omitempty"`
}

// midtransQRISAction represents an action in the QRIS response.
type midtransQRISAction struct {
	Name   string `json:"name"`
	Method string `json:"method"`
	URL    string `json:"url"`
}

// baseAPIURL returns the Midtrans API base URL based on environment.
func (g *PaymentGateway) baseAPIURL() string {
	if g.cfg.Midtrans.Environment == "production" {
		return "https://api.midtrans.com/v2"
	}
	return "https://api.sandbox.midtrans.com/v2"
}

// snapAPIURL returns the Snap API base URL.
func (g *PaymentGateway) snapAPIURL() string {
	if g.cfg.Midtrans.Environment == "production" {
		return "https://app.midtrans.com/snap/v1/transactions"
	}
	return "https://app.sandbox.midtrans.com/snap/v1/transactions"
}

// toRupiah converts a float64 amount to Midtrans integer format (no decimals).
func toRupiah(amount float64) int64 {
	return int64(amount + 0.5) // round to nearest
}

// authHeader returns the base64-encoded server key for Basic Auth.
func (g *PaymentGateway) authHeader() string {
	encoded := base64.StdEncoding.EncodeToString([]byte(g.cfg.Midtrans.ServerKey + ":"))
	return "Basic " + encoded
}

// CreateTransaction creates a Snap transaction via Midtrans Snap API.
func (g *PaymentGateway) CreateTransaction(ctx context.Context, req TransactionRequest) (*TransactionResponse, error) {
	snapReq := midtransSnapRequest{
		TransactionDetails: midtransTransactionDetails{
			OrderID:     req.OrderID,
			GrossAmount: toRupiah(req.GrossAmount),
		},
	}

	if req.Customer.Name != "" || req.Customer.Email != "" {
		snapReq.CustomerDetails = &midtransCustomerDetails{
			FirstName: req.Customer.Name,
			Email:     req.Customer.Email,
			Phone:     req.Customer.Phone,
		}
	}

	for _, item := range req.ItemDetails {
		snapReq.Items = append(snapReq.Items, midtransItemDetail{
			ID:       item.ID,
			Price:    toRupiah(item.Price),
			Quantity: item.Quantity,
			Name:     item.Name,
		})
	}

	body, err := json.Marshal(snapReq)
	if err != nil {
		return nil, fmt.Errorf("marshal snap request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, g.snapAPIURL(), bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")
	httpReq.Header.Set("Authorization", g.authHeader())

	resp, err := g.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("midtrans snap request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read snap response: %w", err)
	}

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		g.logger.Error("midtrans snap API error",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(respBody)),
			zap.String("order_id", req.OrderID))
		return nil, fmt.Errorf("midtrans snap API returned %d: %s", resp.StatusCode, string(respBody))
	}

	var snapResp midtransSnapResponse
	if err := json.Unmarshal(respBody, &snapResp); err != nil {
		return nil, fmt.Errorf("unmarshal snap response: %w", err)
	}

	if snapResp.ErrorMsg != "" {
		return nil, fmt.Errorf("midtrans snap error: %s", snapResp.ErrorMsg)
	}

	g.logger.Info("snap transaction created",
		zap.String("order_id", req.OrderID),
		zap.String("token", snapResp.Token))

	return &TransactionResponse{
		Token:       snapResp.Token,
		RedirectURL: snapResp.RedirectURL,
	}, nil
}

// HandleNotification processes a Midtrans webhook notification.
// Verifies signature using SHA-512(order_id + status_code + gross_amount + server_key).
func (g *PaymentGateway) HandleNotification(ctx context.Context, payload []byte) (*NotificationResult, error) {
	var notif midtransNotificationPayload
	if err := json.Unmarshal(payload, &notif); err != nil {
		return nil, fmt.Errorf("unmarshal notification: %w", err)
	}

	if notif.OrderID == "" {
		return nil, fmt.Errorf("notification missing order_id")
	}

	// Verify signature
	expectedSig := g.computeSignature(notif.OrderID, notif.StatusCode, notif.GrossAmount)
	if notif.SignatureKey != expectedSig {
		g.logger.Warn("invalid notification signature",
			zap.String("order_id", notif.OrderID),
			zap.String("expected", expectedSig),
			zap.String("got", notif.SignatureKey))
		return nil, fmt.Errorf("invalid signature for order %s", notif.OrderID)
	}

	// Parse gross amount
	var amount float64
	if notif.GrossAmount != "" {
		fmt.Sscanf(notif.GrossAmount, "%f", &amount)
	}

	result := &NotificationResult{
		TransactionID: notif.TransactionID,
		OrderID:       notif.OrderID,
		Status:        notif.TransactionStatus,
		FraudStatus:   notif.FraudStatus,
		Amount:        amount,
	}

	g.logger.Info("notification processed",
		zap.String("order_id", notif.OrderID),
		zap.String("status", notif.TransactionStatus),
		zap.String("fraud_status", notif.FraudStatus))

	return result, nil
}

// computeSignature generates the SHA-512 signature for Midtrans notification verification.
func (g *PaymentGateway) computeSignature(orderID, statusCode, grossAmount string) string {
	input := orderID + statusCode + grossAmount + g.cfg.Midtrans.ServerKey
	hash := sha512.Sum512([]byte(input))
	return fmt.Sprintf("%x", hash)
}

// GetTransactionStatus checks the current status of a Midtrans transaction.
func (g *PaymentGateway) GetTransactionStatus(ctx context.Context, transactionID string) (string, error) {
	url := fmt.Sprintf("%s/%s/status", g.baseAPIURL(), transactionID)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", fmt.Errorf("create http request: %w", err)
	}
	httpReq.Header.Set("Accept", "application/json")
	httpReq.Header.Set("Authorization", g.authHeader())

	resp, err := g.httpClient.Do(httpReq)
	if err != nil {
		return "", fmt.Errorf("midtrans status request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read status response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		g.logger.Error("midtrans status API error",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(respBody)),
			zap.String("transaction_id", transactionID))
		return "", fmt.Errorf("midtrans status API returned %d: %s", resp.StatusCode, string(respBody))
	}

	var statusResp midtransStatusResponse
	if err := json.Unmarshal(respBody, &statusResp); err != nil {
		return "", fmt.Errorf("unmarshal status response: %w", err)
	}

	return statusResp.TransactionStatus, nil
}

// CreateQRIS creates a QRIS payment via Midtrans e-wallet API.
func (g *PaymentGateway) CreateQRIS(ctx context.Context, req QRISRequest) (*QRISResponse, error) {
	qrisReq := midtransQRISRequest{
		PaymentType: "qris",
		TransactionDetails: midtransTransactionDetails{
			OrderID:     req.OrderID,
			GrossAmount: toRupiah(req.Amount),
		},
	}

	body, err := json.Marshal(qrisReq)
	if err != nil {
		return nil, fmt.Errorf("marshal qris request: %w", err)
	}

	url := fmt.Sprintf("%s/charge", g.baseAPIURL())
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")
	httpReq.Header.Set("Authorization", g.authHeader())

	resp, err := g.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("midtrans qris request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read qris response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		g.logger.Error("midtrans QRIS API error",
			zap.Int("status", resp.StatusCode),
			zap.String("body", string(respBody)),
			zap.String("order_id", req.OrderID))
		return nil, fmt.Errorf("midtrans QRIS API returned %d: %s", resp.StatusCode, string(respBody))
	}

	var qrisResp midtransQRISResponse
	if err := json.Unmarshal(respBody, &qrisResp); err != nil {
		return nil, fmt.Errorf("unmarshal qris response: %w", err)
	}

	// Extract QR code URL from actions
	var qrCodeURL string
	var expiryTime string
	for _, action := range qrisResp.Actions {
		if strings.Contains(action.Name, "qr") || action.Name == "generate-qr-code" {
			qrCodeURL = action.URL
			break
		}
	}

	result := &QRISResponse{
		QRCode:        qrCodeURL,
		TransactionID: qrisResp.TransactionID,
		ExpiryTime:    expiryTime,
	}

	g.logger.Info("QRIS transaction created",
		zap.String("order_id", req.OrderID),
		zap.String("transaction_id", qrisResp.TransactionID))

	return result, nil
}
