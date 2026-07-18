import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

// ── Pelanggan Order Screen ───────────────────────────────────────────────

class PelangganOrderScreen extends ConsumerStatefulWidget {
  const PelangganOrderScreen({super.key});

  @override
  ConsumerState<PelangganOrderScreen> createState() =>
      _PelangganOrderScreenState();
}

class _PelangganOrderScreenState
    extends ConsumerState<PelangganOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_FilterTab> _tabs = const [
    _FilterTab(label: 'Semua', value: 'semua'),
    _FilterTab(label: 'Aktif', value: 'active'),
    _FilterTab(label: 'Terkirim', value: 'delivered'),
    _FilterTab(label: 'Dibatalkan', value: 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(orderHistoryFilterProvider.notifier).state =
            _tabs[_tabController.index].value;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(orderHistoryFilterProvider);
    final ordersAsync = ref.watch(orderHistoryProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return SPEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada pesanan',
              message:
                  'Mulai berlangganan untuk melihat pesanan Anda di sini.',
              actionLabel: 'Cari Pedagang',
              onAction: () => context.push('/browse-merchants'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderHistoryProvider(filter));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.space8,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _OrderCard(order: orders[index]);
              },
            ),
          );
        },
        loading: () => const SPLoading(),
        error: (e, _) => SPEmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat pesanan',
          message: 'Terjadi kesalahan. Coba lagi nanti.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(orderHistoryProvider(filter)),
        ),
      ),
    );
  }
}

// ── Filter Tab Model ─────────────────────────────────────────────────────

class _FilterTab {
  final String label;
  final String value;

  const _FilterTab({required this.label, required this.value});
}

// ── Order Card ───────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final dynamic order; // Order model

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(order.deliveryDate ?? order.createdAt);
    final pedagangName = order.pedagangName ?? 'Pedagang';
    final items = order.itemsSummary ?? 'Pesanan';
    final total = _formatPrice(order.totalPrice ?? order.total ?? 0);
    final status = order.status ?? 'pending';
    final isRated = order.isRated ?? false;
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final statusIcon = _statusIcon(status);

    return SPCard(
      onTap: () {
        // Navigate to order detail (reuse order history screen)
        context.push('/order-history');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          // Pedagang info
          Row(
            children: [
              SPAvatar(
                name: pedagangName,
                radius: 18,
                backgroundColor: AppTheme.primaryLight,
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  pedagangName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),

          // Items summary
          Text(
            items,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space12),

          // Divider
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: AppTheme.space12),

          // Footer: total + rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    total,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
              if (isRated)
                Row(
                  children: [
                    const Icon(Icons.star,
                        size: 16, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${order.rating ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              else if (status == 'delivered')
                ElevatedButton.icon(
                  onPressed: () => _showRatingDialog(context),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Rating'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),

          // Status timeline for active orders
          if (status == 'pending' ||
              status == 'processing' ||
              status == 'in_transit') ...[
            const SizedBox(height: AppTheme.space12),
            _OrderTimeline(status: status),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date.toString());
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatPrice(dynamic price) {
    final amount = price is int ? price : (price as num?)?.toInt() ?? 0;
    final str = amount.toString();
    final buffer = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.primaryGreen;
      case 'in_transit':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'cancelled':
        return AppTheme.error;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Terkirim';
      case 'in_transit':
        return 'Diantar';
      case 'processing':
        return 'Diproses';
      case 'cancelled':
        return 'Dibatalkan';
      case 'pending':
        return 'Menunggu';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'in_transit':
        return Icons.local_shipping;
      case 'processing':
        return Icons.hourglass_top;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  void _showRatingDialog(BuildContext context) {
    int rating = 0;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Beri Rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bagaimana pesanan Anda?'),
              const SizedBox(height: AppTheme.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star
                          : Icons.star_border,
                      color: AppTheme.accent,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tulis komentar (opsional)',
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () => Navigator.pop(ctx)
                  : null,
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Timeline ───────────────────────────────────────────────────────

class _OrderTimeline extends StatelessWidget {
  final String status;

  const _OrderTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(
        label: 'Dipesan',
        icon: Icons.shopping_cart,
        isCompleted: true,
      ),
      _TimelineStep(
        label: 'Diproses',
        icon: Icons.kitchen,
        isCompleted: status == 'processing' ||
            status == 'in_transit' ||
            status == 'delivered',
        isActive: status == 'processing',
      ),
      _TimelineStep(
        label: 'Diantar',
        icon: Icons.local_shipping,
        isCompleted:
            status == 'in_transit' || status == 'delivered',
        isActive: status == 'in_transit',
      ),
      _TimelineStep(
        label: 'Tiba',
        icon: Icons.check_circle,
        isCompleted: status == 'delivered',
      ),
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final step = entry.value;
        final isLast = entry.key == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isCompleted
                          ? AppTheme.primaryGreen
                          : step.isActive
                              ? AppTheme.primaryLight
                              : AppTheme.divider.withOpacity(0.4),
                    ),
                    child: Icon(
                      step.icon,
                      size: 14,
                      color: step.isCompleted || step.isActive
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: step.isCompleted || step.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: step.isCompleted || step.isActive
                          ? AppTheme.primaryDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: step.isCompleted
                        ? AppTheme.primaryGreen
                        : AppTheme.divider.withOpacity(0.4),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TimelineStep {
  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;

  const _TimelineStep({
    required this.label,
    required this.icon,
    this.isCompleted = false,
    this.isActive = false,
  });
}
