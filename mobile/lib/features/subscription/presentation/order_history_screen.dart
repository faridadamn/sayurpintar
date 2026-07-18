import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String _selectedFilter = 'semua';

  static const _filters = [
    {'id': 'semua', 'label': 'Semua'},
    {'id': 'delivered', 'label': 'Selesai'},
    {'id': 'cancelled', 'label': 'Batal'},
    {'id': 'pending', 'label': 'Proses'},
  ];

  String _formatRupiah(double n) {
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderHistoryProvider(_selectedFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
      ),
      body: Column(
        children: [
          // ── Filter Chips ──
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            color: Colors.white,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTheme.space8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter['id'];
                return Center(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedFilter = filter['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.divider,
                        ),
                      ),
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Orders List ──
          Expanded(
            child: ordersAsync.when(
              loading: () => const SPLoading(message: 'Memuat riwayat...'),
              error: (e, _) => SPErrorWidget(
                message: 'Gagal memuat riwayat: $e',
                onRetry: () =>
                    ref.invalidate(orderHistoryProvider(_selectedFilter)),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return SPEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum Ada Pesanan',
                    message: _selectedFilter == 'semua'
                        ? 'Riwayat pesanan akan muncul di sini'
                        : 'Tidak ada pesanan dengan filter ini',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(orderHistoryProvider(_selectedFilter));
                  },
                  color: AppTheme.primaryGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(context, ref, order);
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

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    return SPCard(
      onTap: () => _showOrderDetail(context, ref, order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(order.deliveryDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedagang #${order.pedagangId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          // Items summary
          Text(
            order.items.map((e) => e.name).join(', '),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space8),

          // Total + rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatRupiah(order.totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
              if (order.rating != null)
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < order.rating! ? Icons.star : Icons.star_border,
                      size: 16,
                      color: AppTheme.accent,
                    );
                  }),
                )
              else if (order.status == 'delivered')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_border, size: 14, color: AppTheme.accent),
                      SizedBox(width: 4),
                      Text(
                        'Beri Rating',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Payment status
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              Icon(
                order.paymentStatus == 'paid'
                    ? Icons.check_circle
                    : Icons.pending,
                size: 14,
                color: order.paymentStatus == 'paid'
                    ? AppTheme.primaryGreen
                    : AppTheme.accent,
              ),
              const SizedBox(width: 6),
              Text(
                order.paymentStatusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: order.paymentStatus == 'paid'
                      ? AppTheme.primaryGreen
                      : AppTheme.accent,
                ),
              ),
              const Spacer(),
              Text(
                '${order.items.length} item',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
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
      case 'preparing':
        color = Colors.blue;
        label = 'Disiapkan';
        break;
      case 'delivering':
        color = Colors.indigo;
        label = 'Diantar';
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

  void _showOrderDetail(BuildContext context, WidgetRef ref, Order order) {
    int? selectedRating = order.rating;
    final commentController =
        TextEditingController(text: order.ratingComment ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          padding: EdgeInsets.only(
            left: AppTheme.space20,
            right: AppTheme.space20,
            top: AppTheme.space16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space16),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(order.deliveryDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pesanan #${order.id}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const Divider(height: AppTheme.space24),

              // Items
              const Text(
                '📦 Item Pesanan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Text('🥬 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            '${item.name} — ${item.qty} ${item.unit}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          _formatRupiah(item.subtotal),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: AppTheme.space24),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatRupiah(order.totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space24),

              // Rating section (only for delivered orders without rating)
              if (order.status == 'delivered' && order.rating == null) ...[
                const Text(
                  '⭐ Beri Rating',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < (selectedRating ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          size: 36,
                          color: AppTheme.accent,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTheme.space12),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar (opsional)',
                    labelText: 'Komentar',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppTheme.space16),
                SPButton(
                  label: 'Kirim Rating',
                  onPressed: selectedRating == null
                      ? null
                      : () async {
                          try {
                            final repo =
                                ref.read(subscriptionRepositoryProvider);
                            await repo.rateDelivery(
                              orderId: order.id,
                              rating: selectedRating!,
                              comment: commentController.text.isNotEmpty
                                  ? commentController.text
                                  : null,
                            );
                            ref.invalidate(
                                orderHistoryProvider(_selectedFilter));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Rating berhasil dikirim! ⭐'),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: Icons.send,
                ),
              ] else if (order.rating != null) ...[
                const Text(
                  'Rating Anda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < order.rating! ? Icons.star : Icons.star_border,
                      size: 32,
                      color: AppTheme.accent,
                    );
                  }),
                ),
                if (order.ratingComment != null &&
                    order.ratingComment!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    '"${order.ratingComment}"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
