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

class SubscriptionDetailScreen extends ConsumerStatefulWidget {
  final Subscription subscription;
  const SubscriptionDetailScreen({super.key, required this.subscription});

  @override
  ConsumerState<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState
    extends ConsumerState<SubscriptionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _dayNames = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatRupiah(double n) {
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  List<String> _getNextDeliveryDates() {
    final now = DateTime.now();
    final dates = <String>[];
    var check = now.add(const Duration(days: 1));
    while (dates.length < 5) {
      dates.add(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(check));
      check = check.add(const Duration(days: 7));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final detailAsync = ref.watch(subscriptionDetailProvider(sub.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Langganan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => _contactPedagang(sub),
            tooltip: 'Hubungi Pedagang',
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const SPLoading(message: 'Memuat detail...'),
        error: (e, _) => SPErrorWidget(
          message: 'Gagal memuat detail: $e',
          onRetry: () => ref.invalidate(subscriptionDetailProvider(sub.id)),
        ),
        data: (detail) => _buildContent(context, ref, sub, detail),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
    SubscriptionDetail detail,
  ) {
    return Column(
      children: [
        // ── Header ──
        _buildHeader(sub, detail),

        // ── Tab Bar ──
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Berikutnya'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Pembayaran'),
            ],
          ),
        ),

        // ── Tab Content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNextDeliveryTab(context, ref, sub, detail),
              _buildHistoryTab(context, ref, sub, detail),
              _buildPaymentTab(context, ref, sub, detail),
            ],
          ),
        ),

