package services

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/sayurpintar/api/internal/config"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// PaymentRequest is the input for creating a payment.
type PaymentRequest struct {
	OrderID       string  `json:"order_id"`
	DebtID        string  `json:"debt_id,omitempty"`
	Amount        float64 `json:"amount"`
	Method        string  `json:"method"` // "qris", "ewallet", "bank_transfer"
	CustomerName  string  `json:"customer_name"`
	CustomerPhone string  `json:"customer_phone"`
	Description   string  `json:"description"`
}

// PaymentResponse is the output after creating a payment.
type PaymentResponse struct {
	PaymentURL     string `json:"payment_url,omitempty"`
	QRCode         string `json:"qr_code,omitempty"`
	VirtualAccount string `json:"virtual_account,omitempty"`
	ExpiryTime     string `json:"expiry_time"`
	GatewayTxID    string `json:"gateway_tx_id"`
	TransactionID  string `json:"transaction_id"`
}

// PaymentService handles payment gateway integration (Midtrans & Xendit).
type PaymentService struct {
	cfg        *config.PaymentConfig
	transRepo  repository.TransactionRepository
	debtRepo   repository.DebtRepository
	userRepo   repository.UserRepository
	debtSvc    *DebtService
	httpClient *http.Client
	logger     *zap.Logger
}

// NewPaymentService creates a new PaymentService.
func NewPaymentService(
	cfg *config.PaymentConfig,
	transRepo repository.TransactionRepository,
	debtRepo repository.DebtRepository,
	userRepo repository.UserRepository,
	debtSvc *DebtService,
	logger *zap.Logger,
) *PaymentService {
	return &PaymentService{
		cfg:       cfg,
		transRepo: transRepo,
		debtRepo:  debtRepo,
		userRepo:  userRepo,
		debtSvc:   debtSvc,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		logger: logger.Named("payment_service"),
	}
}

// CreatePaymentRequest creates a payment request via the appropriate gateway.
func (s *PaymentService) CreatePaymentRequest(ctx context.Context, req PaymentRequest) (*PaymentResponse, error) {
	// Create a pending transaction
	txn := &models.Transaction{
		PedagangID:    uuid.Nil, // Will be set from order/debt context
		Type:          models.TxnTypePayment,
		Amount:        req.Amount,
		PaymentMethod: models.PaymentMethod(req.Method),
		Status:        models.TxnStatusPending,
	}

	// If linked to a debt, get the pedagang_id
	if req.DebtID != "" {
		debt, err := s.debtRepo.GetByID(ctx, req.DebtID)
		if err != nil {
			return nil, fmt.Errorf("get debt: %w", err)
		}
		txn.PedagangID = debt.PedagangID
		txn.PelangganID = &debt.PelangganID
		debtID := uuid.MustParse(req.DebtID)
		txn.DebtID = &debtID
	}

	if err := s.transRepo.Create(ctx, txn); err != nil {
		return nil, fmt.Errorf("create transaction: %w", err)
	}

	// Generate a unique order ID for the gateway
	gatewayOrderID := fmt.Sprintf("SP-%s-%d", txn.ID.String()[:8], time.Now().Unix())

	var resp *PaymentResponse
	var gatewayErr error

	// Route to appropriate gateway based on method
	switch req.Method {
	case "qris":
		resp, gatewayErr = s.createMidtransQRIS(ctx, gatewayOrderID, req)
	case "ewallet":
		resp, gatewayErr = s.createXenditEWallet(ctx, gatewayOrderID, req)
	case "bank_transfer":
		resp, gatewayErr = s.createMidtransBankTransfer(ctx, gatewayOrderID, req)
	default:
		// Default to Midtrans QRIS
		resp, gatewayErr = s.createMidtransQRIS(ctx, gatewayOrderID, req)
	}

	if gatewayErr != nil {
		// Mark transaction as failed
		s.logger.Error("payment gateway error",
			zap.String("transaction_id", txn.ID.String()),
			zap.String("method", req.Method),
			zap.Error(gatewayErr))
		return nil, fmt.Errorf("payment gateway error: %w", gatewayErr)
	}

	// Update transaction with gateway info
	gatewayTxID := resp.GatewayTxID
	txn.GatewayTransactionID = &gatewayTxID
	gatewayStatus := "pending"
	txn.GatewayStatus = &gatewayStatus

	s.logger.Info("payment request created",
		zap.String("transaction_id", txn.ID.String()),
		zap.String("gateway_tx_id", resp.GatewayTxID),
		zap.String("method", req.Method),
		zap.Float64("amount", req.Amount))

	resp.TransactionID = txn.ID.String()
	return resp, nil
}

