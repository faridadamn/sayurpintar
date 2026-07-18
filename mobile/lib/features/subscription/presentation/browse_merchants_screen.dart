import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class BrowseMerchantsScreen extends ConsumerStatefulWidget {
  const BrowseMerchantsScreen({super.key});

  @override
  ConsumerState<BrowseMerchantsScreen> createState() =>
      _BrowseMerchantsScreenState();
}

class _BrowseMerchantsScreenState extends ConsumerState<BrowseMerchantsScreen> {
  final _searchController = TextEditingController();
  String _selectedFrequency = 'semua';
  double? _maxPrice;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRupiah(double n) {
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(availablePackagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pedagang'),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: SPInput(
              label: '',
              hint: 'Cari pedagang atau paket...',
              controller: _searchController,
              prefixIcon: Icons.search,
              suffixIcon:
                  _searchController.text.isNotEmpty ? Icons.clear : null,
              onSuffixTap: () {
                _searchController.clear();
                setState(() {});
              },
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ── Filters ──
          if (_showFilters) _buildFilters(),

          // ── Results ──
          Expanded(
            child: packagesAsync.when(
              loading: () => const SPLoading(message: 'Mencari pedagang...'),
              error: (e, _) => SPErrorWidget(
                message: 'Gagal memuat pedagang: $e',
                onRetry: () => ref.invalidate(availablePackagesProvider),
              ),
              data: (packages) {
                // Apply filters
                var filtered = packages.where((pkg) {
                  final query = _searchController.text.toLowerCase();
                  if (query.isNotEmpty) {
                    if (!pkg.name.toLowerCase().contains(query) &&
                        !(pkg.description?.toLowerCase().contains(query) ??
                            false) &&
                        !pkg.pedagangId.toLowerCase().contains(query)) {
                      return false;
                    }
                  }
                  if (_selectedFrequency != 'semua' &&
                      pkg.frequency != _selectedFrequency) {
                    return false;
                  }
                  if (_maxPrice != null && pkg.price > _maxPrice!) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return SPEmptyState(
                    icon: Icons.search_off,
                    title: 'Tidak Ditemukan',
                    message: _searchController.text.isNotEmpty
                        ? 'Tidak ada paket yang cocok dengan "${_searchController.text}"'
                        : 'Belum ada pedagang dengan paket langganan di sekitarmu',
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final pkg = filtered[index];
                    return _buildPackageCard(context, pkg);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frequency filter
          const Text(
            'Frekuensi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('semua', 'Semua'),
              _filterChip('daily', 'Harian'),
              _filterChip('weekly', 'Mingguan'),
              _filterChip('twice_weekly', '2x Seminggu'),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          // Price filter
          Row(
            children: [
              const Text(
                'Harga maks: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _maxPrice ?? 500000,
                  min: 10000,
                  max: 500000,
                  divisions: 49,
                  activeColor: AppTheme.primaryGreen,
                  label:
                      _maxPrice != null ? _formatRupiah(_maxPrice!) : 'Semua',
                  onChanged: (v) => setState(() => _maxPrice = v),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _maxPrice = null),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFrequency == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFrequency = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen
              : AppTheme.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, SubscriptionPackage pkg) {
    return SPCard(
      onTap: () => _showPackageDetail(context, pkg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pedagang header
          Row(
            children: [
              SPAvatar(
                name: pkg.pedagangId,
                radius: 22,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedagang #${pkg.pedagangId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        const Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        const Icon(Icons.location_on,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        const Text(
                          '2.3 km',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  pkg.frequencyText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppTheme.space20),

          // Package info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (pkg.description != null &&
                        pkg.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pkg.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatRupiah(pkg.price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const Text(
                    '/pengiriman',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Items preview
          if (pkg.items.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: pkg.items.take(5).map((item) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '🥬 ${item.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (pkg.items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${pkg.items.length - 5} item lainnya',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],

          // Delivery days
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Kirim: ${pkg.deliveryDaysText}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          // Subscribe button
          const SizedBox(height: AppTheme.space12),
          SPButton(
            label: 'Berlangganan',
            onPressed: () => context.push('/subscribe', extra: pkg),
            icon: Icons.check_circle,
          ),
        ],
      ),
    );
  }

  void _showPackageDetail(BuildContext context, SubscriptionPackage pkg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: AppTheme.space12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Row(
                  children: [
                    SPAvatar(name: pkg.pedagangId, radius: 24),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Pedagang #${pkg.pedagangId}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.space16),
                  children: [
                    // Price
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _formatRupiah(pkg.price),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const Text(
                            'per pengiriman',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space16),

                    // Info
                    _detailRow('Frekuensi', pkg.frequencyText),
                    _detailRow('Hari Kirim', pkg.deliveryDaysText),
                    _detailRow('Jumlah Item', '${pkg.items.length} produk'),
                    if (pkg.subscriberCount != null)
                      _detailRow('Pelanggan', '${pkg.subscriberCount} orang'),

                    const SizedBox(height: AppTheme.space16),
                    const Text(
                      '📦 Isi Paket',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ...pkg.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Text('🥬 ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${item.qty} ${item.unit}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )),

                    const SizedBox(height: AppTheme.space24),
                    SPButton(
                      label: 'Berlangganan',
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/subscribe', extra: pkg);
                      },
                      icon: Icons.check_circle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
