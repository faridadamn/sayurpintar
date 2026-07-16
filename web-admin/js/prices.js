/* ── SayurPintar Admin Prices Module ── */

const Prices = (() => {
    let currentPage = 1;
    let currentArea = '';
    let currentProduct = '';
    const perPage = 20;

    function init() {
        loadPrices();
    }

    async function loadPrices(page) {
        currentPage = page || 1;
        const container = document.getElementById('pageContent');
        container.innerHTML = renderLoading();

        try {
            let prices = [];
            try {
                const res = await api.getPrices({
                    page: currentPage,
                    per_page: perPage,
                    area: currentArea,
                    product: currentProduct
                });
                prices = res.data || [];
            } catch (e) {
                prices = getMockPrices();
            }

            container.innerHTML = renderPricesPage(prices);
            bindEvents();
        } catch (e) {
            container.innerHTML = renderError(e.message);
        }
    }

    function renderPricesPage(prices) {
        return `
        <div class="card-custom">
            <div class="card-header-custom">
                <h6><i class="bi bi-tag me-2"></i>Price Submissions</h6>
                <div class="d-flex gap-2">
                    <div class="search-bar">
                        <i class="bi bi-search search-icon"></i>
                        <input type="text" id="priceProduct" class="form-control form-control-sm" placeholder="Product name..." value="${currentProduct}">
                    </div>
                    <input type="text" id="priceArea" class="form-control form-control-sm" placeholder="Area..." style="width:140px" value="${currentArea}">
                </div>
            </div>
            <div class="card-body-custom p-0">
                <table class="table table-custom mb-0">
                    <thead><tr>
                        <th>Product</th>
                        <th>Area</th>
                        <th>Market</th>
                        <th>Price</th>
                        <th>Submitted By</th>
                        <th>Date</th>
                        <th>Verified</th>
                        <th class="text-end">Actions</th>
                    </tr></thead>
                    <tbody>
                        ${prices.length === 0 ? '<tr><td colspan="8" class="text-center text-muted py-4">No price submissions found</td></tr>' :
                            prices.map(p => `
                            <tr>
                                <td class="fw-semibold">${p.product_name || '—'}</td>
                                <td>${p.area || '—'}</td>
                                <td>${p.market || '—'}</td>
                                <td>Rp ${formatNumber(p.price)}<span class="text-muted small">/${p.unit || 'kg'}</span></td>
                                <td class="small">${p.submitted_by?.substring(0, 8) || '—'}</td>
                                <td class="small text-muted">${p.date || formatDate(p.created_at)}</td>
                                <td>${p.is_verified ? '<i class="bi bi-check-circle-fill text-success"></i>' : '<i class="bi bi-clock text-warning"></i>'}</td>
                                <td class="text-end">
                                    <div class="d-flex gap-1 justify-content-end">
                                        <button class="btn-sm-icon" title="Flag as suspicious" onclick="Prices.flagPrice('${p.id}')"><i class="bi bi-flag"></i></button>
                                        <button class="btn-sm-icon danger" title="Delete" onclick="Prices.deletePrice('${p.id}', '${p.product_name}')"><i class="bi bi-trash3"></i></button>
                                    </div>
                                </td>
                            </tr>`).join('')
                        }
                    </tbody>
                </table>
            </div>
            ${renderPagination(currentPage, 5, 'Prices.goToPage')}
        </div>`;
    }

    function bindEvents() {
        const productEl = document.getElementById('priceProduct');
        if (productEl) {
            let debounce;
            productEl.addEventListener('input', () => {
                clearTimeout(debounce);
                debounce = setTimeout(() => {
                    currentProduct = productEl.value.trim();
                    loadPrices(1);
                }, 400);
            });
        }
        const areaEl = document.getElementById('priceArea');
        if (areaEl) {
            let debounce;
            areaEl.addEventListener('input', () => {
                clearTimeout(debounce);
                debounce = setTimeout(() => {
                    currentArea = areaEl.value.trim();
                    loadPrices(1);
                }, 400);
            });
        }
    }

    async function flagPrice(id) {
        if (!confirm('Flag this price submission as suspicious?')) return;
        try {
            await api.flagPrice(id);
            showToast('Price flagged for review', 'warning');
            loadPrices(currentPage);
        } catch (e) {
            showToast(e.message, 'danger');
        }
    }

    async function deletePrice(id, name) {
        if (!confirm(`Delete price submission for "${name}"? This cannot be undone.`)) return;
        try {
            await api.deletePrice(id);
            showToast('Price submission deleted', 'success');
            loadPrices(currentPage);
        } catch (e) {
            showToast(e.message, 'danger');
        }
    }

    function goToPage(page) {
        loadPrices(page);
    }

    function getMockPrices() {
        return [
            { id: 'p-001', product_name: 'Cabai Merah', area: 'Jakarta Selatan', market: 'Pasar Minggu', price: 45000, unit: 'kg', submitted_by: 'u-001', date: '2026-07-16', is_verified: true },
            { id: 'p-002', product_name: 'Bawang Putih', area: 'Jakarta Timur', market: 'Pasar Senen', price: 32000, unit: 'kg', submitted_by: 'u-003', date: '2026-07-16', is_verified: false },
            { id: 'p-003', product_name: 'Tomat', area: 'Jakarta Barat', market: 'Pasar Kopro', price: 18000, unit: 'kg', submitted_by: 'u-005', date: '2026-07-15', is_verified: true },
            { id: 'p-004', product_name: 'Kentang', area: 'Jakarta Utara', market: 'Pasar Koja', price: 22000, unit: 'kg', submitted_by: 'u-001', date: '2026-07-15', is_verified: true },
            { id: 'p-005', product_name: 'Wortel', area: 'Jakarta Selatan', market: 'Pasar Minggu', price: 15000, unit: 'kg', submitted_by: 'u-003', date: '2026-07-14', is_verified: false },
            { id: 'p-006', product_name: 'Bayam', area: 'Jakarta Pusat', market: 'Pasar Baru', price: 8000, unit: 'ikat', submitted_by: 'u-005', date: '2026-07-14', is_verified: true },
            { id: 'p-007', product_name: 'Cabai Rawit', area: 'Jakarta Timur', market: 'Pasar Senen', price: 65000, unit: 'kg', submitted_by: 'u-001', date: '2026-07-13', is_verified: true },
            { id: 'p-008', product_name: 'Bawang Merah', area: 'Jakarta Barat', market: 'Pasar Kopro', price: 38000, unit: 'kg', submitted_by: 'u-003', date: '2026-07-13', is_verified: false },
        ];
    }

    return { init, flagPrice, deletePrice, goToPage };
})();
