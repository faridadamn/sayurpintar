package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/sayurpintar/api/internal/models"
	"github.com/sayurpintar/api/internal/repository"
	"go.uber.org/zap"
)

// DebtorStat holds aggregate stats for a single debtor.
type DebtorStat struct {
	PelangganID   string  `json:"pelanggan_id"`
	PelangganName string  `json:"pelanggan_name"`
	TotalDebt     float64 `json:"total_debt"`
	DebtCount     int     `json:"debt_count"`
	OldestDays    int     `json:"oldest_days"`
}

// DebtSummary holds piutang summary for a pedagang.
type DebtSummary struct {
	TotalOutstanding float64      `json:"total_outstanding"`
	DebtCount        int          `json:"debt_count"`
	OverdueCount     int          `json:"overdue_count"`
	OldestDebtDays   int          `json:"oldest_debt_days"`
	TopDebtors       []DebtorStat `json:"top_debtors"`
}

// DebtService orchestrates debt (piutang) operations.
type DebtService struct {
	debtRepo     repository.DebtRepository
	orderRepo    repository.OrderRepository
	transRepo    repository.TransactionRepository
	userRepo     repository.UserRepository
	notifService *NotificationService
	notifDisp    *NotificationDispatcher
	logger       *zap.Logger
}

// NewDebtService creates a new DebtService.
func NewDebtService(
	debtRepo repository.DebtRepository,
	orderRepo repository.OrderRepository,
	transRepo repository.TransactionRepository,
	userRepo repository.UserRepository,
	notifService *NotificationService,
	notifDisp *NotificationDispatcher,
	logger *zap.Logger,
) *DebtService {
	return &DebtService{
		debtRepo:     debtRepo,
		orderRepo:    orderRepo,
		transRepo:    transRepo,
		userRepo:     userRepo,
		notifService: notifService,
		notifDisp:    notifDisp,
		logger:       logger.Named("debt_service"),
	}
}

// CreateDebt records a new debt (piutang).
func (s *DebtService) CreateDebt(ctx context.Context, pedagangID, pelangganID, orderID string, amount float64, dueDate *time.Time) (*models.Debt, error) {
	debt := &models.Debt{
		PedagangID:  uuid.MustParse(pedagangID),
		PelangganID: uuid.MustParse(pelangganID),
		Amount:      amount,
		DueDate:     dueDate,
	}
	if orderID != "" {
		oid := uuid.MustParse(orderID)
		debt.OrderID = &oid
	}

	if err := s.debtRepo.Create(ctx, debt); err != nil {
		return nil, fmt.Errorf("create debt: %w", err)
	}

	s.logger.Info("debt created",
		zap.String("id", debt.ID.String()),
		zap.String("pedagang_id", pedagangID),
		zap.String("pelanggan_id", pelangganID),
		zap.Float64("amount", amount))

	return debt, nil
}

// RecordPayment records a payment against a debt and creates a transaction.
func (s *DebtService) RecordPayment(ctx context.Context, debtID string, amount float64, method string) error {
	debt, err := s.debtRepo.GetByID(ctx, debtID)
	if err != nil {
		return fmt.Errorf("get debt: %w", err)
	}

	if debt.Status == models.DebtStatusSettled || debt.Status == models.DebtStatusWrittenOff {
		return repository.ErrDebtAlreadySettled
	}

	if amount > debt.Remaining {
		return repository.ErrPaymentExceedsDebt
	}

	// Record payment in debt
	if err := s.debtRepo.AddPayment(ctx, debtID, amount); err != nil {
		return fmt.Errorf("add payment: %w", err)
	}

	// Create transaction record
	payMethod := models.PaymentMethod(method)
	if payMethod == "" {
		payMethod = models.PayMethodCash
	}
	txn := &models.Transaction{
		PedagangID:    debt.PedagangID,
		PelangganID:   &debt.PelangganID,
		DebtID:        &debt.ID,
		Type:          models.TxnTypePayment,
		Amount:        amount,
		PaymentMethod: payMethod,
		Status:        models.TxnStatusCompleted,
	}
	if debt.OrderID != nil {
		txn.OrderID = debt.OrderID
	}

	if err := s.transRepo.Create(ctx, txn); err != nil {
		s.logger.Error("failed to create transaction for debt payment",
			zap.String("debt_id", debtID),
			zap.Error(err))
		// Don't fail the whole operation — debt payment is already recorded
	}

	s.logger.Info("debt payment recorded",
		zap.String("debt_id", debtID),
		zap.Float64("amount", amount),
		zap.String("method", method))

	return nil
}

