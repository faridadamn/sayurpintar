import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/common/widgets/rating_widget.dart';
import 'package:sayurpintar/features/pelanggan/data/pelanggan_repository.dart';
import 'package:sayurpintar/features/pelanggan/providers/pelanggan_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class SearchMerchantScreen extends ConsumerStatefulWidget {
  const SearchMerchantScreen({super.key});

  @override
  ConsumerState<SearchMerchantScreen> createState() =>
      _SearchMerchantScreenState();
}

class _SearchMerchantScreenState extends ConsumerState<SearchMerchantScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showMap = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(merchantFilterProvider);
    final merchantsAsync = ref.watch(searchMerchantsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pedagang'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'Tampilan Daftar' : 'Tampilan Peta',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────
          _SearchBar(
            controller: _searchCtrl,
            focusNode: _focusNode,
            onChanged: (query) {
              ref.read(merchantSearchQueryProvider.notifier).state = query;
              _debounceSearch(ref, query, filter);
            },
            onClear: () {
              _searchCtrl.clear();
              ref.read(merchantSearchQueryProvider.notifier).state = '';
              ref.invalidate(searchMerchantsProvider(filter));
            },
          ),

          // ── Filter Chips ───────────────────────────────────────
          _FilterChips(
            currentFilter: filter,
            onFilterChanged: (newFilter) {
              ref.read(merchantFilterProvider.notifier).state = newFilter;
              ref.invalidate(searchMerchantsProvider(newFilter));
            },
          ),

          // ── Results ────────────────────────────────────────────
          Expanded(
            child: _showMap
                ? _MapPlaceholder(merchantsAsync: merchantsAsync)
                : merchantsAsync.when(
                    data: (merchants) {
                      if (merchants.isEmpty) {
                        return SPEmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Pedagang tidak ditemukan',
                          message:
                              'Coba ubah kata kunci atau perluas area pencarian.',
                          actionLabel: 'Reset Filter',
                          onAction: () {
                            _searchCtrl.clear();
                            ref.read(merchantFilterProvider.notifier).state =
                                const MerchantSearchParams();
                            ref.invalidate(searchMerchantsProvider);
                          },
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(searchMerchantsProvider(filter)),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.space8,
                          ),
                          itemCount: merchants.length,
                          itemBuilder: (context, index) {
                            return _MerchantCard(
                              merchant: merchants[index],
                              onTap: () => context.push(
                                '/merchant/${merchants[index].id}',
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const SPLoading(message: 'Mencari pedagang...'),
                    error: (e, _) => SPErrorWidget(
                      message: 'Gagal mencari pedagang.',
                      onRetry: () =>
                          ref.invalidate(searchMerchantsProvider(filter)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _debounceSearch(
      WidgetRef ref, String query, MerchantSearchParams current) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (query == ref.read(merchantSearchQueryProvider)) {
        final newFilter = MerchantSearchParams(
          area: current.area,
          query: query.isEmpty ? null : query,
          lat: current.lat,
          lng: current.lng,
          radiusKm: current.radiusKm,
          minRating: current.minRating,
          hasPackages: current.hasPackages,
        );
        ref.read(merchantFilterProvider.notifier).state = newFilter;
        ref.invalidate(searchMerchantsProvider(newFilter));
      }
    });
  }
}

// ── Search Bar ───────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space8,
        AppTheme.space16,
        AppTheme.space4,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari nama pedagang atau area...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            borderSide: BorderSide(
              color: AppTheme.divider.withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            borderSide: const BorderSide(
              color: AppTheme.primaryGreen,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter Chips ─────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final MerchantSearchParams currentFilter;
  final ValueChanged<MerchantSearchParams> onFilterChanged;

  const _FilterChips({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
        children: [
          _FilterChip(
            label: 'Terdekat',
            icon: Icons.near_me,
            isSelected:
                currentFilter.radiusKm != null && currentFilter.radiusKm! <= 5,
            onTap: () => onFilterChanged(MerchantSearchParams(
              area: currentFilter.area,
              query: currentFilter.query,
              lat: currentFilter.lat,
              lng: currentFilter.lng,
              radiusKm: 5,
              minRating: currentFilter.minRating,
              hasPackages: currentFilter.hasPackages,
            )),
          ),
          const SizedBox(width: AppTheme.space8),
          _FilterChip(
            label: 'Rating 4+',
            icon: Icons.star,
            isSelected: currentFilter.minRating != null &&
                currentFilter.minRating! >= 4,
            onTap: () => onFilterChanged(MerchantSearchParams(
              area: currentFilter.area,
              query: currentFilter.query,
              lat: currentFilter.lat,
              lng: currentFilter.lng,
              radiusKm: currentFilter.radiusKm,
              minRating: currentFilter.minRating != null ? null : 4,
              hasPackages: currentFilter.hasPackages,
            )),
          ),
          const SizedBox(width: AppTheme.space8),
          _FilterChip(
            label: 'Ada Paket',
            icon: Icons.inventory_2_outlined,
            isSelected: currentFilter.hasPackages == true,
            onTap: () => onFilterChanged(MerchantSearchParams(
              area: currentFilter.area,
              query: currentFilter.query,
              lat: currentFilter.lat,
              lng: currentFilter.lng,
              radiusKm: currentFilter.radiusKm,
              minRating: currentFilter.minRating,
              hasPackages: currentFilter.hasPackages == true ? null : true,
            )),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.space4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Merchant Card ────────────────────────────────────────────────────────

class _MerchantCard extends StatelessWidget {
  final MerchantWithPackages merchant;
  final VoidCallback onTap;

  const _MerchantCard({required this.merchant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SPCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SPAvatar(
                imageUrl: merchant.avatarUrl,
                name: merchant.name,
                radius: 28,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Row(
                      children: [
                        RatingWidget(
                          rating: merchant.rating.round(),
                          size: 14,
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          merchant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        const Icon(Icons.location_on,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          merchant.distanceText,
                          style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag,
                        size: 12, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${merchant.packageCount} paket',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Package Preview ────────────────────────────────────
          if (merchant.packages.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space12),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.space8),
            ...merchant.packages.take(2).map(
                  (pkg) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pkg.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatPrice(pkg.price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        Text(
                          '/${pkg.frequencyText}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (merchant.packages.length > 2)
              Text(
                '+${merchant.packages.length - 2} paket lainnya',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
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

// ── Map Placeholder ──────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  final AsyncValue<List<MerchantWithPackages>> merchantsAsync;

  const _MapPlaceholder({required this.merchantsAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.divider),
      ),
      child: merchantsAsync.when(
        data: (merchants) {
          return Stack(
            children: [
              // Map background placeholder
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      'Peta ${merchants.length} pedagang',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    const Text(
                      'Integrasi peta akan segera tersedia',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Merchant count badge
              Positioned(
                top: AppTheme.space16,
                right: AppTheme.space16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront,
                          size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: AppTheme.space4),
                      Text(
                        '${merchants.length} pedagang',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
        error: (_, __) => const Center(
          child: Text('Gagal memuat peta'),
        ),
      ),
    );
  }
}
