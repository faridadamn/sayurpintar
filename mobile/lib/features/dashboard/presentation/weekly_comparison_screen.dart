import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';

class WeeklyComparisonScreen extends ConsumerWidget {
  const WeeklyComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyComparisonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbandingan Mingguan'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(weeklyComparisonProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: weeklyAsync.when(
        loading: () => const SPLoading(message: 'Memuat data...'),
        error: (e, _) => SPErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(weeklyComparisonProvider),
        ),
        data: (weekly) => _WeeklyContent(weekly: weekly),
      ),
    );
  }
}

class _WeeklyContent extends StatelessWidget {
  final WeeklyComparison weekly;

  const _WeeklyContent({required this.weekly});

  String _formatRp(double v) {
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekly.thisWeek;
    final lastWeek = weekly.lastWeek;
    final changes = weekly.changes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _WeekCard(
                  label: 'Minggu Ini',
                  dateRange: '${thisWeek.startDate} — ${thisWeek.endDate}',
                  revenue: _formatRp(thisWeek.totalRevenue),
                  orders: '${thisWeek.totalOrders} pesanan',
                  avgDaily: '${_formatRp(thisWeek.avgDailyRevenue)}/hari',
                  color: AppTheme.primaryGreen,
                  isCurrent: true,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: _WeekCard(
                  label: 'Minggu Lalu',
                  dateRange: '${lastWeek.startDate} — ${lastWeek.endDate}',
                  revenue: _formatRp(lastWeek.totalRevenue),
                  orders: '${lastWeek.totalOrders} pesanan',
                  avgDaily: '${_formatRp(lastWeek.avgDailyRevenue)}/hari',
                  color: AppTheme.textSecondary,
                  isCurrent: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space24),

          // ── Bar chart: daily breakdown ────────────────────────
          const Text(
            '📊 Omset Harian',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          _DailyBarChart(
            thisWeek: thisWeek,
            lastWeek: lastWeek,
            formatRp: _formatRp,
          ),
          const SizedBox(height: AppTheme.space24),

          // ── Changes ──────────────────────────────────────────
          const Text(
            '🔄 Perubahan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          _ChangeCard(
            label: 'Pendapatan',
            pct: changes.revenueChangePct,
            icon: Icons.attach_money,
          ),
          const SizedBox(height: AppTheme.space8),
          _ChangeCard(
            label: 'Jumlah Pesanan',
            pct: changes.ordersChangePct,
            icon: Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: AppTheme.space24),

          // ── Best / Worst day ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _DayHighlight(
                  icon: '🏆',
                  label: 'Hari Terbaik',
                  day: thisWeek.bestDay,
                  color: const Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: _DayHighlight(
                  icon: '📉',
                  label: 'Hari Terlemah',
                  day: thisWeek.worstDay,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space24),

          // ── Trend label ──────────────────────────────────────
          _TrendLabel(trend: changes.trend, pct: changes.revenueChangePct),
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final String label;
  final String dateRange;
  final String revenue;
  final String orders;
  final String avgDaily;
  final Color color;
  final bool isCurrent;

  const _WeekCard({
    required this.label,
    required this.dateRange,
    required this.revenue,
    required this.orders,
    required this.avgDaily,
    required this.color,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: isCurrent
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : null,
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
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateRange,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            revenue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            orders,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            avgDaily,
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

class _DailyBarChart extends StatelessWidget {
  final WeekStats thisWeek;
  final WeekStats lastWeek;
  final String Function(double) formatRp;

  const _DailyBarChart({
    required this.thisWeek,
    required this.lastWeek,
    required this.formatRp,
  });

  @override
  Widget build(BuildContext context) {
    final thisData = thisWeek.dailyBreakdown ?? [];
    final lastData = lastWeek.dailyBreakdown ?? [];

    // Find max for scaling
    double maxVal = 1;
    for (final d in thisData) {
      if (d.revenue > maxVal) maxVal = d.revenue;
    }
    for (final d in lastData) {
      if (d.revenue > maxVal) maxVal = d.revenue;
    }

    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

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
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppTheme.primaryGreen, label: 'Minggu Ini'),
              const SizedBox(width: AppTheme.space16),
              _LegendDot(
                color: AppTheme.textSecondary.withOpacity(0.4),
                label: 'Minggu Lalu',
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          // Bars
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final thisRev = i < thisData.length ? thisData[i].revenue : 0.0;
                final lastRev = i < lastData.length ? lastData[i].revenue : 0.0;
                final thisH = maxVal > 0 ? (thisRev / maxVal) : 0.0;
                final lastH = maxVal > 0 ? (lastRev / maxVal) : 0.0;
                final dayLabel = i < days.length ? days[i] : '';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Two bars side by side
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 120 * lastH,
                              constraints: const BoxConstraints(minHeight: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 10,
                              height: 120 * thisH,
                              constraints: const BoxConstraints(minHeight: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final String label;
  final double pct;
  final IconData icon;

  const _ChangeCard({
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
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
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '${isUp ? '+' : ''}${pct.toStringAsFixed(1)}% $arrow',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHighlight extends StatelessWidget {
  final String icon;
  final String label;
  final String day;
  final Color color;

  const _DayHighlight({
    required this.icon,
    required this.label,
    required this.day,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day.isNotEmpty ? day : '-',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLabel extends StatelessWidget {
  final String trend;
  final double pct;

  const _TrendLabel({required this.trend, required this.pct});

  @override
  Widget build(BuildContext context) {
    final isUp = trend == 'up' || pct >= 0;
    final emoji = isUp ? '🎉' : '📉';
    final text = isUp
        ? 'Minggu ini naik ${pct.toStringAsFixed(1)}%!'
        : 'Minggu ini turun ${pct.abs().toStringAsFixed(1)}%';
    final color = isUp ? AppTheme.primaryGreen : AppTheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUp
              ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
              : [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUp ? 'Pertahankan performa ini!' : 'Ayo semangat minggu depan!',
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
