import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/common/widgets/rating_widget.dart';
import 'package:sayurpintar/features/common/widgets/status_timeline.dart';
import 'package:sayurpintar/features/pelanggan/providers/pelanggan_provider.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final orderAsync =
        ref.watch(pelangganOrderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(
                pelangganOrderDetailProvider(widget.orderId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) => _OrderContent(
          order: order,
          onRefresh: () => ref.invalidate(
              pelangganOrderDetailProvider(widget.orderId)),
        ),
        loading: () => const SPLoading(message: 'Memuat pesanan...'),
        error: (e, _) => SPErrorWidget(
          message: 'Gagal memuat detail pesanan.',
          onRetry: () => ref.invalidate(
              pelangganOrderDetailProvider(widget.orderId)),
        ),
      ),
    );
  }
}

class _OrderContent extends ConsumerWidget {
  final Order order;
  final VoidCallback onRefresh;

  const _OrderContent({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = _statusToStep(order.status);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space16),
        children: [
          // ── Status Timeline ────────────────────────────────────
          SPCard(
            color: AppTheme.primaryGreen.withOpacity(0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    _StatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: AppTheme.space16),
                StatusTimeline(
                  steps: const [
                    StatusStep(
                      label: 'Dipesan',
                      icon: Icons.shopping_cart,
                    ),
                    StatusStep(
                      label: 'Diproses',
                      icon: Icons.kitchen,
                    ),
                    StatusStep(
                      label: 'Diantar',
                      icon: Icons.local_shipping,
                    ),
                    StatusStep(
                      label: 'Tiba',
                      icon: Icons.check_circle,
                    ),
                  ],
                  currentStep: currentStep,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // ── Pedagang Info ──────────────────────────────────────
          SPCard(
            child: Row(
              children: [
                SPAvatar(
                  name: 'Pedagang',
                  radius: 24,
                  backgroundColor: AppTheme.primaryGreen,
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedagang #${order.pedagangId.substring(0, 6)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'ID: ${order.id.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _callPedagang(context),
                  icon: const Icon(Icons.phone, color: AppTheme.primaryGreen),
                  tooltip: 'Telepon Pedagang',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // ── Order Info ─────────────────────────────────────────
          SPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Informasi Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      _formatDate(order.deliveryDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                _InfoRow(
                  label: 'Metode Pembayaran',
                  value: order.paymentMethodText,
                ),
                _InfoRow(
                  label: 'Status Pembayaran',
                  value: order.paymentStatusText,
                  valueColor: order.paymentStatus == 'paid'
                      ? AppTheme.primaryGreen
                      : AppTheme.error,
                ),
                if (order.deliveryNotes != null &&
                    order.deliveryNotes!.isNotEmpty)
                  _InfoRow(
                    label: 'Catatan',
                    value: order.deliveryNotes!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // ── Items List ─────────────────────────────────────────
          SPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item Pesanan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                ...order.items.map((item) => _OrderItemRow(item: item)),
                const Divider(height: AppTheme.space24),
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
                      _formatPrice(order.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.primaryDark,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // ── Rating Section (if delivered and not rated) ─────────
          if (order.status == 'delivered' && order.rating == null) ...[
            SPCard(
              color: AppTheme.accent.withOpacity(0.06),
              child: Column(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 40,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  const Text(
                    'Bagaimana pesanan Anda?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  const Text(
                    'Beri rating untuk membantu pedagang meningkatkan layanan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  SPButton(
                    label: 'Beri Rating',
                    icon: Icons.star_outline,
                    onPressed: () => _showRatingDialog(context, ref),
                    isFullWidth: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),
          ],

          // ── Existing Rating Display ────────────────────────────
          if (order.rating != null) ...[
            SPCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating Anda',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  RatingWidget(rating: order.rating!, size: 24),
                  if (order.ratingComment != null &&
                      order.ratingComment!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      order.ratingComment!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),
          ],

          // ── Action Buttons ─────────────────────────────────────
          if (order.status == 'delivered' || order.status == 'cancelled')
            SPButton(
              label: 'Pesan Lagi',
              icon: Icons.replay,
              onPressed: () => _reorder(context, ref),
            ),

          if (order.status == 'pending') ...[
            SPButton(
              label: 'Batalkan Pesanan',
              icon: Icons.cancel_outlined,
              type: SPButtonType.secondary,
              onPressed: () => _confirmCancel(context, ref),
            ),
          ],

          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }

  int _statusToStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'preparing':
      case 'processing':
        return 1;
      case 'delivering':
      case 'in_transit':
        return 2;
      case 'delivered':
        return 3;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      final months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  void _callPedagang(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menghubungi pedagang...')),
    );
  }

  void _showRatingDialog(BuildContext context, WidgetRef ref) {
    InteractiveRatingDialog.show(
      context,
      title: 'Beri Rating Pesanan',
      subtitle: 'Bagaimana pengalaman Anda?',
      onSubmit: (rating, comment) async {
        try {
          final repo = ref.read(pelangganRepositoryProvider);
          await repo.rateOrder(order.id, rating, comment);
          ref.invalidate(pelangganOrderDetailProvider(order.id));
          ref.invalidate(pelangganOrderHistoryProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rating berhasil dikirim')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal mengirim rating')),
            );
          }
        }
      },
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(pelangganRepositoryProvider);
      await repo.reorder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan berhasil dibuat ulang')),
        );
        context.push('/browse-merchants');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat pesanan ulang')),
        );
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pesanan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pesanan akan dibatalkan. Tindakan ini tidak dapat diurungkan.'),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Alasan pembatalan (opsional)',
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Batalkan Pesanan'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = ref.read(pelangganRepositoryProvider);
        await repo.cancelOrder(order.id, reasonCtrl.text);
        ref.invalidate(pelangganOrderDetailProvider(order.id));
        ref.invalidate(pelangganOrderHistoryProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan berhasil dibatalkan')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membatalkan pesanan')),
          );
        }
      }
    }
  }
}

// ── Status Chip ──────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            _label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (status) {
      case 'delivered':
        return AppTheme.primaryGreen;
      case 'delivering':
      case 'in_transit':
        return Colors.blue;
      case 'preparing':
      case 'processing':
        return Colors.indigo;
      case 'cancelled':
        return AppTheme.error;
      default:
        return Colors.orange;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'delivering':
      case 'in_transit':
        return Icons.local_shipping;
      case 'preparing':
      case 'processing':
        return Icons.kitchen;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'preparing':
      case 'processing':
        return 'Diproses';
      case 'delivering':
      case 'in_transit':
        return 'Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Batal';
      default:
        return status;
    }
  }
}

// ── Info Row ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Item Row ───────────────────────────────────────────────────────

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.eco,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${item.qty} ${item.unit} × ${_formatPrice(item.price)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatPrice(item.subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
