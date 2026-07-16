package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jung-kurt/gofpdf"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// InvoiceService generates PDF invoices for orders.
type InvoiceService struct {
	orderRepo repository.OrderRepository
	logger    *zap.Logger
}

// NewInvoiceService creates a new InvoiceService.
func NewInvoiceService(orderRepo repository.OrderRepository, logger *zap.Logger) *InvoiceService {
	return &InvoiceService{
		orderRepo: orderRepo,
		logger:    logger.Named("invoice_service"),
	}
}

// InvoiceData holds all data needed to generate an invoice PDF.
type InvoiceData struct {
	InvoiceNumber string
	Date          string
	OrderID       string
	PedagangName  string
	PedagangPhone string
	PelangganName string
	PelangganAddr string
	Items         []InvoiceItem
	Subtotal      float64
	Total         float64
	PaymentMethod string
	PaymentStatus string
	Notes         string
}

// InvoiceItem represents a single line item on an invoice.
type InvoiceItem struct {
	Name     string
	Qty      float64
	Unit     string
	Price    float64
	Subtotal float64
}

// GenerateInvoice creates a PDF invoice for the given order ID.
func (s *InvoiceService) GenerateInvoice(ctx context.Context, orderID string) ([]byte, error) {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return nil, fmt.Errorf("get order: %w", err)
	}

	// Parse order items
	var orderItems []struct {
		ProductID string  `json:"product_id"`
		Name      string  `json:"nama"`
		Qty       float64 `json:"qty"`
		Unit      string  `json:"satuan"`
		Price     float64 `json:"harga"`
		Subtotal  float64 `json:"subtotal"`
	}
	if err := json.Unmarshal(order.Items, &orderItems); err != nil {
		s.logger.Warn("failed to parse order items, using empty list", zap.Error(err))
	}

	var items []InvoiceItem
	for _, item := range orderItems {
		items = append(items, InvoiceItem{
			Name:     item.Name,
			Qty:      item.Qty,
			Unit:     item.Unit,
			Price:    item.Price,
			Subtotal: item.Subtotal,
		})
	}

	pelangganName := order.PelangganName
	if pelangganName == "" {
		pelangganName = "Pelanggan"
	}

	pelangganAddr := order.PelangganAddr
	if pelangganAddr == "" {
		pelangganAddr = "-"
	}

	notes := ""
	if order.DeliveryNotes != nil {
		notes = *order.DeliveryNotes
	}

	invoiceNumber := fmt.Sprintf("INV-%s-%s", time.Now().Format("20060102"), orderID[:8])

	data := InvoiceData{
		InvoiceNumber: invoiceNumber,
		Date:          time.Now().Format("02 January 2006"),
		OrderID:       orderID,
		PedagangName:  "SayurPintar",
		PedagangPhone: "",
		PelangganName: pelangganName,
		PelangganAddr: pelangganAddr,
		Items:         items,
		Subtotal:      order.TotalPrice,
		Total:         order.TotalPrice,
		PaymentMethod: order.PaymentMethod,
		PaymentStatus: order.PaymentStatus,
		Notes:         notes,
	}

	pdfBytes, err := s.GeneratePDF(data)
	if err != nil {
		return nil, fmt.Errorf("generate pdf: %w", err)
	}

	s.logger.Info("invoice generated",
		zap.String("order_id", orderID),
		zap.String("invoice_number", invoiceNumber),
		zap.Int("bytes", len(pdfBytes)))

	return pdfBytes, nil
}