// HandleWebhook processes payment gateway callbacks.
func (s *PaymentService) HandleWebhook(ctx context.Context, provider string, payload []byte, signature string) error {
	switch provider {
	case "midtrans":
		return s.handleMidtransWebhook(ctx, payload)
	case "xendit":
		return s.handleXenditWebhook(ctx, payload, signature)
	default:
		return fmt.Errorf("unsupported payment provider: %s", provider)
	}
}

// CheckStatus checks payment status with the gateway.
func (s *PaymentService) CheckStatus(ctx context.Context, gatewayTxID string) (string, error) {
	// Try Midtrans first
	if s.cfg.Midtrans.ServerKey != "" {
		status, err := s.checkMidtransStatus(ctx, gatewayTxID)
		if err == nil {
			return status, nil
		}
		s.logger.Warn("midtrans status check failed", zap.Error(err))
	}

	// Try Xendit
	if s.cfg.Xendit.SecretKey != "" {
		status, err := s.checkXenditStatus(ctx, gatewayTxID)
		if err == nil {
			return status, nil
		}
		s.logger.Warn("xendit status check failed", zap.Error(err))
	}

	return "", fmt.Errorf("unable to check status for gateway tx: %s", gatewayTxID)
}

// GenerateInvoice creates a simple text-based invoice for an order.
func (s *PaymentService) GenerateInvoice(ctx context.Context, orderID string) ([]byte, error) {
	// Find the transaction for this order
	txns, err := s.transRepo.ListByPedagang(ctx, "", "", "")
	if err != nil {
		return nil, fmt.Errorf("list transactions: %w", err)
	}

	var txn *models.Transaction
	for _, t := range txns {
		if t.OrderID != nil && t.OrderID.String() == orderID {
			txn = &t
			break
		}
	}
	if txn == nil {
		return nil, fmt.Errorf("no transaction found for order %s", orderID)
	}

	invoice := fmt.Sprintf(
		"========================================\n"+
			"         SAYURPINTAR - INVOICE\n"+
			"========================================\n\n"+
			"Invoice ID : INV-%s\n"+
			"Order ID   : %s\n"+
			"Date       : %s\n"+
			"Status     : %s\n"+
			"Method     : %s\n"+
			"----------------------------------------\n"+
			"TOTAL      : Rp %.0f\n"+
			"========================================\n\n"+
			"Terima kasih telah berbelanja di SayurPintar!\n",
		txn.ID.String()[:8],
		orderID,
		txn.CreatedAt.Format("02 January 2006 15:04"),
		txn.Status,
		txn.PaymentMethod,
		txn.Amount,
	)

	return []byte(invoice), nil
}

// --- Midtrans Integration ---

type midtransChargeRequest struct {
	PaymentType  string            `json:"payment_type"`
	Transaction  midtransTxDetail  `json:"transaction_details"`
	Customer     *midtransCustomer `json:"customer_details,omitempty"`
	QRIS         *midtransQRIS     `json:"qris,omitempty"`
	BankTransfer *midtransBank     `json:"bank_transfer,omitempty"`
}

type midtransTxDetail struct {
	OrderID  string  `json:"order_id"`
	GrossAmt float64 `json:"gross_amount"`
}

type midtransCustomer struct {
	FirstName string `json:"first_name"`
	Phone     string `json:"phone"`
}

type midtransQRIS struct {
}

type midtransBank struct {
	Bank string `json:"bank"`
}

type midtransChargeResponse struct {
	TransactionID string `json:"transaction_id"`
	OrderID       string `json:"order_id"`
	Status        string `json:"status_code"`
	Actions       []struct {
		Name   string `json:"name"`
		Method string `json:"method"`
		URL    string `json:"url"`
	} `json:"actions"`
	QRCode string `json:"qr_string,omitempty"`
	VANum  string `json:"va_numbers,omitempty"`
}

