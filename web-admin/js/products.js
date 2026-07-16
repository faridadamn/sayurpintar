/* ── SayurPintar Admin Products Module ── */

const Products = (() => {
    let products = [];
    let categories = [];
    let editingId = null;

    function init() {
        loadProducts();
    }

    async function loadProducts() {
        const container = document.getElementById('pageContent');
        container.innerHTML = renderLoading();

        try {
            try {
                const [prodRes, catRes] = await Promise.all([
                    api.getProducts(),
                    api.getCategories().catch(() => ({ data: [] }))
                ]);
                products = prodRes.data || [];
                categories = catRes.data || [];
            } catch (e) {
                products = getMockProducts();
                categories = ['Sayuran', 'Buah', 'Bumbu', 'Sembako', 'Lainnya'];
            }

            container.innerHTML = renderProductsPage();
            bindEvents();
        } catch (e) {
            container.innerHTML = renderError(e.message);
        }
    }

    function renderProductsPage() {
        return `
        <div class="card-custom">
            <div class="card-header-custom">
                <h6><i class="bi bi-box-seam me-2"></i>Product Management</h6>
                <button class="btn btn-sp-primary btn-sm" onclick="Products.openAddModal()">
                    <i class="bi bi-plus-lg me-1"></i> Add Product
                </button>
            </div>
            <div class="card-body-custom p-0">
                <table class="table table-custom mb-0">
                    <thead><tr>
                        <th>Product</th>
                        <th>Category</th>
                        <th>Unit</th>
                        <th>Status</th>
                        <th class="text-end">Actions</th>
                    </tr></thead>
                    <tbody>
                        ${products.length === 0 ? '<tr><td colspan="5" class="text-center text-muted py-4">No products found</td></tr>' :
                            products.map(p => `
                            <tr>
                                <td class="fw-semibold">${p.name || '—'}</td>
                                <td><span class="badge-status badge-active">${p.category || '—'}</span></td>
                                <td>${p.unit || '—'}</td>
                                <td>${p.is_active !== false ? '<span class="badge-status badge-active">Active</span>' : '<span class="badge-status badge-inactive">Inactive</span>'}</td>
                                <td class="text-end">
                                    <div class="d-flex gap-1 justify-content-end">
                                        <button class="btn-sm-icon" title="Edit" onclick="Products.openEditModal('${p.id}')"><i class="bi bi-pencil"></i></button>
                                        <button class="btn-sm-icon danger" title="Delete" onclick="Products.deleteProduct('${p.id}', '${p.name}')"><i class="bi bi-trash3"></i></button>
                                    </div>
                                </td>
                            </tr>`).join('')
                        }
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Product Modal -->
        <div class="modal fade" id="productModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h6 class="modal-title fw-bold" id="productModalTitle">Add Product</h6>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="mb-3">
                            <label class="form-label small fw-semibold">Product Name *</label>
                            <input type="text" id="prodName" class="form-control" placeholder="e.g. Cabai Merah">
                        </div>
                        <div class="row mb-3">
                            <div class="col-6">
                                <label class="form-label small fw-semibold">Category *</label>
                                <select id="prodCategory" class="form-select">
                                    <option value="">Select category</option>
                                    ${categories.map(c => `<option value="${typeof c === 'string' ? c : c.name}">${typeof c === 'string' ? c : c.name}</option>`).join('')}
                                </select>
                            </div>
                            <div class="col-6">
                                <label class="form-label small fw-semibold">Unit *</label>
                                <select id="prodUnit" class="form-select">
                                    <option value="kg">Kilogram (kg)</option>
                                    <option value="gram">Gram (g)</option>
                                    <option value="pcs">Pieces (pcs)</option>
                                    <option value="ikat">Ikat</option>
                                    <option value="liter">Liter</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label small fw-semibold">Description</label>
                            <textarea id="prodDesc" class="form-control" rows="2" placeholder="Optional description"></textarea>
                        </div>
                        <div id="prodError" class="alert alert-danger d-none"></div>
                    </div>
                    <div class="modal-footer">
                        <button class="btn btn-sp-outline btn-sm" data-bs-dismiss="modal">Cancel</button>
                        <button class="btn btn-sp-primary btn-sm" id="btnSaveProduct" onclick="Products.saveProduct()">
                            <i class="bi bi-check-lg me-1"></i> Save
                        </button>
                    </div>
                </div>
            </div>
        </div>`;
    }

    function bindEvents() {
        // No special bindings needed; events are inline
    }

    function openAddModal() {
        editingId = null;
        document.getElementById('productModalTitle').textContent = 'Add Product';
        document.getElementById('prodName').value = '';
        document.getElementById('prodCategory').value = '';
        document.getElementById('prodUnit').value = 'kg';
        document.getElementById('prodDesc').value = '';
        hideProdError();
        new bootstrap.Modal(document.getElementById('productModal')).show();
    }

    function openEditModal(id) {
        const p = products.find(x => x.id === id);
        if (!p) return;
        editingId = id;
        document.getElementById('productModalTitle').textContent = 'Edit Product';
        document.getElementById('prodName').value = p.name || '';
        document.getElementById('prodCategory').value = p.category || '';
        document.getElementById('prodUnit').value = p.unit || 'kg';
        document.getElementById('prodDesc').value = p.description || '';
        hideProdError();
        new bootstrap.Modal(document.getElementById('productModal')).show();
    }

    async function saveProduct() {
        const name = document.getElementById('prodName').value.trim();
        const category = document.getElementById('prodCategory').value;
        const unit = document.getElementById('prodUnit').value;
        const description = document.getElementById('prodDesc').value.trim();

        if (!name) {
            showProdError('Product name is required');
            return;
        }
        if (!category) {
            showProdError('Category is required');
            return;
        }

        const btn = document.getElementById('btnSaveProduct');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Saving...';
        hideProdError();

        try {
            if (editingId) {
                await api.updateProduct(editingId, { name, category, unit, description });
                showToast('Product updated', 'success');
            } else {
                await api.createProduct({ name, category, unit, description });
                showToast('Product created', 'success');
            }
            bootstrap.Modal.getInstance(document.getElementById('productModal')).hide();
            loadProducts();
        } catch (e) {
            showProdError(e.message);
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-check-lg me-1"></i> Save';
        }
    }

    async function deleteProduct(id, name) {
        if (!confirm(`Delete product "${name}"? This cannot be undone.`)) return;
        try {
            await api.deleteProduct(id);
            showToast('Product deleted', 'success');
            loadProducts();
        } catch (e) {
            showToast(e.message, 'danger');
        }
    }

    function showProdError(msg) {
        const el = document.getElementById('prodError');
        el.textContent = msg;
        el.classList.remove('d-none');
    }

    function hideProdError() {
        const el = document.getElementById('prodError');
        if (el) el.classList.add('d-none');
    }

    function getMockProducts() {
        return [
            { id: 'prod-001', name: 'Cabai Merah', category: 'Bumbu', unit: 'kg', is_active: true },
            { id: 'prod-002', name: 'Bawang Putih', category: 'Bumbu', unit: 'kg', is_active: true },
            { id: 'prod-003', name: 'Bawang Merah', category: 'Bumbu', unit: 'kg', is_active: true },
            { id: 'prod-004', name: 'Tomat', category: 'Sayuran', unit: 'kg', is_active: true },
            { id: 'prod-005', name: 'Kentang', category: 'Sayuran', unit: 'kg', is_active: true },
            { id: 'prod-006', name: 'Wortel', category: 'Sayuran', unit: 'kg', is_active: true },
            { id: 'prod-007', name: 'Bayam', category: 'Sayuran', unit: 'ikat', is_active: true },
            { id: 'prod-008', name: 'Kangkung', category: 'Sayuran', unit: 'ikat', is_active: true },
            { id: 'prod-009', name: 'Cabai Rawit', category: 'Bumbu', unit: 'kg', is_active: true },
            { id: 'prod-010', name: 'Beras', category: 'Sembako', unit: 'kg', is_active: true },
            { id: 'prod-011', name: 'Minyak Goreng', category: 'Sembako', unit: 'liter', is_active: true },
            { id: 'prod-012', name: 'Gula Pasir', category: 'Sembako', unit: 'kg', is_active: true },
        ];
    }

    return { init, openAddModal, openEditModal, saveProduct, deleteProduct };
})();
