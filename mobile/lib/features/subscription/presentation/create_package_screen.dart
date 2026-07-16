import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_bottom_sheet.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';

class CreatePackageScreen extends ConsumerStatefulWidget {
  final String? packageId;

  const CreatePackageScreen({super.key, this.packageId});

  @override
  ConsumerState<CreatePackageScreen> createState() =>
      _CreatePackageScreenState();
}

class _CreatePackageScreenState extends ConsumerState<CreatePackageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxSubscribersController = TextEditingController();

  String _frequency = 'weekly';
  final List<int> _selectedDays = [];
  List<PackageItem> _items = [];
  bool _isEditing = false;
  bool _useManualPrice = false;
  bool _isSaving = false;

  static const List<String> _dayNames = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<Map<String, dynamic>> _popularItems = [
    {'name': 'Bayam', 'unit': 'ikat', 'price': 3000.0, 'qty': 1.0},
    {'name': 'Kangkung', 'unit': 'ikat', 'price': 2500.0, 'qty': 1.0},
    {'name': 'Wortel', 'unit': 'kg', 'price': 12000.0, 'qty': 0.5},
    {'name': 'Tomat', 'unit': 'kg', 'price': 10000.0, 'qty': 0.5},
    {'name': 'Bawang Merah', 'unit': 'kg', 'price': 35000.0, 'qty': 0.25},
    {'name': 'Bawang Putih', 'unit': 'kg', 'price': 30000.0, 'qty': 0.25},
    {'name': 'Cabai Merah', 'unit': 'kg', 'price': 50000.0, 'qty': 0.25},
    {'name': 'Kentang', 'unit': 'kg', 'price': 15000.0, 'qty': 0.5},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.packageId != null;
    if (_isEditing) {
      _loadPackage();
    }
    _maxSubscribersController.text = '0';
  }

  Future<void> _loadPackage() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      final pkg = await repo.getPackageDetail(widget.packageId!);
      _nameController.text = pkg.name;
      _descController.text = pkg.description ?? '';
      _priceController.text = pkg.price.toInt().toString();
      _maxSubscribersController.text = pkg.maxSubscribers.toString();
      _frequency = pkg.frequency;
      _selectedDays.clear();
      _selectedDays.addAll(pkg.deliveryDays);
      setState(() => _items = List.from(pkg.items));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat paket: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _maxSubscribersController.dispose();
    super.dispose();
  }

  double get _calculatedPrice =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get _displayPrice =>
      _useManualPrice
          ? (double.tryParse(_priceController.text) ?? 0)
          : _calculatedPrice;

  List<int> get _availableDays {
    switch (_frequency) {
      case 'daily':
        return [1, 2, 3, 4, 5, 6, 7];
      case 'twice_weekly':
        return [1, 2, 3, 4, 5, 6, 7];
      case 'weekly':
      default:
        return [1, 2, 3, 4, 5, 6, 7];
    }
  }

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

  void _addItem(PackageItem item) {
    setState(() {
      final existingIndex =
          _items.indexWhere((i) => i.productId == item.productId);
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = PackageItem(
          productId: existing.productId,
          name: existing.name,
          qty: existing.qty + item.qty,
          unit: existing.unit,
          pricePerUnit: existing.pricePerUnit,
        );
      } else {
        _items.add(item);
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateItemQty(int index, double newQty) {
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }
    final item = _items[index];
    setState(() {
      _items[index] = PackageItem(
        productId: item.productId,
        name: item.name,
        qty: newQty,
        unit: item.unit,
        pricePerUnit: item.pricePerUnit,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 item')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 hari pengiriman')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(subscriptionRepositoryProvider);

    try {
      if (_isEditing) {
        await repo.updatePackage(
          widget.packageId!,
          UpdatePackageRequest(
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            items: _items,
            price: _displayPrice,
          ),
        );
      } else {
        await repo.createPackage(CreatePackageRequest(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          items: _items,
          price: _displayPrice,
          frequency: _frequency,
          deliveryDays: _selectedDays,
          maxSubscribers:
              int.tryParse(_maxSubscribersController.text) ?? 0,
        ));
      }

      ref.invalidate(myPackagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Paket berhasil diperbarui'
                  : 'Paket berhasil dibuat',
            ),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddItemSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    String unit = 'kg';

    SPBottomSheet.show(
      context,
      title: 'Tambah Item',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SPInput(
                label: 'Nama Produk',
                hint: 'Contoh: Bayam',
                controller: nameCtrl,
              ),
              const SizedBox(height: AppTheme.space16),
              Row(
                children: [
                  Expanded(
                    child: SPInput(
                      label: 'Jumlah',
                      hint: '1',
                      controller: qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Satuan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        DropdownButtonFormField<String>(
                          value: unit,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'kg', child: Text('kg')),
                            DropdownMenuItem(
                                value: 'ikat', child: Text('ikat')),
                            DropdownMenuItem(
                                value: 'pcs', child: Text('pcs')),
                            DropdownMenuItem(
                                value: 'liter', child: Text('liter')),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => unit = v ?? 'kg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              SPInput(
                label: 'Harga per Satuan (Rp)',
                hint: '10000',
                controller: priceCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.space24),
              SPButton(
                label: 'Tambahkan',
                icon: Icons.add,
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final qty = double.tryParse(qtyCtrl.text) ?? 0;
                  final price = double.tryParse(priceCtrl.text) ?? 0;
                  if (name.isEmpty || qty <= 0 || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Isi semua field dengan benar')),
                    );
                    return;
                  }
                  _addItem(PackageItem(
                    productId: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
                    name: name,
                    qty: qty,
                    unit: unit,
                    pricePerUnit: price,
                  ));
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickAddSheet() {
    SPBottomSheet.show(
      context,
      title: 'Item Populer',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _popularItems.map((item) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              child: const Icon(Icons.eco, color: AppTheme.primaryGreen),
            ),
            title: Text(item['name'] as String),
            subtitle: Text(
              '${_formatCurrency(item['price'] as double)}/${item['unit']}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: AppTheme.primaryGreen),
              onPressed: () {
                _addItem(PackageItem(
                  productId: (item['name'] as String)
                      .toLowerCase()
                      .replaceAll(' ', '_'),
                  name: item['name'] as String,
                  qty: item['qty'] as double,
                  unit: item['unit'] as String,
                  pricePerUnit: item['price'] as double,
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item["name"]} ditambahkan'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Paket' : 'Buat Paket Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space16),
          children: [
            // ── Info Section ────────────────────────────────────────────
            const _SectionHeader(title: 'Informasi Paket'),
            SPCard(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              child: Column(
                children: [
                  SPInput(
                    label: 'Nama Paket',
                    hint: 'Contoh: Paket Sayur Segar Harian',
                    controller: _nameController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: AppTheme.space16),
                  SPInput(
                    label: 'Deskripsi (opsional)',
                    hint: 'Deskripsi singkat tentang paket ini...',
                    controller: _descController,
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            // ── Items Section ───────────────────────────────────────────
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                const _SectionHeader(title: 'Isi Paket'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showQuickAddSheet,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Populer'),
                ),
              ],
            ),
            if (_items.isEmpty)
              SPCard(
                margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 48,
                      color: AppTheme.textSecondary.withOpacity(0.4),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    const Text(
                      'Belum ada item',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    const Text(
                      'Tekan tombol + untuk menambah item',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey('${item.productId}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppTheme.space20),
                    margin: const EdgeInsets.symmetric(
                        vertical: AppTheme.space4),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Item'),
                        content: Text(
                            'Hapus ${item.name} dari paket?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => _removeItem(index),
                  child: SPCard(
                    margin: const EdgeInsets.symmetric(
                        vertical: AppTheme.space4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatCurrency(item.pricePerUnit)} / ${item.unit}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () =>
                                  _updateItemQty(index, item.qty - 0.5),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8),
                              child: Text(
                                '${item.qty} ${item.unit}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () =>
                                  _updateItemQty(index, item.qty + 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Text(
                          _formatCurrency(item.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAddItemSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Item'),
                  ),
                ),
              ],
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: AppTheme.space8),
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Harga Item',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(_calculatedPrice)} / pengiriman',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Schedule Section ────────────────────────────────────────
            const SizedBox(height: AppTheme.space16),
            const _SectionHeader(title: 'Jadwal Pengiriman'),
            SPCard(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frekuensi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'daily',
                        label: Text('Harian'),
                      ),
                      ButtonSegment(
                        value: 'twice_weekly',
                        label: Text('2x/Minggu'),
                      ),
                      ButtonSegment(
                        value: 'weekly',
                        label: Text('Mingguan'),
                      ),
                    ],
                    selected: {_frequency},
                    onSelectionChanged: (values) {
                      setState(() {
                        _frequency = values.first;
                        _selectedDays.clear();
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppTheme.primaryGreen;
                          }
                          return null;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return AppTheme.textPrimary;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  const Text(
                    'Hari Pengiriman',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Wrap(
                    spacing: AppTheme.space8,
                    runSpacing: AppTheme.space8,
                    children: List.generate(7, (i) {
                      final dayNum = i + 1;
                      final isAvailable =
                          _availableDays.contains(dayNum);
                      final isSelected = _selectedDays.contains(dayNum);
                      return FilterChip(
                        label: Text(_dayNames[i]),
                        selected: isSelected,
                        onSelected: isAvailable
                            ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(dayNum);
                                  } else {
                                    _selectedDays.remove(dayNum);
                                  }
                                });
                              }
                            : null,
                        selectedColor:
                            AppTheme.primaryGreen.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : isAvailable
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      );
                    }),
                  ),
                  if (_selectedDays.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Pengiriman: ${_selectedDays.map((d) => _dayNames[d - 1]).join(', ')}',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Price Section ───────────────────────────────────────────
            const SizedBox(height: AppTheme.space8),
            const _SectionHeader(title: 'Harga'),
            SPCard(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Harga Manual',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _useManualPrice
                          ? 'Masukkan harga secara manual'
                          : 'Otomatis dari total item',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    value: _useManualPrice,
                    onChanged: (v) =>
                        setState(() => _useManualPrice = v),
                    activeColor: AppTheme.primaryGreen,
                  ),
                  if (_useManualPrice) ...[
                    SPInput(
                      label: 'Harga per Pengiriman (Rp)',
                      hint: '45000',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: AppTheme.space8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.space12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_formatCurrency(_displayPrice)} / pengiriman',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        if (_frequency == 'weekly')
                          Text(
                            '${_formatCurrency(_displayPrice * (_selectedDays.isNotEmpty ? _selectedDays.length : 1))} / minggu',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Max Subscribers ─────────────────────────────────────────
            const SizedBox(height: AppTheme.space8),
            const _SectionHeader(title: 'Kuota'),
            SPCard(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              child: SPInput(
                label: 'Maksimal Pelanggan',
                hint: '0 = tidak terbatas',
                controller: _maxSubscribersController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.people_outline,
              ),
            ),

            // ── Save Button ────────────────────────────────────────────
            const SizedBox(height: AppTheme.space24),
            SPButton(
              label: _isEditing ? 'Perbarui Paket' : 'Simpan Paket',
              icon: Icons.save,
              isLoading: _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: AppTheme.space32),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.space4,
        top: AppTheme.space8,
        bottom: AppTheme.space4,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, size: 16, color: AppTheme.textPrimary),
      ),
    );
  }
}