func (s *PaymentService) createMidtransQRIS(ctx context.Context, orderID string, req PaymentRequest) (*PaymentResponse, error) {
	chargeReq := midtransChargeRequest{
		PaymentType: "qris",
		Transaction: midtransTxDetail{
			OrderID:  orderID,
			GrossAmt: req.Amount,
		},
		Customer: &midtransCustomer{
			FirstName: req.CustomerName,
			Phone:     req.CustomerPhone,
		},
		QRIS: &midtransQRIS{},
	}

	body, err := json.Marshal(chargeReq)
	if err != nil {
		return nil, fmt.Errorf("marshal charge request: %w", err)
	}

	baseURL := "https://api.sandbox.midtrans.com"
	if s.cfg.Midtrans.Environment == "production" {
		baseURL = "https://api.midtrans.com"
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", baseURL+"/v2/charge", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.SetBasicAuth(s.cfg.Midtrans.ServerKey, "")
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")

	httpResp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("midtrans request: %w", err)
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		return nil, fmt.Errorf("midtrans error (status %d): %s", httpResp.StatusCode, string(respBody))
		var errResp struct {
			Message string `json:"error_message"`
		}
		json.Unmarshal(respBody, &errResp)
		if errResp.Message != "" {
			return nil, fmt.Errorf("midtrans: %s", errResp.Message)
		}
		return nil, fmt.Errorf("midtrans returned status %d", httpResp.StatusCode)
	}

	var chargeResp midtransChargeResponse
	if err := json.Unmarshal(respBody, &chargeResp); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}

	resp := &PaymentResponse{
		GatewayTxID: chargeResp.TransactionID,
		ExpiryTime:  time.Now().Add(15 * time.Minute).Format(time.RFC3339),
	}

	if chargeResp.QRCode != "" {
		resp.QRCode = chargeResp.QRCode
	}
	for _, action := range chargeResp.Actions {
		if action.Name == "generate-qr-code" || action.Name == "qr-code" {
			resp.PaymentURL = action.URL
			break
		}
	}

	return resp, nil
}

func (s *PaymentService) createMidtransBankTransfer(ctx context.Context, orderID string, req PaymentRequest) (*PaymentResponse, error) {
	chargeReq := midtransChargeRequest{
		PaymentType: "bank_transfer",
		Transaction: midtransTxDetail{
			OrderID:  orderID,
			GrossAmt: req.Amount,
		},
		Customer: &midtransCustomer{
			FirstName: req.CustomerName,
			Phone:     req.CustomerPhone,
		},
		BankTransfer: &midtransBank{
			Bank: "bca",
		},
	}

	body, err := json.Marshal(chargeReq)
	if err != nil {
		return nil, fmt.Errorf("marshal charge request: %w", err)
	}

	baseURL := "https://api.sandbox.midtrans.com"
	if s.cfg.Midtrans.Environment == "production" {
		baseURL = "https://api.midtrans.com"
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST", baseURL+"/v2/charge", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.SetBasicAuth(s.cfg.Midtrans.ServerKey, "")
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("midtrans request: %w", err)
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		return nil, fmt.Errorf("midtrans error (status %d): %s", httpResp.StatusCode, string(respBody))
	}

	var chargeResp midtransChargeResponse
	if err := json.Unmarshal(respBody, &chargeResp); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}

	resp := &PaymentResponse{
		GatewayTxID: chargeResp.TransactionID,
		ExpiryTime:  time.Now().Add(24 * time.Hour).Format(time.RFC3339),
	}

	return resp, nil
}

func (s *PaymentService) checkMidtransStatus(ctx context.Context, txID string) (string, error) {
	baseURL := "https://api.sandbox.midtrans.com"
	if s.cfg.Midtrans.Environment == "production" {
		baseURL = "https://api.midtrans.com"
	}

	httpReq, err := http.NewRequestWithContext(ctx, "GET", baseURL+"/v2/"+txID+"/status", nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	httpReq.SetBasicAuth(s.cfg.Midtrans.ServerKey, "")

	httpResp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return "", fmt.Errorf("midtrans request: %w", err)
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		return "", fmt.Errorf("midtrans status error: %d", httpResp.StatusCode)
	}

	var statusResp struct {
		TransactionStatus string `json:"transaction_status"`
	}
	if err := json.Unmarshal(respBody, &statusResp); err != nil {
		return "", fmt.Errorf("unmarshal: %w", err)
	}

	switch statusResp.TransactionStatus {
	case "capture", "settlement":
		return "completed", nil
	case "pending":
		return "pending", nil
	case "deny", "cancel", "expire":
		return "failed", nil
	case "refund":
		return "refunded", nil
	default:
		return statusResp.TransactionStatus, nil
	}
}

func (s *PaymentService) handleMidtransWebhook(ctx context.Context, payload []byte) error {
	var notif struct {
		TransactionStatus string `json:"transaction_status"`
		OrderID           string `json:"order_id"`
		TransactionID     string `json:"transaction_id"`
		PaymentType       string `json:"payment_type"`
	}
	if err := json.Unmarshal(payload, &notif); err != nil {
		return fmt.Errorf("unmarshal webhook: %w", err)
	}

	s.logger.Info("midtrans webhook received",
		zap.String("order_id", notif.OrderID),
		zap.String("status", notif.TransactionStatus))

	// Map Midtrans status to our status
	var status string
	switch notif.TransactionStatus {
	case "capture", "settlement":
		status = "completed"
	case "pending":
		status = "pending"
	case "deny", "cancel", "expire":
		status = "failed"
	case "refund":
		status = "refunded"
	default:
		status = notif.TransactionStatus
	}

	// Find the transaction by gateway_transaction_id and update
	// For now, log the status change. Full implementation would
	// update the transaction and trigger debt payment if applicable.
	s.logger.Info("midtrans payment status update",
		zap.String("gateway_tx_id", notif.TransactionID),
		zap.String("status", status),
		zap.String("payment_type", notif.PaymentType))

	return nil
}

