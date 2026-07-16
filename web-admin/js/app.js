/* ── SayurPintar Admin App — Main Entry ── */

// ── Global Helpers ──

function formatNumber(n) {
    if (n === undefined || n === null) return '0';
    return Number(n).toLocaleString('id-ID');
}

function formatCurrency(n) {
    if (n === undefined || n === null) return '0';
    return Number(n).toLocaleString('id-ID');
}

function formatDate(d) {
    if (!d) return '—';
    try {
        const dt = new Date(d);
        return dt.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
    } catch {
        return d;
    }
}

function renderLoading() {
    return '<div class="sp-spinner"><div class="spinner-border" role="status"></div></div>';
}

function renderError(msg) {
    return `
    <div class="text-center py-5">
        <i class="bi bi-exclamation-triangle text-warning" style="font-size:2.5rem"></i>
        <h6 class="mt-3">Something went wrong</h6>
        <p class="text-muted small">${msg}</p>
        <button class="btn btn-sp-outline btn-sm" onclick="location.reload()">
            <i class="bi bi-arrow-clockwise me-1"></i> Retry
        </button>
    </div>`;
}

function renderPagination(current, total, onClickFn) {
    if (total <= 1) return '';
    let pages = '';
    const start = Math.max(1, current - 2);
    const end = Math.min(total, current + 2);

    pages += `<li class="page-item ${current === 1 ? 'disabled' : ''}">
        <a class="page-link" href="#" onclick="${onClickFn}(${current - 1});return false">‹</a></li>`;

    if (start > 1) {
        pages += `<li class="page-item"><a class="page-link" href="#" onclick="${onClickFn}(1);return false">1</a></li>`;
        if (start > 2) pages += `<li class="page-item disabled"><span class="page-link">…</span></li>`;
    }

    for (let i = start; i <= end; i++) {
        pages += `<li class="page-item ${i === current ? 'active' : ''}">
            <a class="page-link" href="#" onclick="${onClickFn}(${i});return false">${i}</a></li>`;
    }

    if (end < total) {
        if (end < total - 1) pages += `<li class="page-item disabled"><span class="page-link">…</span></li>`;
        pages += `<li class="page-item"><a class="page-link" href="#" onclick="${onClickFn}(${total});return false">${total}</a></li>`;
    }

    pages += `<li class="page-item ${current === total ? 'disabled' : ''}">
        <a class="page-link" href="#" onclick="${onClickFn}(${current + 1});return false">›</a></li>`;

    return `<div class="d-flex justify-content-between align-items-center px-3 py-2 border-top">
        <span class="small text-muted">Page ${current} of ${total}</span>
        <ul class="pagination pagination-sm mb-0">${pages}</ul>
    </div>`;
}

function showToast(message, type) {
    type = type || 'success';
    const container = document.querySelector('.toast-container') || (() => {
        const el = document.createElement('div');
        el.className = 'toast-container';
        document.body.appendChild(el);
        return el;
    })();

    const id = 'toast-' + Date.now();
    const iconMap = {
        success: 'bi-check-circle-fill text-success',
        danger: 'bi-exclamation-circle-fill text-danger',
        warning: 'bi-exclamation-triangle-fill text-warning',
        info: 'bi-info-circle-fill text-primary'
    };

    const toast = document.createElement('div');
    toast.id = id;
    toast.className = 'toast show';
    toast.setAttribute('role', 'alert');
    toast.innerHTML = `
        <div class="toast-body d-flex align-items-center gap-2">
            <i class="bi ${iconMap[type] || iconMap.info}"></i>
            <span>${message}</span>
            <button type="button" class="btn-close btn-close-sm ms-auto" onclick="this.closest('.toast').remove()"></button>
        </div>`;
    container.appendChild(toast);

    setTimeout(() => {
        const el = document.getElementById(id);
        if (el) el.remove();
    }, 4000);
}

// ── Router ──