// SendReminder sends a WhatsApp reminder for a debt.
// Messages escalate based on reminder count:
//   - 1st reminder: friendly
//   - 2nd reminder: firm
//   - 3rd+ reminder: urgent
func (s *DebtService) SendReminder(ctx context.Context, debtID string) error {
	debt, err := s.debtRepo.GetByID(ctx, debtID)
	if err != nil {
		return fmt.Errorf("get debt: %w", err)
	}

	if debt.Status == models.DebtStatusSettled || debt.Status == models.DebtStatusWrittenOff {
		return fmt.Errorf("debt is already %s", debt.Status)
	}

	// Get pelanggan info for the WhatsApp message
	pelanggan, err := s.userRepo.GetByID(ctx, debt.PelangganID.String())
	if err != nil {
		return fmt.Errorf("get pelanggan: %w", err)
	}

	pedagang, err := s.userRepo.GetByID(ctx, debt.PedagangID.String())
	if err != nil {
		return fmt.Errorf("get pedagang: %w", err)
	}

	reminderNum := debt.ReminderCount + 1
	message := s.buildReminderMessage(debt, pelanggan.Name, pedagang.Name, reminderNum)

	// Send via WhatsApp (auto-fallback to SMS)
	if s.notifDisp != nil {
		_, err := s.notifDisp.SendNotification(ctx, pelanggan.Phone, message, "auto")
		if err != nil {
			s.logger.Error("failed to send debt reminder",
				zap.String("debt_id", debtID),
				zap.String("pelanggan_phone", pelanggan.Phone),
				zap.Error(err))
			return fmt.Errorf("send reminder: %w", err)
		}
	}

	// Update reminder count
	if err := s.debtRepo.IncrementReminder(ctx, debtID); err != nil {
		s.logger.Error("failed to increment reminder count",
			zap.String("debt_id", debtID),
			zap.Error(err))
	}

	s.logger.Info("debt reminder sent",
		zap.String("debt_id", debtID),
		zap.Int("reminder_number", reminderNum),
		zap.String("pelanggan_phone", pelanggan.Phone))

	return nil
}

// SendAllDueReminders sends reminders for all overdue debts.
// Called by the scheduler at 9:00 AM WIB daily.
// Sends reminders at day 3, 7, and 14 thresholds.
func (s *DebtService) SendAllDueReminders(ctx context.Context) (int, error) {
	reminderSchedule := []struct {
		days        int
		reminderNum int
	}{
		{3, 1},
		{7, 2},
		{14, 3},
	}

	totalSent := 0

	for _, schedule := range reminderSchedule {
		debts, err := s.debtRepo.GetOverdue(ctx, "", schedule.days)
		if err != nil {
			s.logger.Error("failed to get overdue debts",
				zap.Int("days", schedule.days),
				zap.Error(err))
			continue
		}

		for _, debt := range debts {
			// Only send if we haven't exceeded the expected reminder count for this threshold
			if debt.ReminderCount >= schedule.reminderNum {
				continue
			}

			if err := s.SendReminder(ctx, debt.ID.String()); err != nil {
				s.logger.Error("failed to send reminder",
					zap.String("debt_id", debt.ID.String()),
					zap.Error(err))
				continue
			}
			totalSent++
		}
	}

	s.logger.Info("batch reminders completed", zap.Int("total_sent", totalSent))
	return totalSent, nil
}

// WriteOff marks a debt as uncollectable.
func (s *DebtService) WriteOff(ctx context.Context, debtID, reason string) error {
	debt, err := s.debtRepo.GetByID(ctx, debtID)
	if err != nil {
		return fmt.Errorf("get debt: %w", err)
	}

	if debt.Status == models.DebtStatusSettled {
		return fmt.Errorf("cannot write off a settled debt")
	}

	if err := s.debtRepo.WriteOff(ctx, debtID, reason); err != nil {
		return fmt.Errorf("write off debt: %w", err)
	}

	s.logger.Info("debt written off",
		zap.String("debt_id", debtID),
		zap.String("reason", reason))

	return nil
}

