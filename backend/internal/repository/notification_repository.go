package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/sayurpintar/api/internal/models"
)

var (
	ErrNotificationNotFound = errors.New("notification not found")
)

// NotificationRepository defines the data access contract for notifications.
type NotificationRepository interface {
	Create(ctx context.Context, notif *models.Notification) error
	GetByID(ctx context.Context, id string) (*models.Notification, error)
	ListByUser(ctx context.Context, userID string, unreadOnly bool, limit int) ([]models.Notification, error)
	MarkAsRead(ctx context.Context, id string, userID string) error
	MarkAllAsRead(ctx context.Context, userID string) error
	GetUnreadCount(ctx context.Context, userID string) (int, error)
	CountUnread(ctx context.Context, userID string) (int, error)
	Delete(ctx context.Context, id string) error
	DeleteOlderThan(ctx context.Context, days int) (int, error)
	DeleteOlderThanTime(ctx context.Context, cutoff time.Time) (int, error)
}

// notificationRepo implements NotificationRepository backed by pgxpool.
type notificationRepo struct {
	pool *pgxpool.Pool
}

// NewNotificationRepository returns a new NotificationRepository.
func NewNotificationRepository(pool *pgxpool.Pool) NotificationRepository {
	return &notificationRepo{pool: pool}
}

const notificationColumns = `
	id, user_id, type, title, body, data, is_read, read_at, created_at
`

func scanNotification(row pgx.Row) (*models.Notification, error) {
	var n models.Notification
	err := row.Scan(
		&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body,
		&n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &n, nil
}

// Create inserts a new notification and populates generated fields.
func (r *notificationRepo) Create(ctx context.Context, notif *models.Notification) error {
	if notif.Data == nil {
		notif.Data = []byte("{}")
	}

	query := `
		INSERT INTO notifications (user_id, type, title, body, data)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING ` + notificationColumns

	row := r.pool.QueryRow(ctx, query,
		notif.UserID, notif.Type, notif.Title, notif.Body, notif.Data,
	)

	created, err := scanNotification(row)
	if err != nil {
		return fmt.Errorf("insert notification: %w", err)
	}
	*notif = *created
	return nil
}

// GetByID fetches a notification by UUID.
func (r *notificationRepo) GetByID(ctx context.Context, id string) (*models.Notification, error) {
	query := `SELECT ` + notificationColumns + ` FROM notifications WHERE id = $1`

	notif, err := scanNotification(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotificationNotFound
		}
		return nil, fmt.Errorf("get notification by id: %w", err)
	}
	return notif, nil
}

// ListByUser returns notifications for a user, optionally filtered to unread only.
func (r *notificationRepo) ListByUser(ctx context.Context, userID string, unreadOnly bool, limit int) ([]models.Notification, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `SELECT ` + notificationColumns + ` FROM notifications WHERE user_id = $1`

	if unreadOnly {
		query += ` AND is_read = false`
	}

	query += ` ORDER BY created_at DESC LIMIT $2`

	rows, err := r.pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("list notifications: %w", err)
	}
	defer rows.Close()

	var notifications []models.Notification
	for rows.Next() {
		var n models.Notification
		if err := rows.Scan(
			&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body,
			&n.Data, &n.IsRead, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan notification: %w", err)
		}
		notifications = append(notifications, n)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate notifications: %w", err)
	}
	if notifications == nil {
		notifications = []models.Notification{}
	}
	return notifications, nil
}

// MarkAsRead marks a single notification as read.
func (r *notificationRepo) MarkAsRead(ctx context.Context, id string, userID string) error {
	query := `
		UPDATE notifications
		SET is_read = true, read_at = NOW()
		WHERE id = $1 AND user_id = $2
		RETURNING id`

	var returnedID string
	err := r.pool.QueryRow(ctx, query, id, userID).Scan(&returnedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotificationNotFound
		}
		return fmt.Errorf("mark notification as read: %w", err)
	}
	return nil
}

// MarkAllAsRead marks all notifications for a user as read.
func (r *notificationRepo) MarkAllAsRead(ctx context.Context, userID string) error {
	query := `
		UPDATE notifications
		SET is_read = true, read_at = NOW()
		WHERE user_id = $1 AND is_read = false`

	_, err := r.pool.Exec(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("mark all notifications as read: %w", err)
	}
	return nil
}

// GetUnreadCount returns the number of unread notifications for a user.
func (r *notificationRepo) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	return r.CountUnread(ctx, userID)
}

// CountUnread returns the number of unread notifications for a user.
func (r *notificationRepo) CountUnread(ctx context.Context, userID string) (int, error) {
	query := `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`

	var count int
	err := r.pool.QueryRow(ctx, query, userID).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("get unread count: %w", err)
	}
	return count, nil
}

// Delete removes a notification by ID.
func (r *notificationRepo) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM notifications WHERE id = $1 RETURNING id`

	var deletedID string
	err := r.pool.QueryRow(ctx, query, id).Scan(&deletedID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotificationNotFound
		}
		return fmt.Errorf("delete notification: %w", err)
	}
	return nil
}

// DeleteOlderThan deletes notifications older than the given number of days.
// Returns the count of deleted notifications.
func (r *notificationRepo) DeleteOlderThan(ctx context.Context, days int) (int, error) {
	query := `DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '1 day' * $1`

	tag, err := r.pool.Exec(ctx, query, days)
	if err != nil {
		return 0, fmt.Errorf("delete old notifications: %w", err)
	}
	return int(tag.RowsAffected()), nil
}

// DeleteOlderThanTime deletes notifications older than the given cutoff time.
// Returns the count of deleted notifications.
func (r *notificationRepo) DeleteOlderThanTime(ctx context.Context, cutoff time.Time) (int, error) {
	query := `DELETE FROM notifications WHERE created_at < $1`

	tag, err := r.pool.Exec(ctx, query, cutoff)
	if err != nil {
		return 0, fmt.Errorf("delete old notifications: %w", err)
	}
	return int(tag.RowsAffected()), nil
}
