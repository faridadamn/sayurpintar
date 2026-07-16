import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PelangganPriceScreen extends ConsumerStatefulWidget {
  const PelangganPriceScreen({super.key});

  @override
  ConsumerState<PelangganPriceScreen> createState() =>
      _PelangganPriceScreenState();
}

class _PelangganPriceScreenState extends ConsumerState<PelangganPriceScreen> {
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  static const List<Map<String, String>> _categories = [
    {'label': 'Semua', 'icon': '🛒'},
    {'label': 'Sayur Hijau', 'icon': '🥬'},
    {'label': 'Bumbu', 'icon': '🌶️'},
    {'label': 'Buah', 'icon': '🍎'},
    {'label': 'Umbi', 'icon': '🥔'},
    {'label': 'Protein', 'icon': '🥩'},
  ];

  static const Map<String, String> _productEmojis = {
    'bayam': '🥬',
    'kangkung': '🥬',
    'sawi': '🥬',
    'wortel': '🥕',
    'kentang': '🥔',
    'bawang merah': '🧅',
    'bawang putih': '🧄',
    'cabai': '🌶️',
    'tomat': '🍅',
    'terong': '🍆',
    'pisang': '🍌',
    'apel': '🍎',
    'jeruk': '🍊',
    'telur': '🥚',
    'ayam': '🍗',
    'tempe': '🫘',
    'tahu': '🧈',
  };

  String _getProductEmoji(String productName) {
    final lower = productName.toLowerCase();
    for (final entry in _productEmojis.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return '🥗';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp -';
    final num = price is int ? price : (price as num).toInt();
    final str = num.toString();
    final buffer = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Pasar'),
        actions: [
          IconButton(
            onPressed: () => context.push('/price-alerts'),
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alert Harga',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header ──────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryLight],
              ),
            ),
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Area: ${_selectedAreaName()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                const Text(
                  'Harga pasar hari ini',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Diperbarui: ${_formattedDate()}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.space16, AppTheme.space12, AppTheme.space16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari nama produk...',
                prefixIcon: const Icon(Icons.search),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // ── Category chips ──────────────────────
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16, vertical: AppTheme.space8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTheme.space8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat['label'];
                return FilterChip(
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat['label']!),
                  label: Text('${cat['icon']} ${cat['label']}'),
                  selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppTheme.primaryGreen
                        : AppTheme.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.primaryGreen
                          : AppTheme.divider,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Price list ──────────────────────────
          Expanded(
            child: pricesAsync.when(
              data: (prices) {
                final filtered = _filterPrices(prices);
                if (filtered.isEmpty) {
                  return const SPEmptyState(
                    icon: Icons.search_off,
                    title: 'Produk Tidak Ditemukan',
                    message:
                        'Coba ubah kata kunci atau pilih kategori lain.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(pricesProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                        top: AppTheme.space8,
                        bottom: AppTheme.space80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _PriceCard(
                        price: filtered[index],
                        getEmoji: _getProductEmoji,
                        formatPrice: _formatPrice,
                        onTap: () {
                          final productId =
                              filtered[index]['product_id']?.toString() ?? '';
                          context.push('/price-compare',
                              extra: productId);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const SPLoading(message: 'Memuat harga...'),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.error),
                      const SizedBox(height: AppTheme.space12),
                      Text('Gagal memuat harga: $e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppTheme.space16),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(pricesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        color: AppTheme.primaryGreen.withOpacity(0.05),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Text(
                'Harga dari kontribusi pedagang di sekitarmu',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _selectedAreaName() {
    // Default area; in production this would come from location provider
    return 'Sekitarmu';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month]} ${now.year}';
  }

  List<dynamic> _filterPrices(List<dynamic> prices) {
    var result = prices;
    if (_selectedCategory != 'Semua') {
      result = result.where((p) {
        final cat = (p['category'] ?? '').toString().toLowerCase();
        return cat.contains(_selectedCategory.toLowerCase());
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) {
        final name = (p['product_name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }
    return result;
  }
}

class _PriceCard extends StatelessWidget {
  final dynamic price;
  final String Function(String) getEmoji;
  final String Function(dynamic) formatPrice;
  final VoidCallback onTap;

  const _PriceCard({
    required this.price,
    required this.getEmoji,
    required this.formatPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = price['product_name'] ?? 'Produk';
    final unit = price['unit'] ?? 'kg';
    final currentPrice = price['price'];
    final trend = (price['trend'] ?? 'stable').toString();

    final trendIcon = trend == 'up'
        ? '⬆️'
        : trend == 'down'
            ? '⬇️'
            : '➡️';
    final trendLabel = trend == 'up'
        ? 'Naik'
        : trend == 'down'
            ? 'Turun'
            : 'Stabil';
    final trendColor = trend == 'up'
        ? AppTheme.error
        : trend == 'down'
            ? AppTheme.primaryGreen
            : AppTheme.textSecondary;

    return SPCard(
      onTap: onTap,
      child: Row(
        children: [
          // Emoji icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            alignment: Alignment.center,
            child: Text(
              getEmoji(name),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          // Name + unit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'per $unit',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Price + trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(currentPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '$trendIcon $trendLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
