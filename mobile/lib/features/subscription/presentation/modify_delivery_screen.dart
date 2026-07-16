import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';

class ModifyDeliveryScreen extends ConsumerStatefulWidget {
  final Subscription subscription;
  final String deliveryDate;
  const ModifyDeliveryScreen({
    super.key,
    required this.subscription,
    required this.deliveryDate,
  });

  @override
  ConsumerState<ModifyDeliveryScreen> createState() =>
      _ModifyDeliveryScreenState();
}

class _ModifyDeliveryScreenState extends ConsumerState<ModifyDeliveryScreen> {
  late List<PackageItem> _items;
  bool _skipDelivery = false;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Deep copy of items for editing
    _items = widget.subscription.packageName != null
        ? [] // Will be populated from detail
        : [];
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final detail = await repo.getMySubscriptionDetail(widget.subscription.id);
      if (mounted) {
        setState(() {
          _items = detail.package?.items
                  .map((e) => PackageItem(
                        productId: e.productId,
                        name: e.name,
                        qty: e.qty,
                        unit: e.unit,
                        pricePerUnit: e.pricePerUnit,
                      ))
                  .toList() ??
              [];
        });
      }
    } catch (_) {
      // If loading fails, use empty list
    }
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

  double get _totalPrice {
    if (_skipDelivery) return 0;
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  void _updateQty(int index, double delta) {
    setState(() {
      final item = _items[index];
      final newQty = (item.qty + delta).clamp(0.0, 999.0);
      _items[index] = PackageItem(
        productId: item.productId,
        name: item.name,
        qty: newQty,
        unit: item.unit,
        pricePerUnit: item.pricePerUnit,
      );
      _hasChanges = true;
      // Remove if qty is 0
      if (_items[index].qty <= 0) {
        _items.removeAt(index);
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _hasChanges = true;
    });
  }

  void _addItem() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String selectedUnit = 'kg';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Tambah Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Produk',
                hintText: 'Misalnya: Bayam',
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      hintText: '1',
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                    items: ['kg', 'ikat', 'pcs', 'liter', 'pack']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => selectedUnit = v ?? 'kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga per satuan',
                hintText: '5000',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  qtyController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                setState(() {
                  _items.add(PackageItem(
                    productId: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    qty: double.tryParse(qtyController.text) ?? 1,
                    unit: selectedUnit,
                    pricePerUnit: double.tryParse(priceController.text) ?? 0,
                  ));
                  _hasChanges = true;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_hasChanges && !_skipDelivery) {
      context.pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Simpan Perubahan'),
        content: Text(
          _skipDelivery
              ? 'Kiriman ini akan dilewati. Anda tidak akan dikenakan biaya.'
              : 'Simpan perubahan pesanan untuk ${_formatDate(widget.deliveryDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.modifyDelivery(
        subscriptionId: widget.subscription.id,
        deliveryDate: widget.deliveryDate,
        items: _items
            .map((e) => {
                  'product_id': e.productId,
                  'name': e.name,
                  'qty': e.qty,
                  'unit': e.unit,
                  'price_per_unit': e.pricePerUnit,
                })
            .toList(),
        skip: _skipDelivery,
      );

      ref.invalidate(subscriptionDetailProvider(widget.subscription.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan disimpan! ✅'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubah Pesanan'),
        subtitle: Text(
          _formatDate(widget.deliveryDate),
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ),
      body: Column(
        children: [
          // ── Deadline Notice ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space12,
            ),
            color: AppTheme.accent.withOpacity(0.15),
            child: const Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppTheme.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Perubahan harus dilakukan sebelum jam 8 malam',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Skip Toggle ──
          SPCard(
            margin: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                const Icon(Icons.skip_next, color: AppTheme.accent),
                const SizedBox(width: AppTheme.space12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lewati Kiriman Ini',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kiriman ini akan dilewati tanpa biaya',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _skipDelivery,
                  onChanged: (v) => setState(() {
                    _skipDelivery = v;
                    _hasChanges = true;
                  }),
                  activeColor: AppTheme.accent,
                ),
              ],
            ),
          ),

          // ── Items List ──
          if (!_skipDelivery) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📦 Item Pesanan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada item',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return SPCard(
                          margin:
                              const EdgeInsets.only(bottom: AppTheme.space8),
                          child: Row(
                            children: [
                              // Product emoji
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSmall),
                                ),
                                child: const Center(
                                  child: Text('🥬',
                                      style: TextStyle(fontSize: 20)),
                                ),
                              ),
                              const SizedBox(width: AppTheme.space12),

                              // Name + price
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${_formatRupiah(item.pricePerUnit)}/${item.unit}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quantity controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _updateQty(index, -0.5),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove,
                                          size: 16, color: AppTheme.error),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      '${item.qty} ${item.unit}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _updateQty(index, 0.5),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add,
                                          size: 16,
                                          color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: AppTheme.space8),

                              // Subtotal
                              Text(
                                _formatRupiah(item.subtotal),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),

                              // Delete
                              GestureDetector(
                                onTap: () => _removeItem(index),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close,
                                      size: 18, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_next, size: 64, color: AppTheme.accent),
                    SizedBox(height: AppTheme.space16),
                    Text(
                      'Kiriman ini akan dilewati',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Bar ──
          Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _skipDelivery ? 'Rp 0' : _formatRupiah(_totalPrice),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _skipDelivery
                            ? AppTheme.textSecondary
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                SPButton(
                  label: 'Simpan Perubahan',
                  onPressed: _isLoading ? null : _handleSave,
                  isLoading: _isLoading,
                  icon: Icons.save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