        // ── Action Buttons ──
        _buildActionButtons(context, ref, sub),
      ],
    );
  }

  Widget _buildHeader(Subscription sub, SubscriptionDetail detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SPAvatar(
                name: sub.pelangganName ?? sub.pedagangId,
                radius: 28,
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.packageName ?? 'Paket Langganan',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedagang #${sub.pedagangId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(sub.status),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Kiriman', '${detail.deliveryCount}'),
              _buildStatItem('Total Belanja', _formatRupiah(detail.totalSpent)),
              _buildStatItem('Metode Bayar', sub.paymentMethodText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildStatusChip(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNextDeliveryTab(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
    SubscriptionDetail detail,
  ) {
    final nextDates = _getNextDeliveryDates();
    final packageItems = detail.package?.items ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Next Delivery Card ──
          SPCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Pengiriman Berikutnya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                if (sub.nextDelivery != null) ...[
                  Text(
                    _formatDate(sub.nextDelivery!),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _countdownLabel(sub.nextDelivery!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ] else
                  const Text(
                    'Menunggu jadwal berikutnya',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                if (packageItems.isNotEmpty) ...[
                  const Divider(height: AppTheme.space20),
                  const Text(
                    'Item pengiriman:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  ...packageItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Text('🥬 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                '${item.name} — ${item.qty} ${item.unit}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              _formatRupiah(item.subtotal),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: AppTheme.space12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/modify-delivery', extra: {
                            'subscription': sub,
                            'date': sub.nextDelivery ?? '',
                          });
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Ubah Pesanan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _skipDelivery(context, ref, sub),
                        icon: const Icon(Icons.skip_next, size: 16),
                        label: const Text('Lewati'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          side: const BorderSide(color: AppTheme.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // ── Delivery Schedule ──
          const Text(
            '📅 Jadwal Pengiriman',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          SPCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: nextDates.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: entry.key == 0
                              ? AppTheme.primaryGreen
                              : AppTheme.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: entry.key == 0
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: entry.key == 0
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: entry.key == 0
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (entry.key == 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Text(
                            'Berikutnya',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppTheme.space80),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
    SubscriptionDetail detail,
  ) {
    final history = detail.recentModifications;

    if (history.isEmpty) {
      return const SPEmptyState(
        icon: Icons.history,
        title: 'Belum Ada Riwayat',
        message: 'Riwayat pengiriman akan muncul di sini setelah pengiriman pertama',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final mod = history[index];
        return SPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    mod.skipDelivery
                        ? Icons.skip_next
                        : Icons.local_shipping,
                    size: 18,
                    color: mod.skipDelivery
                        ? AppTheme.accent
                        : AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatShortDate(mod.deliveryDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (mod.skipDelivery)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Text(
                        'Dilewati',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                ],
              ),
              if (mod.items != null && mod.items!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space8),
                ...mod.items!.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Text('🥬 ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              '${item.name} — ${item.qty} ${item.unit}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              if (mod.reason != null && mod.reason!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Alasan: ${mod.reason}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentTab(
    BuildContext context,
    WidgetRef ref,
    Subscription sub,
    SubscriptionDetail detail,
  ) {
    final paymentsAsync = ref.watch(paymentHistoryProvider(sub.id));

    return paymentsAsync.when(
      loading: () => const SPLoading(message: 'Memuat riwayat pembayaran...'),
      error: (e, _) => SPErrorWidget(
        message: 'Gagal memuat pembayaran: $e',
        onRetry: () => ref.invalidate(paymentHistoryProvider(sub.id)),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return const SPEmptyState(
            icon: Icons.payment,
            title: 'Belum Ada Pembayaran',
            message: 'Riwayat pembayaran akan muncul di sini',
          );
        }

        double totalPaid = 0;
        for (final p in payments) {
          if (p['status'] == 'paid') {
            totalPaid += (p['amount'] as num?)?.toDouble() ?? 0;
          }
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space16),
              color: AppTheme.primaryGreen.withOpacity(0.05),
              child: Column(
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(totalPaid),
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
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                  final method = p['method'] ?? 'cash';
                  final status = p['status'] ?? 'pending';
                  final date = p['payment_date'] ?? '';

                  return SPCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Center(
                            child: Text(
                              _methodEmoji(method),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatShortDate(date),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _methodLabel(method),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatRupiah(amount),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (status == 'paid'
                                        ? AppTheme.primaryGreen
                                        : AppTheme.accent)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status == 'paid' ? 'Lunas' : 'Proses',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: status == 'paid'
                                      ? AppTheme.primaryGreen
                                      : AppTheme.accent,
                                ),
                              ),
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

  String _methodEmoji(String method) {
    switch (method) {
      case 'cash':
        return '💵';
      case 'qris':
        return '📱';
      case 'transfer':
        return '🏦';
      default:
        return '💳';
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      default:
        return method;
    }
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, Subscription sub) {
    if (sub.status == 'cancelled') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (sub.status == 'active')
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showPauseDialog(context, ref, sub),
                icon: const Icon(Icons.pause, size: 18),
                label: const Text('Jeda Langganan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else if (sub.status == 'paused')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleResume(context, ref, sub),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Lanjutkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (sub.status != 'cancelled') ...[
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, ref, sub),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Batalkan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _countdownLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff < 0) return 'Terlewat';
      if (diff == 0) return 'Hari ini';
      if (diff == 1) return 'Besok — 1 hari lagi';
      return '$diff hari lagi';
    } catch (_) {
      return '';
    }
  }

  Future<void> _skipDelivery(
      BuildContext context, WidgetRef ref, Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Lewati Kiriman Ini'),
        content: const Text(
          'Kiriman berikutnya akan dilewati. Anda tidak akan dikenakan biaya untuk kiriman ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Ya, Lewati'),
          ),
        ],
      ),
    );

    if (confirmed == true && sub.nextDelivery != null) {
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.skipDelivery(sub.id, sub.nextDelivery!);
        ref.invalidate(subscriptionDetailProvider(sub.id));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kiriman dilewati'),
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
        ref.invalidate(subscriptionDetailProvider(sub.id));
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
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Batalkan Langganan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yakin ingin membatalkan langganan "${sub.packageName}"? '
              'Tindakan ini tidak dapat dibatalkan.',
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan pembatalan',
                hintText: 'Beritahu alasan Anda',
              ),
              maxLines: 2,
            ),
          ],
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
        await repo.pelangganCancelSubscription(sub.id,
            reason: reasonController.text.isNotEmpty
                ? reasonController.text
                : null);
        ref.invalidate(subscriptionDetailProvider(sub.id));
        ref.invalidate(myActiveSubscriptionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Langganan dibatalkan'),
              backgroundColor: AppTheme.error,
            ),
          );
          context.pop();
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
      ref.invalidate(subscriptionDetailProvider(sub.id));
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

  void _contactPedagang(Subscription sub) {
    if (sub.pelangganPhone != null && sub.pelangganPhone!.isNotEmpty) {
      // In real app, launch WhatsApp or phone dialer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka WhatsApp: ${sub.pelangganPhone}'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor pedagang tidak tersedia'),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }
}