// GeneratePDF creates the actual PDF document from invoice data.
func (s *InvoiceService) GeneratePDF(data InvoiceData) ([]byte, error) {
	pdf := gofpdf.New("P", "mm", "A4", "")
	pdf.SetAutoPageBreak(true, 20)
	pdf.AddPage()

	// ── Header ──
	pdf.SetFont("Helvetica", "B", 20)
	pdf.Cell(0, 12, "INVOICE")
	pdf.Ln(16)

	// Invoice info
	pdf.SetFont("Helvetica", "", 10)
	pdf.CellFormat(95, 6, fmt.Sprintf("No. Invoice: %s", data.InvoiceNumber), "", 0, "L", false, 0, "")
	pdf.CellFormat(95, 6, fmt.Sprintf("Tanggal: %s", data.Date), "", 1, "R", false, 0, "")
	pdf.CellFormat(95, 6, fmt.Sprintf("Order ID: %s", data.OrderID), "", 0, "L", false, 0, "")
	pdf.CellFormat(95, 6, fmt.Sprintf("Status: %s", data.PaymentStatus), "", 1, "R", false, 0, "")
	pdf.Ln(6)

	// ── From / To ──
	pdf.SetFont("Helvetica", "B", 11)
	pdf.CellFormat(95, 7, "Dari:", "", 0, "L", false, 0, "")
	pdf.CellFormat(95, 7, "Kepada:", "", 1, "L", false, 0, "")

	pdf.SetFont("Helvetica", "", 10)
	pdf.CellFormat(95, 6, data.PedagangName, "", 0, "L", false, 0, "")
	pdf.CellFormat(95, 6, data.PelangganName, "", 1, "L", false, 0, "")
	if data.PedagangPhone != "" {
		pdf.CellFormat(95, 6, data.PedagangPhone, "", 0, "L", false, 0, "")
	}
	pdf.CellFormat(95, 6, data.PelangganAddr, "", 1, "L", false, 0, "")
	pdf.Ln(8)

	// ── Items Table ──
	// Column widths: Name=70, Qty=20, Unit=20, Price=40, Subtotal=40 = 190
	colW := []float64{70, 20, 20, 40, 40}
	headers := []string{"Item", "Qty", "Satuan", "Harga", "Subtotal"}

	// Table header
	pdf.SetFillColor(41, 128, 185)
	pdf.SetTextColor(255, 255, 255)
	pdf.SetFont("Helvetica", "B", 10)
	for i, h := range headers {
		pdf.CellFormat(colW[i], 8, h, "1", 0, "C", true, 0, "")
	}
	pdf.Ln(-1)

	// Table rows
	pdf.SetTextColor(0, 0, 0)
	pdf.SetFont("Helvetica", "", 10)
	for i, item := range data.Items {
		if i%2 == 0 {
			pdf.SetFillColor(245, 245, 245)
		} else {
			pdf.SetFillColor(255, 255, 255)
		}

		name := item.Name
		if len(name) > 35 {
			name = name[:32] + "..."
		}

		pdf.CellFormat(colW[0], 7, name, "1", 0, "L", true, 0, "")
		pdf.CellFormat(colW[1], 7, fmt.Sprintf("%.1f", item.Qty), "1", 0, "C", true, 0, "")
		pdf.CellFormat(colW[2], 7, item.Unit, "1", 0, "C", true, 0, "")
		pdf.CellFormat(colW[3], 7, formatRupiah(item.Price), "1", 0, "R", true, 0, "")
		pdf.CellFormat(colW[4], 7, formatRupiah(item.Subtotal), "1", 0, "R", true, 0, "")
		pdf.Ln(-1)
	}

	if len(data.Items) == 0 {
		pdf.SetFillColor(255, 255, 255)
		pdf.CellFormat(190, 7, "Tidak ada item", "1", 0, "C", true, 0, "")
		pdf.Ln(-1)
	}

	pdf.Ln(4)

	// ── Totals ──
	totalW := colW[3] + colW[4]
	offsetX := colW[0] + colW[1] + colW[2]

	pdf.SetFont("Helvetica", "", 10)
	pdf.CellFormat(offsetX, 7, "", 0, 0, "L", false, 0, "")
	pdf.CellFormat(colW[3], 7, "Subtotal:", "1", 0, "R", false, 0, "")
	pdf.CellFormat(colW[4], 7, formatRupiah(data.Subtotal), "1", 0, "R", false, 0, "")
	pdf.Ln(-1)

	pdf.SetFont("Helvetica", "B", 11)
	pdf.SetFillColor(41, 128, 185)
	pdf.SetTextColor(255, 255, 255)
	pdf.CellFormat(offsetX, 8, "", 0, 0, "L", false, 0, "")
	pdf.CellFormat(colW[3], 8, "TOTAL:", "1", 0, "R", true, 0, "")
	pdf.CellFormat(colW[4], 8, formatRupiah(data.Total), "1", 0, "R", true, 0, "")
	pdf.Ln(-1)
	pdf.SetTextColor(0, 0, 0)

	pdf.Ln(8)

	// ── Payment Info ──
	if data.PaymentMethod != "" {
		pdf.SetFont("Helvetica", "B", 10)
		pdf.Cell(0, 6, fmt.Sprintf("Metode Pembayaran: %s", data.PaymentMethod))
		pdf.Ln(8)
	}

	// ── Notes ──
	if data.Notes != "" {
		pdf.SetFont("Helvetica", "B", 10)
		pdf.Cell(0, 6, "Catatan:")
		pdf.Ln(6)
		pdf.SetFont("Helvetica", "", 10)
		pdf.MultiCell(0, 5, data.Notes, "", "L", false)
		pdf.Ln(4)
	}

	// ── Footer ──
	pdf.Ln(10)
	pdf.SetFont("Helvetica", "I", 9)
	pdf.Cell(0, 6, "Terima kasih telah berbelanja di SayurPintar!")
	pdf.Ln(6)
	pdf.Cell(0, 6, fmt.Sprintf("Dicetak pada: %s", time.Now().Format("02 Jan 2006 15:04:05")))

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, fmt.Errorf("output pdf: %w", err)
	}

	return buf.Bytes(), nil
}

// formatRupiah formats a float64 as a Rupiah string.
func formatRupiah(amount float64) string {
	n := int64(amount + 0.5)
	if n < 0 {
		return "-" + formatRupiahPositive(-n)
	}
	return formatRupiahPositive(n)
}

func formatRupiahPositive(n int64) string {
	if n < 1000 {
		return fmt.Sprintf("%d", n)
	}
	return formatRupiahPositive(n/1000) + "." + fmt.Sprintf("%03d", n%1000)
}