const App = (() => {
    const routes = {
        'dashboard': { title: 'Dashboard', icon: 'bi-speedometer2', module: () => Dashboard },
        'users': { title: 'Pedagang & Users', icon: 'bi-people', module: () => Users },
        'prices': { title: 'Prices', icon: 'bi-tag', module: () => Prices },
        'products': { title: 'Products', icon: 'bi-box-seam', module: () => Products },
        'orders': { title: 'Orders', icon: 'bi-cart', module: null },
        'settings': { title: 'Settings', icon: 'bi-gear', module: null },
    };

    let currentRoute = 'dashboard';

    function init() {
        renderSidebar();
        renderTopBar();
        renderMainContent();

        // Listen for hash changes
        window.addEventListener('hashchange', onHashChange);
        onHashChange();

        // Mobile sidebar toggle
        document.addEventListener('click', (e) => {
            if (e.target.closest('#sidebarToggle')) {
                document.querySelector('.sidebar').classList.toggle('show');
                document.querySelector('.sidebar-overlay').classList.toggle('show');
            }
            if (e.target.closest('.sidebar-overlay')) {
                document.querySelector('.sidebar').classList.remove('show');
                document.querySelector('.sidebar-overlay').classList.remove('show');
            }
            if (e.target.closest('#btnLogout')) {
                Auth.logout();
            }
        });
    }

    function renderSidebar() {
        const sidebar = document.getElementById('appSidebar');
        sidebar.innerHTML = `
            <a href="#dashboard" class="sidebar-brand">
                <img src="assets/logo.svg" alt="SayurPintar">
            </a>
            <nav class="sidebar-nav">
                <div class="nav-section">Main</div>
                <a href="#dashboard" class="nav-link" data-route="dashboard">
                    <i class="bi bi-speedometer2"></i> Dashboard
                </a>
                <div class="nav-section">Management</div>
                <a href="#users" class="nav-link" data-route="users">
                    <i class="bi bi-people"></i> Pedagang & Users
                </a>
                <a href="#prices" class="nav-link" data-route="prices">
                    <i class="bi bi-tag"></i> Prices
                </a>
                <a href="#products" class="nav-link" data-route="products">
                    <i class="bi bi-box-seam"></i> Products
                </a>
                <a href="#orders" class="nav-link" data-route="orders">
                    <i class="bi bi-cart"></i> Orders
                </a>
                <div class="nav-section">System</div>
                <a href="#settings" class="nav-link" data-route="settings">
                    <i class="bi bi-gear"></i> Settings
                </a>
            </nav>
        `;
    }

    function renderTopBar() {
        const topBar = document.getElementById('appTopBar');
        topBar.innerHTML = `
            <div class="d-flex align-items-center gap-3">
                <button class="btn btn-sm d-lg-none" id="sidebarToggle">
                    <i class="bi bi-list fs-5"></i>
                </button>
                <span class="page-title" id="pageTitle">Dashboard</span>
            </div>
            <div class="d-flex align-items-center gap-3">
                <div class="user-info" id="userInfo"></div>
                <button class="btn btn-sm btn-outline-secondary" id="btnLogout" title="Logout">
                    <i class="bi bi-box-arrow-right"></i>
                </button>
            </div>
        `;
    }

    function renderMainContent() {
        const main = document.getElementById('appMain');
        main.innerHTML = `
            <div class="sidebar-overlay"></div>
            <div class="content-area" id="pageContent"></div>
        `;
    }

    function onHashChange() {
        const hash = (location.hash || '#dashboard').replace('#', '');
        const route = routes[hash];

        if (!route) {
            location.hash = '#dashboard';
            return;
        }

        currentRoute = hash;

        // Update sidebar active state
        document.querySelectorAll('.sidebar-nav .nav-link').forEach(el => {
            el.classList.toggle('active', el.dataset.route === hash);
        });

        // Update title
        const titleEl = document.getElementById('pageTitle');
        if (titleEl) titleEl.textContent = route.title;

        // Close mobile sidebar
        document.querySelector('.sidebar')?.classList.remove('show');
        document.querySelector('.sidebar-overlay')?.classList.remove('show');

        // Load module
        if (route.module) {
            const mod = route.module();
            if (mod && mod.init) mod.init();
        } else {
            document.getElementById('pageContent').innerHTML = `
                <div class="empty-state">
                    <i class="bi bi-tools"></i>
                    <h6>Coming Soon</h6>
                    <p class="text-muted small">This section is under development.</p>
                </div>`;
        }
    }

    return { init };
})();

// ── Bootstrap ──

document.addEventListener('DOMContentLoaded', () => {
    // Wait for auth to initialize first, then app
    // Auth.init() runs on DOMContentLoaded from auth.js
    // App will be initialized after successful login
    const waitForAuth = setInterval(() => {
        if (Auth.isLoggedIn()) {
            clearInterval(waitForAuth);
            App.init();
        }
    }, 200);

    // Timeout after 5s — if auth modal is showing, that's fine
    setTimeout(() => clearInterval(waitForAuth), 5000);
});
