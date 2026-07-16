import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_bottom_sheet.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class SubscribersScreen extends ConsumerStatefulWidget {
  const SubscribersScreen({super.key});

  @override
  ConsumerState<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends ConsumerState<SubscribersScreen> {
  String _statusFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final subscribersAsync = ref.watch(subscribersProvider);
    final statsAsync = ref.watch(subscriberStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan Langganan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () {
              ref.invalidate(subscribersProvider);
              ref.invalidate(subscriberStatsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Stats Card ─────────────────────────────────────────────
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _StatsCard(stats: stats),
          ),

          // ── Filter ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space8,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Aktif',
                  value: 'active',
                  selected: _statusFilter == 'active',
                  onTap: () => setState(() => _statusFilter = 'active'),
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: AppTheme.space8),
                _FilterChip(
                  label: 'Dijeda',
                  value: 'paused',
                  selected: _statusFilter == 'paused',
                  onTap: () => setState(() => _statusFilter = 'paused'),
                  color: Colors.orange,
                ),
                const SizedBox(width: AppTheme.space8),
                _FilterChip(
                  label: 'Dibatalkan',
                  value: 'cancelled',
                  selected: _statusFilter == 'cancelled',
                  onTap: () =>
                      setState(() => _statusFilter = 'cancelled'),
                  color: AppTheme.error,
                ),
              ],
            ),
          ),

          // ── Subscriber List ────────────────────────────────────────
          Expanded(
            child: subscribersAsync.when(
              loading: () =>
                  const SPLoading(message: 'Memuat pelanggan...'),
              error: (error, _) => SPErrorWidget(
                message: 'Gagal memuat pelanggan: $error',
                onRetry: () => ref.invalidate(subscribersProvider),
              ),
              data: (subscribers) {
                final filtered = subscribers
                    .where((s) => s.status == _statusFilter)
                    .toList();

                if (filtered.isEmpty) {
                  return SPEmptyState(
                    icon: Icons.people_outline,
                    title: 'Tidak Ada Pelanggan',
                    message: _statusFilter == 'active'
                        ? 'Belum ada pelanggan aktif'
                        : 'Tidak ada pelanggan dengan status ini',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(subscribersProvider);
                    ref.invalidate(subscriberStatsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space16,
                      0,
                      AppTheme.space16,
                      AppTheme.space16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _SubscriberCard(
                        subscription: filtered[index],
                        onTap: () => _showSubscriberDetail(
                          context,
                          filtered[index],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriberDetail(
      BuildContext context, Subscription subscription) {
    SPBottomSheet.show(
      context,
      title: 'Detail Pelanggan',
      child: _SubscriberDetailContent(subscription: subscription),
    );
  }
}

// ── Stats Card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final SubscriberStats stats;

  const _StatsCard({required this.stats});

  String _formatCurrency(double value) {
    final parts = value.toInt().toString().split('');
    final result = <String>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      result.insert(0, parts[i]);
      if ((parts.length - i) % 3 == 0 && i != 0) {
        result.insert(0, '.');
      }
    }
    return 'Rp ${result.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space8,
        AppTheme.space16,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Total',
            value: '${stats.totalSubscribers}',
            icon: Icons.people,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          _StatItem(
            label: 'Aktif',
            value: '${stats.activeSubscribers}',
            icon: Icons.check_circle,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white24,
          ),
          _StatItem(
            label: 'Pendapatan',
            value: _formatCurrency(stats.monthlyRevenue),
            icon: Icons.payments,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: AppTheme.space4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected ? color : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Subscriber Card ──────────────────────────────────────────────────────────

class _SubscriberCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;

  const _SubscriberCard({
    required this.subscription,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SPCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
      child: Row(
        children: [
          SPAvatar(
            name: subscription.pelangganName ?? 'P',
            radius: 22,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.pelangganName ?? 'Pelanggan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subscription.packageName ?? 'Paket',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    subscription.nextDelivery ?? '-',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  subscription.paymentMethodText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Subscriber Detail Content ────────────────────────────────────────────────

class _SubscriberDetailContent extends StatelessWidget {
  final Subscription subscription;

  const _SubscriberDetailContent({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SPAvatar(
            name: subscription.pelangganName ?? 'P',
            radius: 36,
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        Center(
          child: Text(
            subscription.pelangganName ?? 'Pelanggan',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        if (subscription.pelangganPhone != null)
          Center(
            child: Text(
              subscription.pelangganPhone!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: AppTheme.space16),
        const Divider(),
        _DetailRow(
          icon: Icons.inventory_2,
          label: 'Paket',
          value: subscription.packageName ?? '-',
        ),
        _DetailRow(
          icon: Icons.calendar_today,
          label: 'Mulai',
          value: subscription.startDate,
        ),
        _DetailRow(
          icon: Icons.event,
          label: 'Pengiriman Berikutnya',
          value: subscription.nextDelivery ?? '-',
        ),
        _DetailRow(
          icon: Icons.payment,
          label: 'Pembayaran',
          value: subscription.paymentMethodText,
        ),
        _DetailRow(
          icon: Icons.info_outline,
          label: 'Status',
          value: subscription.statusText,
        ),
        const SizedBox(height: AppTheme.space16),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.space12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
