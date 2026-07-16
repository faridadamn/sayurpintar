/* ── SayurPintar Admin Auth Module ── */

const Auth = (() => {
    let currentUser = null;

    function init() {
        renderLoginModal();
        checkSession();
    }

    function isLoggedIn() {
        return !!api.token;
    }

    async function checkSession() {
        if (!api.token) {
            showLoginModal();
            return;
        }
        try {
            const res = await api.getProfile();
            currentUser = res.data;
            if (currentUser.role !== 'admin') {
                api.clearToken();
                showLoginModal();
                showToast('Access denied. Admin role required.', 'danger');
                return;
            }
            hideLoginModal();
            updateUserInfo();
            if (typeof Dashboard !== 'undefined') Dashboard.init();
        } catch (e) {
            api.clearToken();
            showLoginModal();
        }
    }

    function renderLoginModal() {
        if (document.getElementById('loginModal')) return;
        const modal = document.createElement('div');
        modal.innerHTML = `
        <div class="modal fade" id="loginModal" data-bs-backdrop="static" data-bs-keyboard="false" tabindex="-1">
            <div class="modal-dialog modal-dialog-centered">
                <div class="modal-content">
                    <div class="modal-body p-4">
                        <div class="text-center mb-4">
                            <img src="assets/logo.svg" alt="SayurPintar" height="40" class="mb-3">
                            <h5 class="fw-bold">Admin Login</h5>
                            <p class="text-muted small">Enter your phone number to receive an OTP</p>
                        </div>
                        <div id="loginStep1">
                            <div class="mb-3">
                                <label class="form-label small fw-semibold">Phone Number</label>
                                <input type="tel" id="loginPhone" class="form-control" placeholder="+628xxxxxxxxxx">
                            </div>
                            <button class="btn btn-sp-primary w-100" id="btnSendOTP">
                                <i class="bi bi-send me-1"></i> Send OTP
                            </button>
                        </div>
                        <div id="loginStep2" style="display:none">
                            <div class="mb-3">
                                <label class="form-label small fw-semibold">OTP Code</label>
                                <input type="text" id="loginOTP" class="form-control" placeholder="6-digit code" maxlength="6">
                            </div>
                            <button class="btn btn-sp-primary w-100" id="btnVerifyOTP">
                                <i class="bi bi-check-circle me-1"></i> Verify & Login
                            </button>
                            <button class="btn btn-link btn-sm w-100 mt-2 text-muted" id="btnBackToPhone">
                                ← Change phone number
                            </button>
                        </div>
                        <div id="loginError" class="alert alert-danger mt-3 d-none" role="alert"></div>
                    </div>
                </div>
            </div>
        </div>`;
        document.body.appendChild(modal.firstElementChild);

        document.getElementById('btnSendOTP').addEventListener('click', sendOTP);
        document.getElementById('btnVerifyOTP').addEventListener('click', verifyOTP);
        document.getElementById('btnBackToPhone').addEventListener('click', () => {
            document.getElementById('loginStep1').style.display = '';
            document.getElementById('loginStep2').style.display = 'none';
            hideLoginError();
        });

        document.getElementById('loginOTP').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') verifyOTP();
        });
        document.getElementById('loginPhone').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendOTP();
        });
    }

    async function sendOTP() {
        const phone = document.getElementById('loginPhone').value.trim();
        if (!phone) {
            showLoginError('Please enter your phone number');
            return;
        }
        const btn = document.getElementById('btnSendOTP');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Sending...';
        hideLoginError();

        try {
            await api.sendOTP(phone);
            document.getElementById('loginStep1').style.display = 'none';
            document.getElementById('loginStep2').style.display = '';
            document.getElementById('loginOTP').focus();
        } catch (e) {
            showLoginError(e.message);
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-send me-1"></i> Send OTP';
        }
    }

    async function verifyOTP() {
        const phone = document.getElementById('loginPhone').value.trim();
        const otp = document.getElementById('loginOTP').value.trim();
        if (!otp) {
            showLoginError('Please enter the OTP code');
            return;
        }
        const btn = document.getElementById('btnVerifyOTP');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Verifying...';
        hideLoginError();

        try {
            const res = await api.verifyOTP(phone, otp);
            const user = res.data?.user;
            if (!user || user.role !== 'admin') {
                api.clearToken();
                showLoginError('Access denied. Admin role required.');
                return;
            }
            currentUser = user;
            hideLoginModal();
            updateUserInfo();
            if (typeof Dashboard !== 'undefined') Dashboard.init();
            showToast('Welcome back, ' + (user.name || 'Admin') + '!', 'success');
        } catch (e) {
            showLoginError(e.message);
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-check-circle me-1"></i> Verify & Login';
        }
    }

    function showLoginModal() {
        const el = document.getElementById('loginModal');
        if (el) {
            const modal = new bootstrap.Modal(el);
            modal.show();
        }
    }

    function hideLoginModal() {
        const el = document.getElementById('loginModal');
        if (el) {
            const modal = bootstrap.Modal.getInstance(el);
            if (modal) modal.hide();
        }
    }

    function showLoginError(msg) {
        const el = document.getElementById('loginError');
        el.textContent = msg;
        el.classList.remove('d-none');
    }

    function hideLoginError() {
        const el = document.getElementById('loginError');
        if (el) el.classList.add('d-none');
    }

    function updateUserInfo() {
        const el = document.getElementById('userInfo');
        if (el && currentUser) {
            const initial = (currentUser.name || 'A')[0].toUpperCase();
            el.innerHTML = `
                <div class="user-avatar">${initial}</div>
                <span>${currentUser.name || currentUser.phone}</span>
            `;
        }
    }

    function logout() {
        api.clearToken();
        currentUser = null;
        window.location.reload();
    }

    function getUser() {
        return currentUser;
    }

    return { init, isLoggedIn, logout, getUser };
})();

document.addEventListener('DOMContentLoaded', () => Auth.init());
