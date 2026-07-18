import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';

enum _SortBy { lowestPrice, nearest, highestRating }

class PriceComparisonScreen extends ConsumerStatefulWidget {
  final String productId;

  const PriceComparisonScreen({super.key, required this.productId});

  @override
  ConsumerState<PriceComparisonScreen> createState() =>
      _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends ConsumerState<PriceComparisonScreen> {
  _SortBy _sortBy = _SortBy.lowestPrice;

  static const Map<String, String> _sortLabels = {
    'lowest': 'Harga Terendah',
    'nearest': 'Terdekat',
    'rating': 'Rating Tertinggi',
  };

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
    final comparisonAsync =
        ref.watch(priceComparisonProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandingkan Harga'),
      ),
      body: comparisonAsync.when(
        data: (data) {
          final productName = data['product_name'] ?? 'Produk';
          final unit = data['unit'] ?? 'kg';
          final sellers = (data['sellers'] as List<dynamic>?) ?? [];
          final marketAvg = data['market_average'];

          // Sort sellers
          final sorted = List<dynamic>.from(sellers);
          sorted.sort((a, b) {
            switch (_sortBy) {
              case _SortBy.lowestPrice:
                return (a['price'] as num? ?? 0)
                    .compareTo(b['price'] as num? ?? 0);
              case _SortBy.nearest:
                return (a['distance'] as num? ?? 99999)
                    .compareTo(b['distance'] as num? ?? 99999);
              case _SortBy.highestRating:
                return (b['rating'] as num? ?? 0)
                    .compareTo(a['rating'] as num? ?? 0);
            }
          });

          return Column(
            children: [
              // ── Product header ──────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      'per $unit',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (marketAvg != null) ...[
                      const SizedBox(height: AppTheme.space12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          'Rata-rata pasar: ${_formatPrice(marketAvg)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Sort selector ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16, vertical: AppTheme.space12),
                child: Row(
                  children: [
                    const Text(
                      'Urutkan:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _SortBy.values.map((sort) {
                            final selected = _sortBy == sort;
                            final label = sort == _SortBy.lowestPrice
                                ? _sortLabels['lowest']!
                                : sort == _SortBy.nearest
                                    ? _sortLabels['nearest']!
                                    : _sortLabels['rating']!;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label,
                                    style: const TextStyle(fontSize: 12)),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _sortBy = sort),
                                selectedColor:
                                    AppTheme.primaryGreen.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? AppTheme.primaryGreen
                                      : AppTheme.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                  side: BorderSide(
                                    color: selected
                                        ? AppTheme.primaryGreen
                                        : AppTheme.divider,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Sellers list ────────────────────
              Expanded(
                child: sorted.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada pedagang yang menjual produk ini.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.only(bottom: AppTheme.space16),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final seller = sorted[index];
                          return _SellerComparisonCard(
                            seller: seller,
                            marketAvg: marketAvg,
                            formatPrice: _formatPrice,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const SPLoading(message: 'Memuat perbandingan...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.error),
                const SizedBox(height: AppTheme.space12),
                Text('Gagal memuat data: $e', textAlign: TextAlign.center),
                const SizedBox(height: AppTheme.space16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(priceComparisonProvider(widget.productId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerComparisonCard extends StatelessWidget {
  final dynamic seller;
  final dynamic marketAvg;
  final String Function(dynamic) formatPrice;

  const _SellerComparisonCard({
    required this.seller,
    required this.marketAvg,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    final name = seller['pedagang_name'] ?? 'Pedagang';
    final price = seller['price'];
    final rating = (seller['rating'] as num?)?.toDouble() ?? 0.0;
    final distance = seller['distance'];
    final isSubscribed = seller['is_subscribed'] == true;

    final priceNum = price is num ? price : 0;
    final avgNum = marketAvg is num ? marketAvg : 0;
    final isBelowAvg = avgNum > 0 && priceNum < avgNum;

    return SPCard(
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              // Name + rating + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSubscribed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: const Text(
                              '⭐ Langganan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: AppTheme.space12),
                          const Icon(Icons.location_on,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            _formatDistance(distance),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          // Price row
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      formatPrice(price),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: isBelowAvg
                            ? AppTheme.primaryGreen
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (marketAvg != null && marketAvg > 0) ...[
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBelowAvg
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      isBelowAvg
                          ? '↓ Di bawah rata-rata'
                          : '↑ Di atas rata-rata',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isBelowAvg ? AppTheme.primaryGreen : AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          // Order button
          SizedBox(
            width: double.infinity,
            child: SPButton(
              label: 'Pesan',
              icon: Icons.shopping_cart_outlined,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Memesan dari $name...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '-';
    final d = distance is double ? distance : (distance as num).toDouble();
    if (d < 1) return '${(d * 1000).toInt()} m';
    return '${d.toStringAsFixed(1)} km';
  }
}
