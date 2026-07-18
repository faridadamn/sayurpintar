import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';

class DailySummaryScreen extends ConsumerStatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  ConsumerState<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends ConsumerState<DailySummaryScreen> {
  String _formatRp(double v) {
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    final str = v.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Pagi';
    if (h < 15) return 'Siang';
    if (h < 18) return 'Sore';
    return 'Malam';
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dailySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Harian'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(dailySummaryProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const SPLoading(message: 'Memuat ringkasan...'),
        error: (e, _) => SPErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(dailySummaryProvider),
        ),
        data: (summary) => _SummaryContent(
          summary: summary,
          formatRp: _formatRp,
          greeting: _greeting(),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final DailySummary summary;
  final String Function(double) formatRp;
  final String greeting;

  const _SummaryContent({
    required this.summary,
    required this.formatRp,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header ───────────────────────────────────────
            _DateHeader(date: summary.date, greeting: greeting),
            const SizedBox(height: AppTheme.space16),

            // ── Main stats grid ──────────────────────────────────
            _MainStatsGrid(summary: summary, formatRp: formatRp),
            const SizedBox(height: AppTheme.space24),

            // ── Revenue breakdown ────────────────────────────────
            _SectionTitle(title: '💰 Rincian Pendapatan'),
            const SizedBox(height: AppTheme.space8),
            _RevenueBreakdown(summary: summary, formatRp: formatRp),
            const SizedBox(height: AppTheme.space24),

            // ── Order status ─────────────────────────────────────
            _SectionTitle(title: '📦 Status Pesanan'),
            const SizedBox(height: AppTheme.space8),
            _OrderStatusBreakdown(summary: summary),
            const SizedBox(height: AppTheme.space24),

            // ── Route stats ──────────────────────────────────────
            _SectionTitle(title: '🗺️ Statistik Rute'),
            const SizedBox(height: AppTheme.space8),
            _RouteStats(summary: summary),
            const SizedBox(height: AppTheme.space24),

            // ── Piutang ──────────────────────────────────────────
            if (summary.totalPiutang > 0) ...[
              _SectionTitle(title: '📋 Piutang'),
              const SizedBox(height: AppTheme.space8),
              _PiutangCard(summary: summary, formatRp: formatRp),
              const SizedBox(height: AppTheme.space24),
            ],

            // ── Top items today ──────────────────────────────────
            if (summary.topItems.isNotEmpty) ...[
              _SectionTitle(title: '🏆 Produk Terlaris Hari Ini'),
              const SizedBox(height: AppTheme.space8),
              _TopItemsList(items: summary.topItems, formatRp: formatRp),
              const SizedBox(height: AppTheme.space24),
            ],

            // ── Comparison vs yesterday ──────────────────────────
            _SectionTitle(title: '📊 Dibanding Kemarin'),
            const SizedBox(height: AppTheme.space8),
            _YesterdayComparison(summary: summary, formatRp: formatRp),
            const SizedBox(height: AppTheme.space32),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  final String greeting;

  const _DateHeader({required this.date, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 6),
              Text(
                date.isNotEmpty ? date : 'Hari Ini',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'Selamat $greeting 👋',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MainStatsGrid extends StatelessWidget {
  final DailySummary summary;
  final String Function(double) formatRp;

  const _MainStatsGrid({required this.summary, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppTheme.space12,
      crossAxisSpacing: AppTheme.space12,
      childAspectRatio: 1.6,
      children: [
        _StatTile(
          icon: Icons.attach_money,
          label: 'Omset',
          value: formatRp(summary.totalRevenue),
          color: AppTheme.primaryGreen,
        ),
        _StatTile(
          icon: Icons.trending_up,
          label: 'Keuntungan',
          value: formatRp(summary.grossProfit),
          color: const Color(0xFFFF9800),
        ),
        _StatTile(
          icon: Icons.shopping_bag,
          label: 'Total Pesanan',
          value: '${summary.totalOrders}',
          color: const Color(0xFF1565C0),
        ),
        _StatTile(
          icon: Icons.repeat,
          label: 'Langganan Aktif',
          value: '${summary.activeSubscriptions}',
          color: const Color(0xFF7B1FA2),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Nunito',
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _RevenueBreakdown extends StatelessWidget {
  final DailySummary summary;
  final String Function(double) formatRp;

  const _RevenueBreakdown({required this.summary, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _BreakdownRow(
            icon: Icons.money,
            label: 'Tunai',
            value: formatRp(summary.cashRevenue),
            color: const Color(0xFF4CAF50),
          ),
          const Divider(height: 24),
          _BreakdownRow(
            icon: Icons.qr_code,
            label: 'QRIS',
            value: formatRp(summary.qrisRevenue),
            color: const Color(0xFF2196F3),
          ),
          const Divider(height: 24),
          _BreakdownRow(
            icon: Icons.account_balance,
            label: 'Transfer',
            value: formatRp(summary.transferRevenue),
            color: const Color(0xFF9C27B0),
          ),
          const Divider(height: 24),
          _BreakdownRow(
            icon: Icons.shopping_cart,
            label: 'Pengeluaran',
            value: formatRp(summary.totalExpenses),
            color: AppTheme.error,
          ),
          const Divider(height: 24),
          _BreakdownRow(
            icon: Icons.account_balance_wallet,
            label: 'Margin',
            value: '${summary.profitMargin.toStringAsFixed(1)}%',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _OrderStatusBreakdown extends StatelessWidget {
  final DailySummary summary;

  const _OrderStatusBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalOrders;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (summary.deliveredOrders > 0)
                    Expanded(
                      flex: summary.deliveredOrders,
                      child: Container(
                        height: 8,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  if (summary.pendingOrders > 0)
                    Expanded(
                      flex: summary.pendingOrders,
                      child: Container(
                        height: 8,
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                  if (summary.cancelledOrders > 0)
                    Expanded(
                      flex: summary.cancelledOrders,
                      child: Container(
                        height: 8,
                        color: AppTheme.error,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatusChip(
                count: summary.deliveredOrders,
                label: 'Selesai',
                color: AppTheme.primaryGreen,
              ),
              _StatusChip(
                count: summary.pendingOrders,
                label: 'Pending',
                color: const Color(0xFFFFC107),
              ),
              _StatusChip(
                count: summary.cancelledOrders,
                label: 'Batal',
                color: AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatusChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Nunito',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RouteStats extends StatelessWidget {
  final DailySummary summary;

  const _RouteStats({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RouteStatItem(
            icon: Icons.straighten,
            value: '${summary.routeDistanceKm.toStringAsFixed(1)} km',
            label: 'Jarak',
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          _RouteStatItem(
            icon: Icons.timer_outlined,
            value: '${summary.routeDurationMin} menit',
            label: 'Durasi',
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          _RouteStatItem(
            icon: Icons.check_circle_outline,
            value:
                '${summary.visitsCompleted}/${summary.visitsCompleted + summary.visitsSkipped}',
            label: 'Kunjungan',
          ),
        ],
      ),
    );
  }
}

class _RouteStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _RouteStatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PiutangCard extends StatelessWidget {
  final DailySummary summary;
  final String Function(double) formatRp;

  const _PiutangCard({required this.summary, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF9800),
            size: 28,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRp(summary.totalPiutang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                    fontFamily: 'Nunito',
                  ),
                ),
                Text(
                  '${summary.piutangCount} pelanggan belum membayar',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF795548),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopItemsList extends StatelessWidget {
  final List<TopItem> items;
  final String Function(double) formatRp;

  const _TopItemsList({required this.items, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final medals = ['🥇', '🥈', '🥉'];
          final medal = i < 3 ? medals[i] : '${i + 1}';

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space12,
              vertical: AppTheme.space10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    medal,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${item.totalQty.toStringAsFixed(1)} ${item.unit} • ${item.orderCount} pesanan',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRp(item.totalRevenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _YesterdayComparison extends StatelessWidget {
  final DailySummary summary;
  final String Function(double) formatRp;

  const _YesterdayComparison({required this.summary, required this.formatRp});

  @override
  Widget build(BuildContext context) {
    final revPct = summary.revenueVsYesterday;
    final orderPct = summary.ordersVsYesterday;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _ComparisonRow(
            label: 'Pendapatan',
            pct: revPct,
            icon: Icons.attach_money,
          ),
          const Divider(height: 24),
          _ComparisonRow(
            label: 'Jumlah Pesanan',
            pct: orderPct,
            icon: Icons.shopping_bag_outlined,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double pct;
  final IconData icon;

  const _ComparisonRow({
    required this.label,
    required this.pct,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = pct >= 0;
    final arrow = isUp ? '↑' : '↓';
    final color = isUp ? AppTheme.primaryGreen : AppTheme.error;
    final bg = isUp ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            '${isUp ? '+' : ''}${pct.toStringAsFixed(1)}% $arrow',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
