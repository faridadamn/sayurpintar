package repository

import "errors"

var (
	// ErrUserNotFound is returned when a user lookup yields no rows.
	ErrUserNotFound = errors.New("user not found")

	// ErrOTPInvalid is returned when the provided OTP does not match.
	ErrOTPInvalid = errors.New("invalid otp")

	// ErrOTPExpired is returned when the OTP has passed its expiry time.
	ErrOTPExpired = errors.New("otp expired")

	// ErrWaypointNotFound is returned when a waypoint lookup yields no rows.
	ErrWaypointNotFound = errors.New("waypoint not found")

	// ErrVisitNotFound is returned when a visit lookup yields no rows.
	ErrVisitNotFound = errors.New("visit not found")

	// ErrSubscriptionPackageNotFound is returned when a subscription package lookup yields no rows.
	ErrSubscriptionPackageNotFound = errors.New("subscription package not found")

	// ErrSubscriptionNotFound is returned when a subscription lookup yields no rows.
	ErrSubscriptionNotFound = errors.New("subscription not found")

	// ErrModificationNotFound is returned when a subscription modification lookup yields no rows.
	ErrModificationNotFound = errors.New("modification not found")

	// ErrPackageLimitReached is returned when a package has reached its max subscriber limit.
	ErrPackageLimitReached = errors.New("package has reached maximum subscribers")

	// ErrAlreadySubscribed is returned when a pelanggan already subscribes to a package.
	ErrAlreadySubscribed = errors.New("already subscribed to this package")

	// ErrOrderNotFound is returned when an order lookup yields no rows.
	ErrOrderNotFound = errors.New("order not found")

	// ErrPackageInactive is returned when the subscription package is not active.
	ErrPackageInactive = errors.New("subscription package is not active")

	// ErrOrderAlreadyExists is returned when a duplicate order is detected.
	ErrOrderAlreadyExists = errors.New("order already exists for this subscription and date")

	// ErrProductNotFound is returned when a product lookup yields no rows.
	ErrProductNotFound = errors.New("product not found")

	// ErrGroupOrderNotFound is returned when a group order lookup yields no rows.
	ErrGroupOrderNotFound = errors.New("group order not found")

	// ErrGroupNotOpen is returned when trying to join a group that is not open.
	ErrGroupNotOpen = errors.New("group order is not open")

	// ErrGroupFull is returned when the group has reached target quantity.
	ErrGroupFull = errors.New("group order is full")

	// ErrAlreadyJoined is returned when a pedagang already joined the group.
	ErrAlreadyJoined = errors.New("already joined this group order")

	// ErrParticipantNotFound is returned when a participant lookup yields no rows.
	ErrParticipantNotFound = errors.New("participant not found")

	// ErrSupplierNotFound is returned when a supplier lookup yields no rows.
	ErrSupplierNotFound = errors.New("supplier not found")

	// ErrDeadlinePassed is returned when trying to join an expired group.
	ErrDeadlinePassed = errors.New("group order deadline has passed")

	// ErrDebtNotFound is returned when a debt lookup yields no rows.
	ErrDebtNotFound = errors.New("debt not found")

	// ErrDebtAlreadySettled is returned when trying to pay a settled debt.
	ErrDebtAlreadySettled = errors.New("debt already settled")

	// ErrPaymentExceedsDebt is returned when payment amount exceeds remaining debt.
	ErrPaymentExceedsDebt = errors.New("payment amount exceeds remaining debt")

	// ErrTransactionNotFound is returned when a transaction lookup yields no rows.
	ErrTransactionNotFound = errors.New("transaction not found")
)
