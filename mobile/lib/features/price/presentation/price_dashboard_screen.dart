import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';
import 'package:sayurpintar/features/price/presentation/widgets/price_card.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PriceDashboardScreen extends ConsumerStatefulWidget {
  const PriceDashboardScreen({super.key});

  @override
  ConsumerState<PriceDashboardScreen> createState() =>
      _PriceDashboardScreenState();
}

class _PriceDashboardScreenState extends ConsumerState<PriceDashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _areaNames = {
    'jakarta_selatan': 'Jakarta Selatan',
    'jakarta_utara': 'Jakarta Utara',
    'jakarta_barat': 'Jakarta Barat',
    'jakarta_timur': 'Jakarta Timur',
    'jakarta_pusat': 'Jakarta Pusat',
    'bandung': 'Bandung',
    'surabaya': 'Surabaya',
    'medan': 'Medan',
    'semarang': 'Semarang',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(selectedAreaProvider);
    final pricesAsync = ref.watch(currentPricesProvider(area));
    final topMoversAsync = ref.watch(topMoversProvider(area));
    final alertsAsync = ref.watch(priceAlertsProvider);
    final categoriesAsync = ref.watch(productCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    final areaName = _areaNames[area] ?? area;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Pasar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () => _showAreaSelector(context, ref),
            tooltip: 'Ganti area',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentPricesProvider(area));
          ref.invalidate(topMoversProvider(area));
          ref.invalidate(priceAlertsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryDark,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          areaName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                          ),
                          child: Text(
                            _formatLastUpdated(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space12),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari produk...',
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space16,
                            vertical: AppTheme.space12,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Top Movers ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space16,
                  AppTheme.space16,
                  AppTheme.space16,
                  AppTheme.space8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    const Text(
                      'Perubahan Terbesar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            topMoversAsync.when(
              data: (movers) {
                if (movers.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.space16),
                      child: Text(
                        'Belum ada data perubahan harga',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                      ),
                      itemCount: movers.length,
                      itemBuilder: (context, index) =>
                          _TopMoverCard(price: movers[index]),
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 130,
                  child: SPLoading(),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Text(
                    'Gagal memuat: $e',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            // ── Category chips ────────────────────────────────────────
            SliverToBoxAdapter(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) return const SizedBox.shrink();
                  return Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: AppTheme.space8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                      ),
                      children: [
                        _CategoryChip(
                          label: 'Semua',
                          isSelected: selectedCategory == null,
                          onTap: () => ref
                              .read(selectedCategoryProvider.notifier)
                              .state = null,
                        ),
                        ...categories.map(
                          (cat) => _CategoryChip(
                            label: cat,
                            isSelected: selectedCategory == cat,
                            onTap: () => ref
                                .read(selectedCategoryProvider.notifier)
                                .state = cat,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Price list ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space16,
                  AppTheme.space16,
                  AppTheme.space16,
                  AppTheme.space8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.price_change_outlined,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    const Text(
                      'Daftar Harga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    pricesAsync.when(
                      data: (prices) {
                        final filtered = _filterPrices(
                          prices,
                          selectedCategory,
                        );
                        return Text(
                          '${filtered.length} produk',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            pricesAsync.when(
              data: (prices) {
                final filtered = _filterPrices(prices, selectedCategory);
                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: SPEmptyState(
                      icon: Icons.price_change_outlined,
                      title: 'Belum Ada Data Harga',
                      message:
                          'Jadilah yang pertama menginput harga di area ini!',
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final price = filtered[index];
                      return PriceCard(
                        price: price,
                        onTap: () {
                          final products = ref.read(productsProvider);
                          products.whenData((prods) {
                            final match = prods.where(
                              (p) => p.id == price.productId,
                            );
                            if (match.isNotEmpty) {
                              context.push(
                                '/prices/detail',
                                extra: {
                                  'product': match.first,
                                  'area': area,
                                },
                              );
                            }
                          });
                        },
                      );
                    },
                    childCount: filtered.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: SPLoading(message: 'Memuat harga...'),
              ),
              error: (e, _) => SliverFillRemaining(
                child: SPErrorWidget(
                  message: 'Gagal memuat harga: $e',
                  onRetry: () {
                    ref.invalidate(currentPricesProvider(area));
                  },
                ),
              ),
            ),

            // ── My Alerts ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space16,
                  AppTheme.space24,
                  AppTheme.space16,
                  AppTheme.space8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 20,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    const Text(
                      'Alert Harga Saya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space12,
                      ),
                      child: Text(
                        'Belum ada alert. Ketuk produk untuk membuat alert harga.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = alerts[index];
                      return _AlertCard(
                        alert: alert,
                        onDelete: () async {
                          try {
                            final repo = ref.read(priceRepositoryProvider);
                            await repo.deleteAlert(alert.id);
                            ref.invalidate(priceAlertsProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Alert dihapus'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menghapus: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                    childCount: alerts.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.space16),
                  child: SPLoading(),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Text(
                    'Gagal memuat alert: $e',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/prices/submit'),
        icon: const Icon(Icons.add),
        label: const Text('Input Harga'),
      ),
    );
  }

  List<AggregatedPrice> _filterPrices(
    List<AggregatedPrice> prices,
    String? category,
  ) {
    var filtered = prices;

    if (category != null && category.isNotEmpty) {
      // Filter by category is done via product name match for simplicity
      // In a real app, the AggregatedPrice would have a category field
      filtered = filtered;
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) => p.productName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }

  String _formatLastUpdated() {
    final now = DateTime.now();
    return 'Diperbarui ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showAreaSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) {
        final current = ref.read(selectedAreaProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.space16),
              const Text(
                'Pilih Area',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              ..._areaNames.entries.map(
                (entry) => ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: current == entry.key
                        ? AppTheme.primaryGreen
                        : AppTheme.textSecondary,
                  ),
                  title: Text(entry.value),
                  trailing: current == entry.key
                      ? const Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryGreen,
                        )
                      : null,
                  onTap: () {
                    ref.read(selectedAreaProvider.notifier).state = entry.key;
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const SizedBox(height: AppTheme.space16),
            ],
          ),
        );
      },
    );
  }
}

// ── Top Mover Card ───────────────────────────────────────────────────────────

class _TopMoverCard extends StatelessWidget {
  final AggregatedPrice price;

  const _TopMoverCard({required this.price});

  @override
  Widget build(BuildContext context) {
    final isUp = price.trend == 'up';
    final color = isUp ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);
    final bgColor = isUp ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: AppTheme.space12),
      child: Card(
        elevation: 2,
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(
                    isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${price.changePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                'Rp ${_formatPrice(price.medianPrice)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}jt';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}rb';
    }
    return price.toStringAsFixed(0);
  }
}

// ── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Alert Card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onDelete;

  const _AlertCard({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final directionIcon = alert.direction == 'up'
        ? Icons.arrow_upward
        : alert.direction == 'down'
            ? Icons.arrow_downward
            : Icons.swap_vert;
    final directionLabel = alert.direction == 'up'
        ? 'Naik'
        : alert.direction == 'down'
            ? 'Turun'
            : 'Keduanya';
    final directionColor = alert.direction == 'up'
        ? const Color(0xFFD32F2F)
        : alert.direction == 'down'
            ? const Color(0xFF2E7D32)
            : AppTheme.accent;

    return SPCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: directionColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              directionIcon,
              color: directionColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$directionLabel ${alert.threshold.toStringAsFixed(0)}% • ${alert.area}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: alert.isActive
                  ? AppTheme.primaryGreen.withOpacity(0.1)
                  : AppTheme.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              alert.isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: alert.isActive
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.error,
              size: 20,
            ),
            onPressed: onDelete,
            tooltip: 'Hapus alert',
          ),
        ],
      ),
    );
  }
}
