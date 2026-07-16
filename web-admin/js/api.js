/* ── SayurPintar Admin API Client ── */

class AdminAPI {
    constructor(baseURL) {
        this.baseURL = baseURL || '/api/v1';
        this.token = localStorage.getItem('sp_admin_token') || '';
    }

    setToken(token) {
        this.token = token;
        localStorage.setItem('sp_admin_token', token);
    }

    clearToken() {
        this.token = '';
        localStorage.removeItem('sp_admin_token');
    }

    async _request(method, path, body, params) {
        let url = `${this.baseURL}${path}`;
        if (params) {
            const qs = new URLSearchParams();
            for (const [k, v] of Object.entries(params)) {
                if (v !== undefined && v !== null && v !== '') qs.append(k, v);
            }
            const qsStr = qs.toString();
            if (qsStr) url += `?${qsStr}`;
        }

        const headers = { 'Content-Type': 'application/json' };
        if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

        const opts = { method, headers };
        if (body && method !== 'GET') opts.body = JSON.stringify(body);

        const res = await fetch(url, opts);

        if (res.status === 401) {
            this.clearToken();
            window.location.reload();
            throw new Error('Session expired');
        }

        const data = await res.json();
        if (!res.ok) {
            throw new Error(data?.error?.message || `HTTP ${res.status}`);
        }
        return data;
    }

    // ── Auth ──

    async sendOTP(phone) {
        return this._request('POST', '/auth/send-otp', { phone });
    }

    async verifyOTP(phone, otp) {
        const data = await this._request('POST', '/auth/verify-otp', { phone, otp });
        if (data?.data?.access_token) {
            this.setToken(data.data.access_token);
        }
        return data;
    }

    async getProfile() {
        return this._request('GET', '/auth/profile');
    }

    // ── Dashboard ──

    async getDashboardStats() {
        return this._request('GET', '/analytics/dashboard');
    }

    // ── Users ──

    async getUsers(params) {
        return this._request('GET', '/admin/users', null, params);
    }

    async getUserDetail(id) {
        return this._request('GET', `/admin/users/${id}`);
    }

    async verifyUser(id) {
        return this._request('POST', `/admin/users/${id}/verify`);
    }

    async banUser(id) {
        return this._request('POST', `/admin/users/${id}/ban`);
    }

    async unbanUser(id) {
        return this._request('POST', `/admin/users/${id}/unban`);
    }

    // ── Prices ──

    async getPrices(params) {
        return this._request('GET', '/admin/prices', null, params);
    }

    async flagPrice(id) {
        return this._request('POST', `/admin/prices/${id}/flag`);
    }

    async deletePrice(id) {
        return this._request('DELETE', `/admin/prices/${id}`);
    }

    async getPriceHistory(productId, area) {
        return this._request('GET', `/prices/trend/${productId}`, null, { area, days: 30 });
    }

    // ── Products ──

    async getProducts() {
        return this._request('GET', '/products');
    }

    async getProduct(id) {
        return this._request('GET', `/products/${id}`);
    }

    async createProduct(data) {
        return this._request('POST', '/products', data);
    }

    async updateProduct(id, data) {
        return this._request('PUT', `/products/${id}`, data);
    }

    async deleteProduct(id) {
        return this._request('DELETE', `/products/${id}`);
    }

    async getCategories() {
        return this._request('GET', '/products/categories');
    }

    // ── Orders ──

    async getOrders(params) {
        return this._request('GET', '/admin/orders', null, params);
    }

    // ── Groups (GrosirKu) ──

    async getGroupOrders(params) {
        return this._request('GET', '/groups', null, params);
    }

    async getGroupOrderDetail(id) {
        return this._request('GET', `/groups/${id}`);
    }

    // ── Suppliers ──

    async getSuppliers() {
        return this._request('GET', '/suppliers');
    }
}

// Singleton
const api = new AdminAPI();