// --- Xendit Integration ---

type xenditEWalletRequest struct {
	ExternalID  string  `json:"external_id"`
	Amount      float64 `json:"amount"`
	Phone       string  `json:"phone"`
	CallbackURL string  `json:"callback_url"`
	ChannelCode string  `json:"channel_code"` // "ID_OVO", "ID_DANA", "ID_LINKAJA"
}

type xenditEWalletResponse struct {
	ID          string `json:"id"`
	ExternalID  string `json:"external_id"`
	Status      string `json:"status"`
	CallbackURL string `json:"callback_url"`
	Actions     struct {
		MobileURL  string `json:"mobile_url"`
		DesktopURL string `json:"desktop_url"`
	} `json:"actions"`
}

func (s *PaymentService) createXenditEWallet(ctx context.Context, orderID string, req PaymentRequest) (*PaymentResponse, error) {
	ewalletReq := xenditEWalletRequest{
		ExternalID:  orderID,
		Amount:      req.Amount,
		Phone:       req.CustomerPhone,
		CallbackURL: s.cfg.Xendit.CallbackURL,
		ChannelCode: "ID_OVO",
	}

	body, err := json.Marshal(ewalletReq)
	if err != nil {
		return nil, fmt.Errorf("marshal ewallet request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, "POST",
		"https://api.xendit.com/ewallets/charges", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	httpReq.SetBasicAuth(s.cfg.Xendit.SecretKey, "")
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("xendit request: %w", err)
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		return nil, fmt.Errorf("xendit error (status %d): %s", httpResp.StatusCode, string(respBody))
	}

	var ewalletResp xenditEWalletResponse
	if err := json.Unmarshal(respBody, &ewalletResp); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}

	paymentURL := ewalletResp.Actions.MobileURL
	if paymentURL == "" {
		paymentURL = ewalletResp.Actions.DesktopURL
	}

	return &PaymentResponse{
		PaymentURL:  paymentURL,
		GatewayTxID: ewalletResp.ID,
		ExpiryTime:  time.Now().Add(15 * time.Minute).Format(time.RFC3339),
	}, nil
}

func (s *PaymentService) checkXenditStatus(ctx context.Context, txID string) (string, error) {
	httpReq, err := http.NewRequestWithContext(ctx, "GET",
		"https://api.xendit.com/ewallets/charges/"+txID, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	httpReq.SetBasicAuth(s.cfg.Xendit.SecretKey, "")

	httpResp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return "", fmt.Errorf("xendit request: %w", err)
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		return "", fmt.Errorf("xendit status error: %d", httpResp.StatusCode)
	}

	var statusResp struct {
		Status string `json:"status"`
	}
	if err := json.Unmarshal(respBody, &statusResp); err != nil {
		return "", fmt.Errorf("unmarshal: %w", err)
	}

	switch statusResp.Status {
	case "SUCCEEDED":
		return "completed", nil
	case "PENDING":
		return "pending", nil
	case "FAILED":
		return "failed", nil
	default:
		return statusResp.Status, nil
	}
}

func (s *PaymentService) handleXenditWebhook(ctx context.Context, payload []byte, signature string) error {
	// Verify HMAC signature
	if s.cfg.Xendit.SecretKey != "" {
		mac := hmac.New(sha256.New, []byte(s.cfg.Xendit.SecretKey))
		mac.Write(payload)
		expectedSig := hex.EncodeToString(mac.Sum(nil))
		if signature != expectedSig {
			return fmt.Errorf("invalid xendit webhook signature")
		}
	}

	var notif struct {
		ID         string `json:"id"`
		ExternalID string `json:"external_id"`
		Status     string `json:"status"`
	}
	if err := json.Unmarshal(payload, &notif); err != nil {
		return fmt.Errorf("unmarshal webhook: %w", err)
	}

	s.logger.Info("xendit webhook received",
		zap.String("id", notif.ID),
		zap.String("external_id", notif.ExternalID),
		zap.String("status", notif.Status))

	return nil
}
