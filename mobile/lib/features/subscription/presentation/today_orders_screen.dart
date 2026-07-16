import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_bottom_sheet.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

enum OrderFilter { all, pending, delivered }

class TodayOrdersScreen extends ConsumerStatefulWidget {
  const TodayOrdersScreen({super.key});

  @override
  ConsumerState<TodayOrdersScreen> createState() => _TodayOrdersScreenState();
}

class _TodayOrdersScreenState extends ConsumerState<TodayOrdersScreen> {
  OrderFilter _filter = OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(todayOrdersProvider);
    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Pesanan $dateStr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () => ref.invalidate(todayOrdersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const SPLoading(message: 'Memuat pesanan...'),
        error: (error, _) => SPErrorWidget(
          message: 'Gagal memuat pesanan: $error',
          onRetry: () => ref.invalidate(todayOrdersProvider),
        ),
        data: (orders) {
          final filteredOrders = _filterOrders(orders);

          return Column(
            children: [
              // ── Header Stats ──────────────────────────────────────
              _OrderStatsHeader(orders: orders),

              // ── Filter Chips ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space8,
                ),
                child: Row(
                  children: OrderFilter.values.map((f) {
                    final isSelected = _filter == f;
                    final count = f == OrderFilter.all
                        ? orders.length
                        : f == OrderFilter.pending
                            ? orders
                                .where((o) =>
                                    o.status == 'pending' ||
                                    o.status == 'preparing')
                                .length
                            : orders
                                .where((o) => o.status == 'delivered')
                                .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.space8),
                      child: FilterChip(
                        label: Text('${_filterLabel(f)} ($count)'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Order List ────────────────────────────────────────
              Expanded(
                child: filteredOrders.isEmpty
                    ? SPEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Tidak Ada Pesanan',
                        message: _filter == OrderFilter.all
                            ? 'Belum ada pesanan untuk hari ini'
                            : 'Tidak ada pesanan dengan filter ini',
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(todayOrdersProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.space16,
                            0,
                            AppTheme.space16,
                            AppTheme.space80,
                          ),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _OrderCard(
                              order: filteredOrders[index],
                              onTap: () => _showOrderDetail(
                                context,
                                ref,
                                filteredOrders[index],
                              ),
                              onDeliver: () => _markDelivered(
                                context,
                                ref,
                                filteredOrders[index],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Order> _filterOrders(List<Order> orders) {
    switch (_filter) {
      case OrderFilter.pending:
        return orders
            .where((o) => o.status == 'pending' || o.status == 'preparing')
            .toList();
      case OrderFilter.delivered:
        return orders.where((o) => o.status == 'delivered').toList();
      case OrderFilter.all:
        return orders;
    }
  }

  String _filterLabel(OrderFilter f) {
    switch (f) {
      case OrderFilter.all:
        return 'Semua';
      case OrderFilter.pending:
        return 'Pending';
      case OrderFilter.delivered:
        return 'Selesai';
    }
  }

  void _showOrderDetail(BuildContext context, WidgetRef ref, Order order) {
    SPBottomSheet.show(
      context,
      title: 'Detail Pesanan',
      child: _OrderDetailContent(
        order: order,
        onDeliver: () {
          Navigator.pop(context);
          _markDelivered(context, ref, order);
        },
        onCancel: () {
          Navigator.pop(context);
          _showCancelDialog(context, ref, order);
        },
      ),
    );
  }

  Future<void> _markDelivered(
      BuildContext context, WidgetRef ref, Order order) async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.markOrderDelivered(order.id);
      ref.invalidate(todayOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${order.pelangganName ?? ""} selesai'),
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

  void _showCancelDialog(BuildContext context, WidgetRef ref, Order order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Batalkan pesanan ${order.pelangganName ?? ""}?'),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan pembatalan',
                hintText: 'Contoh: Stok habis',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(subscriptionRepositoryProvider);
                await repo.cancelOrder(
                  order.id,
                  reasonCtrl.text.trim(),
                );
                ref.invalidate(todayOrdersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pesanan dibatalkan'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }
}

// ── Stats Header ─────────────────────────────────────────────────────────────

class _OrderStatsHeader extends StatelessWidget {
  final List<Order> orders;

  const _OrderStatsHeader({required this.orders});

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
    final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final pendingCount = orders
        .where((o) => o.status == 'pending' || o.status == 'preparing')
        .length;
    final deliveredCount = orders.where((o) => o.status == 'delivered').length;

    return Container(
      margin: const EdgeInsets.all(AppTheme.space16),
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
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Pesanan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${orders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total Pendapatan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatCurrency(totalRevenue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              _StatBadge(
                label: 'Menunggu',
                count: pendingCount,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: AppTheme.space8),
              _StatBadge(
                label: 'Selesai',
                count: deliveredCount,
                color: Colors.lightGreenAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final VoidCallback onDeliver;

  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onDeliver,
  });

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
    final isActionable =
        order.status == 'pending' || order.status == 'preparing';

    return SPCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
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
                      order.pelangganName ?? 'Pelanggan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (order.pelangganAddress != null)
                      Text(
                        order.pelangganAddress!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            order.items.map((i) => '${i.name} ${i.qty}${i.unit}').join(', '),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Text(
                _formatCurrency(order.totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              _PaymentBadge(status: order.paymentStatus),
              const Spacer(),
              if (isActionable)
                SPButton(
                  label: order.status == 'pending' ? 'Antar' : 'Sudah Sampai',
                  icon: order.status == 'pending'
                      ? Icons.local_shipping
                      : Icons.check_circle,
                  type: SPButtonType.primary,
                  isFullWidth: false,
                  onPressed: onDeliver,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Order Detail Content ─────────────────────────────────────────────────────

class _OrderDetailContent extends StatelessWidget {
  final Order order;
  final VoidCallback onDeliver;
  final VoidCallback onCancel;

  const _OrderDetailContent({
    required this.order,
    required this.onDeliver,
    required this.onCancel,
  });

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
    final isActionable =
        order.status == 'pending' || order.status == 'preparing';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer info
        Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              child: const Icon(Icons.person, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.pelangganName ?? 'Pelanggan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (order.pelangganPhone != null)
                    Text(
                      order.pelangganPhone!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            _StatusBadge(status: order.status),
          ],
        ),
        if (order.pelangganAddress != null) ...[
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Text(
                  order.pelangganAddress!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],

        const Divider(height: AppTheme.space24),

        // Items
        const Text(
          'Item Pesanan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        ...order.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.name} (${item.qty} ${item.unit})',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  _formatCurrency(item.subtotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: AppTheme.space16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              _formatCurrency(order.totalPrice),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            const Text('Pembayaran: ', style: TextStyle(fontSize: 13)),
            Text(
              order.paymentMethod == 'cash' ? 'Tunai' : 'Transfer',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            _PaymentBadge(status: order.paymentStatus),
          ],
        ),

        if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note, size: 16, color: AppTheme.accent),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    order.deliveryNotes!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (order.rating != null) ...[
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < order.rating! ? Icons.star : Icons.star_border,
                  color: AppTheme.accent,
                  size: 20,
                );
              }),
              if (order.ratingComment != null) ...[
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    order.ratingComment!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],

        // Actions
        if (isActionable) ...[
          const SizedBox(height: AppTheme.space20),
          Row(
            children: [
              Expanded(
                child: SPButton(
                  label: 'Batalkan',
                  type: SPButtonType.secondary,
                  icon: Icons.cancel_outlined,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: SPButton(
                  label: order.status == 'pending'
                      ? 'Mulai Antar'
                      : 'Sudah Sampai',
                  icon: order.status == 'pending'
                      ? Icons.local_shipping
                      : Icons.check_circle,
                  onPressed: onDeliver,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppTheme.space16),
      ],
    );
  }
}

// ── Badge Widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Menunggu';
        icon = Icons.schedule;
        break;
      case 'preparing':
        color = Colors.blue;
        label = 'Disiapkan';
        icon = Icons.kitchen;
        break;
      case 'delivering':
        color = Colors.purple;
        label = 'Diantar';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        color = AppTheme.primaryGreen;
        label = 'Selesai';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = AppTheme.error;
        label = 'Batal';
        icon = Icons.cancel;
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String status;

  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'paid':
        color = AppTheme.primaryGreen;
        label = 'Lunas';
        break;
      case 'unpaid':
        color = AppTheme.error;
        label = 'Belum Bayar';
        break;
      case 'partial':
        color = Colors.orange;
        label = 'Sebagian';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
