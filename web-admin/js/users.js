/* ── SayurPintar Admin Users Module ── */

const Users = (() => {
    let currentPage = 1;
    let currentFilter = '';
    let currentSearch = '';
    let totalCount = 0;
    const perPage = 20;

    function init() {
        loadUsers();
    }

    async function loadUsers(page) {
        currentPage = page || 1;
        const container = document.getElementById('pageContent');
        container.innerHTML = renderLoading();

        try {
            let users = [];
            try {
                const res = await api.getUsers({
                    page: currentPage,
                    per_page: perPage,
                    role: currentFilter,
                    search: currentSearch
                });
                users = res.data || [];
                totalCount = res.meta?.total || users.length;
            } catch (e) {
                users = getMockUsers();
                totalCount = users.length;
            }

            container.innerHTML = renderUsersPage(users);
            bindEvents();
        } catch (e) {
            container.innerHTML = renderError(e.message);
        }
    }

    function renderUsersPage(users) {
        return `
        <div class="card-custom">
            <div class="card-header-custom">
                <h6><i class="bi bi-people me-2"></i>User Management</h6>
                <div class="d-flex gap-2">
                    <div class="search-bar">
                        <i class="bi bi-search search-icon"></i>
                        <input type="text" id="userSearch" class="form-control form-control-sm" placeholder="Search name or phone..." value="${currentSearch}">
                    </div>
                    <select id="userFilter" class="form-select form-select-sm" style="width:140px">
                        <option value="" ${currentFilter === '' ? 'selected' : ''}>All Roles</option>
                        <option value="pedagang" ${currentFilter === 'pedagang' ? 'selected' : ''}>Pedagang</option>
                        <option value="pelanggan" ${currentFilter === 'pelanggan' ? 'selected' : ''}>Pelanggan</option>
                        <option value="admin" ${currentFilter === 'admin' ? 'selected' : ''}>Admin</option>
                    </select>
                </div>
            </div>
            <div class="card-body-custom p-0">
                <table class="table table-custom mb-0">
                    <thead><tr>
                        <th>User</th>
                        <th>Phone</th>
                        <th>Role</th>
                        <th>Verified</th>
                        <th>Joined</th>
                        <th class="text-end">Actions</th>
                    </tr></thead>
                    <tbody>
                        ${users.length === 0 ? '<tr><td colspan="6" class="text-center text-muted py-4">No users found</td></tr>' :
                            users.map(u => `
                            <tr>
                                <td>
                                    <div class="d-flex align-items-center gap-2">
                                        <div class="user-avatar" style="width:32px;height:32px;font-size:0.75rem">${(u.name || 'U')[0].toUpperCase()}</div>
                                        <div>
                                            <div class="fw-semibold small">${u.name || 'Unnamed'}</div>
                                            <div class="text-muted" style="font-size:0.75rem">${u.id?.substring(0, 8) || ''}</div>
                                        </div>
                                    </div>
                                </td>
                                <td>${u.phone || '—'}</td>
                                <td><span class="badge-status ${u.role === 'admin' ? 'badge-verified' : u.role === 'pedagang' ? 'badge-active' : 'badge-pending'}">${u.role || '—'}</span></td>
                                <td>${u.is_verified ? '<i class="bi bi-check-circle-fill text-success"></i>' : '<i class="bi bi-x-circle text-muted"></i>'}</td>
                                <td class="small text-muted">${formatDate(u.created_at)}</td>
                                <td class="text-end">
                                    <div class="d-flex gap-1 justify-content-end">
                                        ${u.role === 'pedagang' && !u.is_verified ? `<button class="btn-sm-icon" title="Verify" onclick="Users.verifyUser('${u.id}')"><i class="bi bi-patch-check"></i></button>` : ''}
                                        <button class="btn-sm-icon" title="View Details" onclick="Users.viewUser('${u.id}')"><i class="bi bi-eye"></i></button>
                                        <button class="btn-sm-icon danger" title="Ban" onclick="Users.banUser('${u.id}', '${u.name}')"><i class="bi bi-slash-circle"></i></button>
                                    </div>
                                </td>
                            </tr>`).join('')
                        }
                    </tbody>
                </table>
            </div>
            ${renderPagination(currentPage, Math.ceil(totalCount / perPage), 'Users.goToPage')}
        </div>

        <!-- User Detail Modal -->
        <div class="modal fade" id="userDetailModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h6 class="modal-title fw-bold">User Details</h6>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body" id="userDetailBody">
                        <div class="sp-spinner"><div class="spinner-border"></div></div>
                    </div>
                </div>
            </div>
        </div>`;
    }

    function bindEvents() {
        const searchEl = document.getElementById('userSearch');
        if (searchEl) {
            let debounce;
            searchEl.addEventListener('input', () => {
                clearTimeout(debounce);
                debounce = setTimeout(() => {
                    currentSearch = searchEl.value.trim();
                    loadUsers(1);
                }, 400);
            });
        }
        const filterEl = document.getElementById('userFilter');
        if (filterEl) {
            filterEl.addEventListener('change', () => {
                currentFilter = filterEl.value;
                loadUsers(1);
            });
        }
    }

    async function verifyUser(id) {
        if (!confirm('Verify this pedagang?')) return;
        try {
            await api.verifyUser(id);
            showToast('User verified successfully', 'success');
            loadUsers(currentPage);
        } catch (e) {
            showToast(e.message, 'danger');
        }
    }

    async function banUser(id, name) {
        if (!confirm(`Ban user "${name || id}"? They will be unable to access the app.`)) return;
        try {
            await api.banUser(id);
            showToast('User banned', 'warning');
            loadUsers(currentPage);
        } catch (e) {
            showToast(e.message, 'danger');
        }
    }

    async function viewUser(id) {
        const modal = new bootstrap.Modal(document.getElementById('userDetailModal'));
        document.getElementById('userDetailBody').innerHTML = '<div class="sp-spinner"><div class="spinner-border"></div></div>';
        modal.show();

        try {
            const res = await api.getUserDetail(id);
            const u = res.data;
            document.getElementById('userDetailBody').innerHTML = `
                <div class="text-center mb-3">
                    <div class="user-avatar mx-auto" style="width:60px;height:60px;font-size:1.5rem">${(u.name || 'U')[0].toUpperCase()}</div>
                    <h6 class="mt-2 mb-0">${u.name || 'Unnamed'}</h6>
                    <span class="badge-status ${u.role === 'admin' ? 'badge-verified' : u.role === 'pedagang' ? 'badge-active' : 'badge-pending'}">${u.role}</span>
                </div>
                <table class="table table-sm">
                    <tr><td class="text-muted" style="width:120px">Phone</td><td>${u.phone}</td></tr>
                    <tr><td class="text-muted">Verified</td><td>${u.is_verified ? 'Yes' : 'No'}</td></tr>
                    <tr><td class="text-muted">Address</td><td>${u.address || '—'}</td></tr>
                    <tr><td class="text-muted">Area</td><td>${u.area || '—'}</td></tr>
                    <tr><td class="text-muted">Joined</td><td>${formatDate(u.created_at)}</td></tr>
                    <tr><td class="text-muted">Last Login</td><td>${u.last_login_at ? formatDate(u.last_login_at) : '—'}</td></tr>
                </table>`;
        } catch (e) {
            document.getElementById('userDetailBody').innerHTML = `<div class="alert alert-danger">${e.message}</div>`;
        }
    }

    function goToPage(page) {
        loadUsers(page);
    }

    function getMockUsers() {
        return [
            { id: 'u-001', name: 'Pak Budi Santoso', phone: '+62812345678', role: 'pedagang', is_verified: true, created_at: '2026-01-15' },
            { id: 'u-002', name: 'Ibu Sari Dewi', phone: '+62823456789', role: 'pelanggan', is_verified: true, created_at: '2026-02-10' },
            { id: 'u-003', name: 'Pak Joko Widodo', phone: '+62834567890', role: 'pedagang', is_verified: false, created_at: '2026-03-22' },
            { id: 'u-004', name: 'Ibu Rina Hartati', phone: '+62845678901', role: 'pelanggan', is_verified: true, created_at: '2026-04-05' },
            { id: 'u-005', name: 'Pak Andi Prasetyo', phone: '+62856789012', role: 'pedagang', is_verified: true, created_at: '2026-05-18' },
            { id: 'u-006', name: 'Admin Utama', phone: '+62899999999', role: 'admin', is_verified: true, created_at: '2025-12-01' },
        ];
    }

    return { init, verifyUser, banUser, viewUser, goToPage };
})();
