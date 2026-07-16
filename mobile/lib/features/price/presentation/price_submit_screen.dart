import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PriceSubmitScreen extends ConsumerStatefulWidget {
  const PriceSubmitScreen({super.key});

  @override
  ConsumerState<PriceSubmitScreen> createState() => _PriceSubmitScreenState();
}

class _PriceSubmitScreenState extends ConsumerState<PriceSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _marketController = TextEditingController();
  final _searchController = TextEditingController();

  Product? _selectedProduct;
  String _selectedArea = 'jakarta_selatan';
  bool _isSubmitting = false;
  bool _showSuccess = false;
  int _todaySubmissions = 0;
  String? _spamMessage;

  // Recent submissions cache
  final List<PriceSubmission> _recentSubmissions = [];

  static const _areas = [
    {'id': 'jakarta_selatan', 'name': 'Jakarta Selatan'},
    {'id': 'jakarta_utara', 'name': 'Jakarta Utara'},
    {'id': 'jakarta_barat', 'name': 'Jakarta Barat'},
    {'id': 'jakarta_timur', 'name': 'Jakarta Timur'},
    {'id': 'jakarta_pusat', 'name': 'Jakarta Pusat'},
    {'id': 'bandung', 'name': 'Bandung'},
    {'id': 'surabaya', 'name': 'Surabaya'},
    {'id': 'medan', 'name': 'Medan'},
    {'id': 'semarang', 'name': 'Semarang'},
  ];

  @override
  void initState() {
    super.initState();
    final area = ref.read(selectedAreaProvider);
    _selectedArea = area;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _marketController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _checkSpamLimit(String productId) {
    // Check if user has submitted 3+ times today for this product
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final count = _recentSubmissions
        .where((s) => s.productId == productId && s.date.startsWith(today))
        .length;

    setState(() {
      _todaySubmissions = count;
      if (count >= 3) {
        _spamMessage =
            'Anda sudah mengirim ${count}x hari ini untuk produk ini';
      } else {
        _spamMessage = null;
      }
    });
  }

  Future<void> _submitPrice() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedProduct == null) return;
    if (_spamMessage != null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(priceRepositoryProvider);
      final request = SubmitPriceRequest(
        productId: _selectedProduct!.id,
        price: double.parse(_priceController.text.replaceAll('.', '')),
        market: _marketController.text.trim(),
        area: _selectedArea,
      );

      final submission = await repo.submitPrice(request);

      setState(() {
        _recentSubmissions.insert(0, submission);
        _isSubmitting = false;
        _showSuccess = true;
        _todaySubmissions++;
      });

      // Invalidate providers to refresh data
      ref.invalidate(currentPricesProvider(_selectedArea));
      ref.invalidate(topMoversProvider(_selectedArea));

      // Clear form
      _priceController.clear();
      _marketController.clear();

      // Hide success after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSuccess = false);
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim harga: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Harga'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Success banner ──────────────────────────────────────
              if (_showSuccess)
                Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.space16),
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '🎉',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '+1 poin!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Terima kasih sudah berkontribusi',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryGreen.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Spam warning ────────────────────────────────────────
              if (_spamMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.space16),
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Text(
                          _spamMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Product selector ────────────────────────────────────
              const Text(
                'Produk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              productsAsync.when(
                data: (products) {
                  final filtered = _searchController.text.isEmpty
                      ? products
                      : products
                          .where((p) => p.name
                              .toLowerCase()
                              .contains(_searchController.text.toLowerCase()))
                          .toList();

                  return Column(
                    children: [
                      // Search field
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari produk...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppTheme.space8),
                      // Product list
                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: const Center(
                            child: Text(
                              'Produk tidak ditemukan',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final isSelected =
                                  _selectedProduct?.id == product.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor:
                                    AppTheme.primaryGreen.withOpacity(0.08),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                title: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  product.category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primaryGreen,
                                        size: 20,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() => _selectedProduct = product);
                                  _checkSpamLimit(product.id);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SPLoading(message: 'Memuat produk...'),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text('Gagal memuat produk: $e'),
                ),
              ),
              const SizedBox(height: AppTheme.space20),

              // ── Current market price ────────────────────────────────
              if (_selectedProduct != null)
                _CurrentPricePreview(
                  productId: _selectedProduct!.id,
                  area: _selectedArea,
                ),

              // ── Price input ─────────────────────────────────────────
              const Text(
                'Harga',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CurrencyInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Harga wajib diisi';
                  final clean = v.replaceAll('.', '');
                  final num = int.tryParse(clean);
                  if (num == null || num <= 0) return 'Harga tidak valid';
                  if (num < 100) return 'Harga terlalu kecil';
                  return null;
                },
              ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: AppTheme.space4),
                Text(
                  'per ${_selectedProduct!.defaultUnit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.space20),

              // ── Market / Pasar ──────────────────────────────────────
              SPInput(
                label: 'Nama Pasar',
                hint: 'Pasar Minggu, Pasar Rebo, dll.',
                controller: _marketController,
                prefixIcon: Icons.store_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nama pasar wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space20),

              // ── Area selector ───────────────────────────────────────
              const Text(
                'Area',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedArea,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _areas.map((area) {
                      return DropdownMenuItem(
                        value: area['id'],
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(area['name']!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedArea = v);
                        ref.read(selectedAreaProvider.notifier).state = v;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  const Icon(
                    Icons.my_location,
                    size: 14,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      // Auto-detect would go here with geolocator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mendeteksi lokasi...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text(
                      'Deteksi otomatis dari GPS',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space32),

              // ── Submit button ───────────────────────────────────────
              SPButton(
                label: 'Kirim Harga',
                onPressed: _isSubmitting ? null : _submitPrice,
                isLoading: _isSubmitting,
                icon: Icons.send,
              ),
              const SizedBox(height: AppTheme.space8),
              const Center(
                child: Text(
                  'Data harga Anda membantu pedagang lain!',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space32),

              // ── Recent submissions ──────────────────────────────────
              if (_recentSubmissions.isNotEmpty) ...[
                const Text(
                  'Riwayat Kiriman Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                ..._recentSubmissions.map(
                  (sub) => SPCard(
                    margin: const EdgeInsets.only(bottom: AppTheme.space8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                sub.market,
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
                              'Rp ${_formatNumber(sub.price.toInt())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            Text(
                              sub.date.length >= 16
                                  ? sub.date.substring(11, 16)
                                  : sub.date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

// ── Current price preview widget ─────────────────────────────────────────────

class _CurrentPricePreview extends ConsumerWidget {
  final String productId;
  final String area;

  const _CurrentPricePreview({required this.productId, required this.area});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricesAsync = ref.watch(currentPricesProvider(area));

    return pricesAsync.when(
      data: (prices) {
        final match = prices.where((p) => p.productId == productId).toList();
        if (match.isEmpty) return const SizedBox.shrink();

        final price = match.first;
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.space16),
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGreen.withOpacity(0.06),
                AppTheme.primaryLight.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Harga Pasar Saat Ini',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  Text(
                    'Rp ${_formatNumber(price.medianPrice.toInt())}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    'per ${price.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space4),
              Row(
                children: [
                  Text(
                    'Min: Rp ${_formatNumber(price.minPrice.toInt())}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Text(
                    'Max: Rp ${_formatNumber(price.maxPrice.toInt())}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Text(
                    '${price.sampleSize} sampel',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

// ── Currency input formatter ─────────────────────────────────────────────────

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final number = int.parse(digits);
    final formatted = _formatNumber(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
