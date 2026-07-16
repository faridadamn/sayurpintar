package auth

// RegisterRequest is the request body for POST /auth/register.
type RegisterRequest struct {
	Phone string `json:"phone" validate:"required,e164"`
}

// SendOTPRequest is the request body for POST /auth/otp/send.
type SendOTPRequest struct {
	Phone string `json:"phone" validate:"required,e164"`
}

// VerifyOTPRequest is the request body for POST /auth/otp/verify.
type VerifyOTPRequest struct {
	Phone string `json:"phone" validate:"required,e164"`
	OTP   string `json:"otp" validate:"required,len=6,numeric"`
}

// SetRoleRequest is the request body for POST /auth/role.
type SetRoleRequest struct {
	Role string `json:"role" validate:"required,oneof=pedagang pelanggan"`
}

// RefreshTokenRequest is the request body for POST /auth/token/refresh.
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

// UpdateProfileBody is the request body for PUT /auth/me.
type UpdateProfileBody struct {
	Name      string `json:"name" validate:"omitempty,min=2,max=100"`
	Address   string `json:"address" validate:"omitempty,max=500"`
	AvatarURL string `json:"avatar_url" validate:"omitempty,url"`
}
