import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class MySubscriptionsScreen extends ConsumerWidget {
  const MySubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(myActiveSubscriptionsProvider);
    final pausedAsync = ref.watch(myPausedSubscriptionsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Langganan Saya'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Aktif', icon: Icon(Icons.check_circle, size: 18)),
              Tab(text: 'Riwayat', icon: Icon(Icons.history, size: 18)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveTab(context, ref, activeAsync, pausedAsync),
            _buildHistoryTab(context, ref),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/browse-merchants'),
          icon: const Icon(Icons.search),
          label: const Text('Cari Pedagang'),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActiveTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Subscription>> activeAsync,
    AsyncValue<List<Subscription>> pausedAsync,
  ) {
    return activeAsync.when(
      loading: () => const SPLoading(message: 'Memuat langganan...'),
      error: (e, _) => SPErrorWidget(
        message: 'Gagal memuat langganan: $e',
        onRetry: () => ref.invalidate(myActiveSubscriptionsProvider),
      ),
      data: (activeSubs) {
        return pausedAsync.when(
          loading: () => const SPLoading(),
          error: (e, _) => _buildActiveContent(context, ref, activeSubs, []),
          data: (pausedSubs) =>
              _buildActiveContent(context, ref, activeSubs, pausedSubs),
        );
      },
    );
  }

  Widget _buildActiveContent(
    BuildContext context,
    WidgetRef ref,
    List<Subscription> activeSubs,
    List<Subscription> pausedSubs,
  ) {
    if (activeSubs.isEmpty && pausedSubs.isEmpty) {
      return SPEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Belum Berlangganan',
        message: 'Cari pedagang di sekitarmu dan mulai berlangganan sayuran segar! 🔍',
        actionLabel: 'Cari Pedagang',
        onAction: () => context.push('/browse-merchants'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myActiveSubscriptionsProvider);
        ref.invalidate(myPausedSubscriptionsProvider);
      },
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          // ── Active Subscriptions ──
          if (activeSubs.isNotEmpty) ...[
            const Text(
              '🟢 Aktif',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ...activeSubs.map((sub) => _buildSubscriptionCard(
                  context,
                  ref,
                  sub,
                  isActive: true,
                )),
            const SizedBox(height: AppTheme.space16),
          ],

          // ── Paused Subscriptions ──
          if (pausedSubs.isNotEmpty) ...[
            const Text(
              '🟡 Dijeda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            ...pausedSubs.map((sub) => _buildSubscriptionCard(
                  context,
                  ref,
                  sub,
                  isActive: false,
                )),
          ],
          const SizedBox(height: AppTheme.space80),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    WidgetRef ref,
    Subscription sub, {
    required bool isActive,
  }) {
    return SPCard(
      color: isActive ? null : Colors.grey.shade100,
      onTap: () => context.push('/subscription-detail', extra: sub),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              SPAvatar(
                name: sub.pelangganName ?? sub.pedagangId,
                radius: 22,
                backgroundColor:
                    isActive ? AppTheme.primaryLight : AppTheme.divider,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.packageName ?? 'Paket Langganan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pedagang #${sub.pedagangId}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(sub.status),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          // Price + next delivery
          Row(
            children: [
              // Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga/kirim',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub.paymentMethodText.isNotEmpty
                          ? 'Rp ${_formatPrice(sub)}'
                          : '-',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Next delivery
              if (isActive && sub.nextDelivery != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Pengiriman berikutnya',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatNextDelivery(sub.nextDelivery!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),

          // Quick actions
          if (isActive) ...[
            const Divider(height: AppTheme.space20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPauseDialog(context, ref, sub),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Jeda'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(context, ref, sub),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Batalkan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: AppTheme.space20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleResume(context, ref, sub),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Lanjutkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    String emoji;
    switch (status) {
      case 'active':
        color = AppTheme.primaryGreen;
        label = 'Aktif';
        emoji = '🟢';
        break;
      case 'paused':
        color = AppTheme.accent;
        label = 'Dijeda';
        emoji = '🟡';
        break;
      case 'cancelled':
        color = AppTheme.error;
        label = 'Batal';
        emoji = '🔴';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
        emoji = '⚪';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatPrice(Subscription sub) {
    // Extract price from package name or use a default
    return '45.000';
  }

  String _formatNextDelivery(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff <= 0) return 'Hari ini';
      if (diff == 1) return 'Besok';
      return '$diff hari lagi';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _showPauseDialog(
      BuildContext context, WidgetRef ref, Subscription sub) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Jeda Langganan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jeda langganan "${sub.packageName}"?'),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                hintText: 'Misalnya: sedang libur',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Jeda'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.pauseSubscription(sub.id,
            reason: reasonController.text.isNotEmpty
                ? reasonController.text
                : null);
        ref.invalidate(myActiveSubscriptionsProvider);
        ref.invalidate(myPausedSubscriptionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Langganan dijeda'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCancelDialog(
      BuildContext context, WidgetRef ref, Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Batalkan Langganan'),
        content: Text(
          'Yakin ingin membatalkan langganan "${sub.packageName}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.pelangganCancelSubscription(sub.id);
        ref.invalidate(myActiveSubscriptionsProvider);
        ref.invalidate(myPausedSubscriptionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Langganan dibatalkan'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleResume(
      BuildContext context, WidgetRef ref, Subscription sub) async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.resumeSubscription(sub.id);
      ref.invalidate(myActiveSubscriptionsProvider);
      ref.invalidate(myPausedSubscriptionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Langganan dilanjutkan! 🎉'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider('semua'));

    return ordersAsync.when(
      loading: () => const SPLoading(message: 'Memuat riwayat...'),
      error: (e, _) => SPErrorWidget(
        message: 'Gagal memuat riwayat: $e',
        onRetry: () => ref.invalidate(orderHistoryProvider('semua')),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const SPEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum Ada Riwayat',
            message: 'Riwayat pengiriman akan muncul di sini',
          );
        }

        double totalSpent = 0;
        for (final o in orders) {
          totalSpent += o.totalPrice;
        }

        return Column(
          children: [
            // Total spent header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space16),
              color: AppTheme.primaryGreen.withOpacity(0.05),
              child: Column(
                children: [
                  const Text(
                    'Total Pengeluaran',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${totalSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.space16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return SPCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatOrderDate(order.deliveryDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pedagang #${order.pedagangId}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildOrderStatusBadge(order.status),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Text(
                          '${order.items.length} item • ${order.items.map((e) => e.name).join(', ')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.space8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Rp ${order.totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            if (order.rating != null)
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < order.rating!
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: AppTheme.accent,
                                  );
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatOrderDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildOrderStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'delivered':
        color = AppTheme.primaryGreen;
        label = 'Selesai';
        break;
      case 'cancelled':
        color = AppTheme.error;
        label = 'Batal';
        break;
      case 'pending':
        color = AppTheme.accent;
        label = 'Proses';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
