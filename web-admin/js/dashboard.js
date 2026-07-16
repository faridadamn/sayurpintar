/* ── SayurPintar Admin Dashboard Module ── */

const Dashboard = (() => {
    let userGrowthChart = null;
    let orderVolumeChart = null;
    let revenueChart = null;

    function init() {
        loadStats();
    }

    async function loadStats() {
        const container = document.getElementById('pageContent');
        container.innerHTML = renderLoading();

        try {
            // Fetch dashboard data (falls back gracefully if endpoint not available)
            let stats = null;
            try {
                const res = await api.getDashboardStats();
                stats = res.data;
            } catch (e) {
                // Endpoint may not exist yet — use mock data
                stats = getMockStats();
            }

            container.innerHTML = renderDashboard(stats);
            initCharts(stats);
        } catch (e) {
            container.innerHTML = renderError(e.message);
        }
    }

    function renderDashboard(stats) {
        return `
        <div class="row g-3 mb-4">
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#e8f5e9;color:#2e7d32">
                        <i class="bi bi-people"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.totalUsers)}</div>
                    <div class="stat-label">Total Users</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#e3f2fd;color:#1565c0">
                        <i class="bi bi-shop"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.totalPedagang)}</div>
                    <div class="stat-label">Pedagang</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#fff3e0;color:#e65100">
                        <i class="bi bi-cart"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.ordersToday)}</div>
                    <div class="stat-label">Orders Today</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#fce4ec;color:#c62828">
                        <i class="bi bi-cash-stack"></i>
                    </div>
                    <div class="stat-value">Rp ${formatCurrency(stats.revenueMonth)}</div>
                    <div class="stat-label">Revenue (Month)</div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#f3e5f5;color:#7b1fa2">
                        <i class="bi bi-person-check"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.totalPelanggan)}</div>
                    <div class="stat-label">Pelanggan</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#e0f7fa;color:#00838f">
                        <i class="bi bi-graph-up-arrow"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.ordersWeek)}</div>
                    <div class="stat-label">Orders This Week</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#fff8e1;color:#f9a825">
                        <i class="bi bi-tag"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.priceSubmissions)}</div>
                    <div class="stat-label">Price Submissions</div>
                </div>
            </div>
            <div class="col-6 col-lg-3">
                <div class="stat-card">
                    <div class="stat-icon" style="background:#e8eaf6;color:#283593">
                        <i class="bi bi-box-seam"></i>
                    </div>
                    <div class="stat-value">${formatNumber(stats.totalProducts)}</div>
                    <div class="stat-label">Products</div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-lg-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <h6><i class="bi bi-people me-2"></i>User Growth</h6>
                    </div>
                    <div class="card-body-custom">
                        <div class="chart-container"><canvas id="chartUserGrowth"></canvas></div>
                    </div>
                </div>
            </div>
            <div class="col-lg-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <h6><i class="bi bi-bar-chart me-2"></i>Order Volume</h6>
                    </div>
                    <div class="card-body-custom">
                        <div class="chart-container"><canvas id="chartOrderVolume"></canvas></div>
                    </div>
                </div>
            </div>
            <div class="col-lg-4">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <h6><i class="bi bi-currency-dollar me-2"></i>Revenue Trend</h6>
                    </div>
                    <div class="card-body-custom">
                        <div class="chart-container"><canvas id="chartRevenue"></canvas></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3">
            <div class="col-lg-6">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <h6><i class="bi bi-clock-history me-2"></i>Recent Orders</h6>
                    </div>
                    <div class="card-body-custom p-0">
                        <table class="table table-custom mb-0">
                            <thead><tr>
                                <th>Order ID</th><th>Customer</th><th>Amount</th><th>Status</th>
                            </tr></thead>
                            <tbody>
                                ${(stats.recentOrders || []).map(o => `
                                <tr>
                                    <td><code class="small">${o.id?.substring(0, 8) || '—'}</code></td>
                                    <td>${o.customer || '—'}</td>
                                    <td>Rp ${formatCurrency(o.amount)}</td>
                                    <td><span class="badge-status badge-active">${o.status || 'completed'}</span></td>
                                </tr>`).join('') || '<tr><td colspan="4" class="text-center text-muted py-3">No recent orders</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
            <div class="col-lg-6">
                <div class="card-custom">
                    <div class="card-header-custom">
                        <h6><i class="bi bi-exclamation-triangle me-2"></i>Price Alerts</h6>
                    </div>
                    <div class="card-body-custom p-0">
                        <table class="table table-custom mb-0">
                            <thead><tr>
                                <th>Product</th><th>Area</th><th>Change</th><th>Alert</th>
                            </tr></thead>
                            <tbody>
                                ${(stats.priceAlerts || []).map(a => `
                                <tr>
                                    <td>${a.product || '—'}</td>
                                    <td>${a.area || '—'}</td>
                                    <td class="${a.change > 0 ? 'text-danger' : 'text-success'}">${a.change > 0 ? '+' : ''}${a.change}%</td>
                                    <td><span class="badge-status ${a.change > 5 ? 'badge-inactive' : 'badge-pending'}">${a.change > 5 ? 'High' : 'Normal'}</span></td>
                                </tr>`).join('') || '<tr><td colspan="4" class="text-center text-muted py-3">No price alerts</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>`;
    }

    function initCharts(stats) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
        const chartOpts = {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                x: { grid: { display: false }, ticks: { font: { size: 11 } } },
                y: { grid: { color: '#f0f0f0' }, ticks: { font: { size: 11 } } }
            }
        };

        // User Growth
        const ctx1 = document.getElementById('chartUserGrowth');
        if (ctx1) {
            if (userGrowthChart) userGrowthChart.destroy();
            userGrowthChart = new Chart(ctx1, {
                type: 'line',
                data: {
                    labels: months,
                    datasets: [{
                        label: 'Users',
                        data: stats.userGrowth || [120, 180, 250, 340, 420, 510, 630],
                        borderColor: '#198754',
                        backgroundColor: 'rgba(25,135,84,0.1)',
                        fill: true,
                        tension: 0.4,
                        pointRadius: 3
                    }]
                },
                options: chartOpts
            });
        }

        // Order Volume
        const ctx2 = document.getElementById('chartOrderVolume');
        if (ctx2) {
            if (orderVolumeChart) orderVolumeChart.destroy();
            orderVolumeChart = new Chart(ctx2, {
                type: 'bar',
                data: {
                    labels: months,
                    datasets: [{
                        label: 'Orders',
                        data: stats.orderVolume || [45, 68, 92, 110, 135, 158, 180],
                        backgroundColor: 'rgba(21,101,192,0.8)',
                        borderRadius: 6
                    }]
                },
                options: chartOpts
            });
        }

        // Revenue Trend
        const ctx3 = document.getElementById('chartRevenue');
        if (ctx3) {
            if (revenueChart) revenueChart.destroy();
            revenueChart = new Chart(ctx3, {
                type: 'line',
                data: {
                    labels: months,
                    datasets: [{
                        label: 'Revenue (Rp)',
                        data: stats.revenueTrend || [12000000, 18500000, 24000000, 31000000, 38000000, 42000000, 51000000],
                        borderColor: '#c62828',
                        backgroundColor: 'rgba(198,40,40,0.08)',
                        fill: true,
                        tension: 0.4,
                        pointRadius: 3
                    }]
                },
                options: {
                    ...chartOpts,
                    scales: {
                        ...chartOpts.scales,
                        y: {
                            ...chartOpts.scales.y,
                            ticks: {
                                ...chartOpts.scales.y.ticks,
                                callback: v => 'Rp ' + (v / 1000000).toFixed(0) + 'M'
                            }
                        }
                    }
                }
            });
        }
    }

    function getMockStats() {
        return {
            totalUsers: 630,
            totalPedagang: 280,
            totalPelanggan: 350,
            ordersToday: 42,
            ordersWeek: 180,
            revenueMonth: 51000000,
            priceSubmissions: 1240,
            totalProducts: 85,
            userGrowth: [120, 180, 250, 340, 420, 510, 630],
            orderVolume: [45, 68, 92, 110, 135, 158, 180],
            revenueTrend: [12000000, 18500000, 24000000, 31000000, 38000000, 42000000, 51000000],
            recentOrders: [
                { id: 'ord-a1b2c3d4', customer: 'Pak Budi', amount: 285000, status: 'completed' },
                { id: 'ord-e5f6g7h8', customer: 'Ibu Sari', amount: 150000, status: 'pending' },
                { id: 'ord-i9j0k1l2', customer: 'Pak Joko', amount: 420000, status: 'completed' },
                { id: 'ord-m3n4o5p6', customer: 'Ibu Rina', amount: 95000, status: 'completed' },
                { id: 'ord-q7r8s9t0', customer: 'Pak Andi', amount: 310000, status: 'processing' }
            ],
            priceAlerts: [
                { product: 'Cabai Merah', area: 'Jakarta Selatan', change: 12.5 },
                { product: 'Bawang Putih', area: 'Jakarta Timur', change: -3.2 },
                { product: 'Tomat', area: 'Jakarta Barat', change: 8.1 },
                { product: 'Kentang', area: 'Jakarta Utara', change: -1.5 }
            ]
        };
    }

    return { init };
})();
