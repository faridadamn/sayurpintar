import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/providers/tracking_provider.dart';
import 'package:sayurpintar/features/route/presentation/widgets/item_entry_widget.dart';

// ─── Screen ─────────────────────────────────────────

class VisitCompletionScreen extends ConsumerStatefulWidget {
  final VisitData visit;
  final WaypointData waypoint;

  const VisitCompletionScreen({
    super.key,
    required this.visit,
    required this.waypoint,
  });

  @override
  ConsumerState<VisitCompletionScreen> createState() =>
      _VisitCompletionScreenState();
}

class _VisitCompletionScreenState extends ConsumerState<VisitCompletionScreen> {
  final List<VisitItem> _items = [];
  String _paymentMethod = 'cash';
  bool _isPaid = true;
  double _partialAmount = 0;
  final _notesController = TextEditingController();
  final _manualAmountController = TextEditingController();
  bool _isSubmitting = false;

  // Common quick-add items for vegetable vendors
  static const List<Map<String, dynamic>> _quickItems = [
    {'name': 'Bayam', 'unit': 'ikat', 'price': 3000},
    {'name': 'Kangkung', 'unit': 'ikat', 'price': 2000},
    {'name': 'Sawi Hijau', 'unit': 'ikat', 'price': 3000},
    {'name': 'Kol / Kubis', 'unit': 'pcs', 'price': 5000},
    {'name': 'Wortel', 'unit': 'kg', 'price': 12000},
    {'name': 'Tomat', 'unit': 'kg', 'price': 10000},
    {'name': 'Bawang Merah', 'unit': 'ons', 'price': 8000},
    {'name': 'Bawang Putih', 'unit': 'ons', 'price': 7000},
    {'name': 'Cabai Merah', 'unit': 'ons', 'price': 15000},
    {'name': 'Kentang', 'unit': 'kg', 'price': 12000},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _manualAmountController.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  double get _amountDue => _isPaid ? 0 : _totalAmount - _partialAmount;

  String get _visitDuration {
    if (widget.visit.arrivedAt == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(widget.visit.arrivedAt!);
    if (diff.inHours > 0) {
      return '${diff.inHours} jam ${diff.inMinutes % 60} menit';
    }
    return '${diff.inMinutes} menit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selesaikan Kunjungan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showExitDialog(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: AppTheme.space20),

                  // ── Quick Add Section ─────────────────
                  _buildQuickAddSection(),
                  const SizedBox(height: AppTheme.space20),

                  // ── Item Entry Section ────────────────
                  _buildItemSection(),
                  const SizedBox(height: AppTheme.space20),

                  // ── Payment Section ───────────────────
                  _buildPaymentSection(),
                  const SizedBox(height: AppTheme.space20),

                  // ── Notes Section ─────────────────────
                  _buildNotesSection(),
                  const SizedBox(height: AppTheme.space32),
                ],
              ),
            ),
          ),

          // ── Bottom action bar ──────────────────────
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  widget.waypoint.name.isNotEmpty
                      ? widget.waypoint.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.waypoint.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.waypoint.address,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              _headerBadge(Icons.pin_drop,
                  'Kunjungan #${widget.waypoint.order}'),
              const SizedBox(width: AppTheme.space12),
              _headerBadge(Icons.timer, 'Durasi: $_visitDuration'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Add Section ────────────────────────────

  Widget _buildQuickAddSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tambah Cepat',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickItems.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTheme.space8),
            itemBuilder: (context, index) {
              final qi = _quickItems[index];
              return ActionChip(
                label: Text(
                  qi['name'] as String,
                  style: const TextStyle(fontSize: 13),
                ),
                avatar: const Icon(Icons.add, size: 16),
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.08),
                side: BorderSide(
                    color: AppTheme.primaryGreen.withOpacity(0.3)),
                onPressed: () => _addQuickItem(qi),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Item Entry Section ───────────────────────────

  Widget _buildItemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Barang Terjual',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${_items.length} item',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),

        // Item list
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.space24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                  color: AppTheme.divider.withOpacity(0.3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 40, color: AppTheme.textSecondary),
                SizedBox(height: AppTheme.space8),
                Text(
                  'Belum ada barang.\nGunakan "Tambah Cepat" atau tombol di bawah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_items.length, (index) {
            return ItemEntryWidget(
              key: ValueKey('item_$index'),
              item: _items[index],
              index: index,
              onChanged: (updated) {
                setState(() => _items[index] = updated);
              },
              onRemove: () {
                setState(() => _items.removeAt(index));
              },
            );
          }),

        const SizedBox(height: AppTheme.space12),

        // Add item button
        OutlinedButton.icon(
          onPressed: _addManualItem,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Tambah Barang'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: AppTheme.primaryGreen),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        ),

        // Running total
        if (_items.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space12),
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.06),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Penjualan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Rp ${_formatCurrency(_totalAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.primaryGreen,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Payment Section ──────────────────────────────

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.divider.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pembayaran',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),

          // Amount due
          if (_totalAmount > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tagihan',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Rp ${_formatCurrency(_totalAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],

          // Payment method selector
          const Text(
            'Metode Pembayaran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              _paymentMethodButton('cash', '💵', 'Tunai'),
              const SizedBox(width: AppTheme.space8),
              _paymentMethodButton('qris', '📱', 'QRIS'),
              const SizedBox(width: AppTheme.space8),
              _paymentMethodButton('transfer', '🏦', 'Transfer'),
            ],
          ),

          const SizedBox(height: AppTheme.space16),

          // Lunas toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Pembayaran',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPaid ? 'Lunas ✅' : 'Belum Lunas ⚠️',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _isPaid
                            ? AppTheme.primaryGreen
                            : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPaid,
                onChanged: (v) => setState(() {
                  _isPaid = v;
                  if (v) _partialAmount = 0;
                }),
                activeColor: AppTheme.primaryGreen,
              ),
            ],
          ),

          // Partial payment input (if not paid in full)
          if (!_isPaid) ...[
            const SizedBox(height: AppTheme.space12),
            const Text(
              'Jumlah Dibayar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            TextFormField(
              controller: _manualAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onChanged: (v) {
                final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
                setState(() {
                  _partialAmount = double.tryParse(cleaned) ?? 0;
                });
              },
            ),
            const SizedBox(height: AppTheme.space8),
            if (_amountDue > 0)
              Text(
                'Sisa tagihan: Rp ${_formatCurrency(_amountDue)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppTheme.space8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Save as piutang (debt)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📝 Piutang dicatat'),
                      backgroundColor: AppTheme.accent,
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Catat Piutang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentMethodButton(String value, String emoji, String label) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGreen.withOpacity(0.1)
                : AppTheme.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryGreen
                  : AppTheme.divider.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Notes Section ────────────────────────────────

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan Kunjungan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Catatan opsional tentang kunjungan ini...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ─── Bottom Bar ───────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.space16,
        right: AppTheme.space16,
        top: AppTheme.space12,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.space12,
      ),
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
          // Lewati button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : () => _showSkipDialog(),
              icon: const Icon(Icons.skip_next, size: 20),
              label: const Text('Lewati'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.divider),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),

          // Selesai button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _showConfirmDialog,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle, size: 20),
              label: Text(_isSubmitting ? 'Menyimpan...' : 'Selesai ✅'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────

  void _addQuickItem(Map<String, dynamic> qi) {
    HapticFeedback.lightImpact();
    setState(() {
      _items.add(VisitItem(
        productName: qi['name'] as String,
        quantity: 1,
        unit: qi['unit'] as String,
        pricePerUnit: (qi['price'] as int).toDouble(),
      ));
    });
  }

  void _addManualItem() {
    setState(() {
      _items.add(const VisitItem(
        productName: '',
        quantity: 1,
        unit: 'ikat',
        pricePerUnit: 0,
      ));
    });
  }

  void _showConfirmDialog() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Tambahkan minimal 1 barang terlebih dahulu'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final hasEmptyItems =
        _items.any((i) => i.productName.isEmpty || i.pricePerUnit <= 0);
    if (hasEmptyItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ Lengkapi nama barang dan harga pada semua item'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesaikan Kunjungan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pelanggan: ${widget.waypoint.name}'),
            const SizedBox(height: 8),
            Text('Total: Rp ${_formatCurrency(_totalAmount)}'),
            Text('Pembayaran: ${_paymentMethodLabel()}'),
            Text('Status: ${_isPaid ? "Lunas" : "Belum Lunas"}'),
            if (_notesController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catatan: ${_notesController.text}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeVisit();
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  void _showSkipDialog() {
    final reasons = [
      'Tidak jadi beli',
      'Stok masih ada',
      'Minta ditunda',
      'Alasan lain',
    ];
    String selected = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Lewati Kunjungan?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih alasan:'),
              const SizedBox(height: AppTheme.space12),
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(trackingProvider.notifier).skipVisit(selected);
                context.pop();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Lewati'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    if (_items.isEmpty && _notesController.text.isEmpty) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Kunjungan?'),
        content: const Text(
          'Data yang sudah diisi akan hilang. Yakin ingin keluar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tetap di Sini'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeVisit() async {
    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(trackingProvider.notifier);
      await notifier.markCompleted(
        _items.map((i) => i.toJson()).toList(),
        _totalAmount,
        _paymentMethod,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kunjungan berhasil diselesaikan!'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menyimpan: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _paymentMethodLabel() {
    switch (_paymentMethod) {
      case 'cash':
        return '💵 Tunai';
      case 'qris':
        return '📱 QRIS';
      case 'transfer':
        return '🏦 Transfer';
      default:
        return _paymentMethod;
    }
  }

  String _formatCurrency(double value) {
    final rounded = value.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