// GetSummary returns piutang summary for a pedagang.
func (s *DebtService) GetSummary(ctx context.Context, pedagangID string) (*DebtSummary, error) {
	totalOutstanding, debtCount, err := s.debtRepo.GetTotalOutstanding(ctx, pedagangID)
	if err != nil {
		return nil, fmt.Errorf("get total outstanding: %w", err)
	}

	// Get all debts to compute stats
	debts, err := s.debtRepo.ListByPedagang(ctx, pedagangID, "")
	if err != nil {
		return nil, fmt.Errorf("list debts: %w", err)
	}

	now := time.Now()
	overdueCount := 0
	oldestDays := 0
	debtorMap := make(map[string]*DebtorStat)

	for _, d := range debts {
		if d.Status == models.DebtStatusSettled || d.Status == models.DebtStatusWrittenOff {
			continue
		}

		// Calculate overdue days
		days := 0
		if d.DueDate != nil && d.DueDate.Before(now) {
			days = int(now.Sub(*d.DueDate).Hours() / 24)
		}

		if days > 0 {
			overdueCount++
		}
		if days > oldestDays {
			oldestDays = days
		}

		// Aggregate by debtor
		pid := d.PelangganID.String()
		stat, ok := debtorMap[pid]
		if !ok {
			stat = &DebtorStat{
				PelangganID:   pid,
				PelangganName: d.PelangganName,
			}
			debtorMap[pid] = stat
		}
		stat.TotalDebt += d.Remaining
		stat.DebtCount++
		if days > stat.OldestDays {
			stat.OldestDays = days
		}
	}

	// Convert to slice and sort by total debt descending
	topDebtors := make([]DebtorStat, 0, len(debtorMap))
	for _, stat := range debtorMap {
		topDebtors = append(topDebtors, *stat)
	}
	for i := 1; i < len(topDebtors); i++ {
		for j := i; j > 0 && topDebtors[j].TotalDebt > topDebtors[j-1].TotalDebt; j-- {
			topDebtors[j], topDebtors[j-1] = topDebtors[j-1], topDebtors[j]
		}
	}
	if len(topDebtors) > 10 {
		topDebtors = topDebtors[:10]
	}

	return &DebtSummary{
		TotalOutstanding: totalOutstanding,
		DebtCount:        debtCount,
		OverdueCount:     overdueCount,
		OldestDebtDays:   oldestDays,
		TopDebtors:       topDebtors,
	}, nil
}

// ListDebts returns debts for a pedagang filtered by status.
func (s *DebtService) ListDebts(ctx context.Context, pedagangID string, status string) ([]models.Debt, error) {
	return s.debtRepo.ListByPedagang(ctx, pedagangID, status)
}

// GetDebt returns a single debt by ID.
func (s *DebtService) GetDebt(ctx context.Context, debtID string) (*models.Debt, error) {
	return s.debtRepo.GetByID(ctx, debtID)
}

// buildReminderMessage constructs an escalating reminder message in Bahasa Indonesia.
func (s *DebtService) buildReminderMessage(debt *models.Debt, pelangganName, pedagangName string, reminderNum int) string {
	amount := debt.Remaining
	daysOverdue := 0
	if debt.DueDate != nil {
		daysOverdue = int(time.Since(*debt.DueDate).Hours() / 24)
	}
	if daysOverdue < 0 {
		daysOverdue = 0
	}

	switch {
	case reminderNum == 1:
		return fmt.Sprintf(
			"Halo %s 👋\n\n"+
				"Mengingatkan bahwa Anda memiliki piutang sebesar Rp %.0f kepada %s.\n"+
				"Jatuh tempo: %s (%d hari yang lalu)\n\n"+
				"Mohon segera melunasi ya. Terima kasih! 🙏",
			pelangganName, amount, pedagangName,
			debt.DueDate.Format("02 January 2006"), daysOverdue,
		)
	case reminderNum == 2:
		return fmt.Sprintf(
			"Halo %s,\n\n"+
				"Kami ingatkan kembali bahwa piutang Anda sebesar Rp %.0f kepada %s sudah jatuh tempo %d hari yang lalu.\n"+
				"Tanggal jatuh tempo: %s\n\n"+
				"Mohon segera ditransfer ya. Jika sudah membayar, abaikan pesan ini.\n\n"+
				"Terima kasih.",
			pelangganName, amount, pedagangName, daysOverdue,
			debt.DueDate.Format("02 January 2006"),
		)
	default:
		return fmt.Sprintf(
			"Yth. %s,\n\n"+
				"⚠️ PENGINGAT PENTING\n\n"+
				"Piutang Anda sebesar Rp %.0f kepada %s sudah TERLAMBAT %d hari.\n"+
				"Tanggal jatuh tempo: %s\n\n"+
				"Segera lakukan pembayaran untuk menghindari penagihan lebih lanjut.\n"+
				"Jika ada kendala, silakan hubungi %s langsung.\n\n"+
				"Terima kasih atas perhatiannya.",
			pelangganName, amount, pedagangName, daysOverdue,
			debt.DueDate.Format("02 January 2006"),
			pedagangName,
		)
	}
}
