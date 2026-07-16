import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';
import 'package:sayurpintar/features/price/presentation/widgets/price_trend_chart.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PriceDetailScreen extends ConsumerStatefulWidget {
  final Product product;
  final String area;

  const PriceDetailScreen({
    super.key,
    required this.product,
    required this.area,
  });

  @override
  ConsumerState<PriceDetailScreen> createState() => _PriceDetailScreenState();
}

class _PriceDetailScreenState extends ConsumerState<PriceDetailScreen> {
  int _selectedDays = 7;
  double _marginPct = 30;
  final _thresholdController = TextEditingController(text: '10');
  String _alertDirection = 'up';

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendParams = PriceTrendParams(
      productId: widget.product.id,
      area: widget.area,
      days: _selectedDays,
    );
    final trendAsync = ref.watch(priceTrendProvider(trendParams));

    final recParams = RecommendedPriceParams(
      productId: widget.product.id,
      area: widget.area,
      marginPct: _marginPct,
    );
    final recAsync = ref.watch(recommendedPriceProvider(recParams));

    final pricesAsync = ref.watch(currentPricesProvider(widget.area));

    // Find current price for this product
    AggregatedPrice? currentPrice;
    pricesAsync.whenData((prices) {
      final match = prices.where((p) => p.productId == widget.product.id);
      if (match.isNotEmpty) currentPrice = match.first;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull,
                              ),
                            ),
                            child: Text(
                              widget.product.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Text(
                            'per ${widget.product.defaultUnit}',
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
              ],
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Current Price Card ──────────────────────────────────────
            _CurrentPriceCard(
              price: currentPrice,
              unit: widget.product.defaultUnit,
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Trend Chart ─────────────────────────────────────────────
            const Text(
              'Tren Harga',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            // Time period toggle
            Row(
              children: [
                _TimePeriodChip(
                  label: '7 Hari',
                  isSelected: _selectedDays == 7,
                  onTap: () => setState(() => _selectedDays = 7),
                ),
                const SizedBox(width: AppTheme.space8),
                _TimePeriodChip(
                  label: '30 Hari',
                  isSelected: _selectedDays == 30,
                  onTap: () => setState(() => _selectedDays = 30),
                ),
                const SizedBox(width: AppTheme.space8),
                _TimePeriodChip(
                  label: '90 Hari',
                  isSelected: _selectedDays == 90,
                  onTap: () => setState(() => _selectedDays = 90),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            trendAsync.when(
              data: (trend) => SPCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(AppTheme.space12),
                child: PriceTrendChart(
                  dataPoints: trend.dataPoints,
                  timePeriod: '${_selectedDays}d',
                ),
              ),
              loading: () => const SPCard(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 240,
                  child: SPLoading(message: 'Memuat tren...'),
                ),
              ),
              error: (e, _) => SPCard(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 200,
                  child: SPErrorWidget(
                    message: 'Gagal memuat tren: $e',
                    onRetry: () => ref.invalidate(priceTrendProvider(trendParams)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Recommended Selling Price ───────────────────────────────
            const Text(
              'Harga Jual Rekomendasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            recAsync.when(
              data: (rec) => _RecommendedPriceCard(
                recommended: rec,
                marginPct: _marginPct,
                onMarginChanged: (v) => setState(() => _marginPct = v),
                onUsePrice: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Harga Rp ${_formatNumber(rec.suggestedPrice.toInt())} disalin!',
                      ),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                  Clipboard.setData(
                    ClipboardData(text: rec.suggestedPrice.toStringAsFixed(0)),
                  );
                },
              ),
              loading: () => const SPCard(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 150,
                  child: SPLoading(message: 'Menghitung rekomendasi...'),
                ),
              ),
              error: (e, _) => SPCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: Text(
                    'Gagal memuat rekomendasi: $e',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Price History ───────────────────────────────────────────
            const Text(
              'Riwayat Harga',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            trendAsync.when(
              data: (trend) {
                if (trend.dataPoints.isEmpty) {
                  return const SPCard(
                    margin: EdgeInsets.zero,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.space16),
                        child: Text(
                          'Belum ada riwayat harga',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final reversed = trend.dataPoints.reversed.toList();
                return SPCard(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reversed.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final point = reversed[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        title: Text(
                          'Rp ${_formatNumber(point.price.toInt())}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          point.date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                          ),
                          child: Text(
                            '${point.samples} sampel',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SPCard(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 100,
                  child: SPLoading(),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Set Alert ───────────────────────────────────────────────
            const Text(
              'Buat Alert Harga',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            SPCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Batas perubahan (%)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '10',
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  const Text(
                    'Arah',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Row(
                    children: [
                      _DirectionChip(
                        label: 'Naik',
                        icon: Icons.arrow_upward,
                        color: const Color(0xFFD32F2F),
                        isSelected: _alertDirection == 'up',
                        onTap: () => setState(() => _alertDirection = 'up'),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      _DirectionChip(
                        label: 'Turun',
                        icon: Icons.arrow_downward,
                        color: const Color(0xFF2E7D32),
                        isSelected: _alertDirection == 'down',
                        onTap: () => setState(() => _alertDirection = 'down'),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      _DirectionChip(
                        label: 'Keduanya',
                        icon: Icons.swap_vert,
                        color: AppTheme.accent,
                        isSelected: _alertDirection == 'both',
                        onTap: () => setState(() => _alertDirection = 'both'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space16),
                  SPButton(
                    label: 'Buat Alert',
                    icon: Icons.notifications_active_outlined,
                    onPressed: () => _createAlert(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space40),
          ],
        ),
      ),
    );
  }

  Future<void> _createAlert() async {
    final thresholdText = _thresholdController.text.trim();
    if (thresholdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan batas perubahan harga'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final threshold = double.tryParse(thresholdText);
    if (threshold == null || threshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batas perubahan tidak valid'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      final repo = ref.read(priceRepositoryProvider);
      await repo.createAlert(
        CreateAlertRequest(
          productId: widget.product.id,
          area: widget.area,
          threshold: threshold,
          direction: _alertDirection,
        ),
      );

      ref.invalidate(priceAlertsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alert berhasil dibuat! Notifikasi saat harga '
              '${_alertDirection == 'up' ? 'naik' : _alertDirection == 'down' ? 'turun' : 'berubah'} '
              '${threshold.toStringAsFixed(0)}%',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat alert: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
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

// ── Current Price Card ───────────────────────────────────────────────────────

class _CurrentPriceCard extends StatelessWidget {
  final AggregatedPrice? price;
  final String unit;

  const _CurrentPriceCard({required this.price, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (price == null) {
      return SPCard(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              children: [
                Icon(
                  Icons.price_change_outlined,
                  size: 40,
                  color: AppTheme.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(height: AppTheme.space8),
                const Text(
                  'Belum ada data harga untuk produk ini',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = price!;
    final isUp = p.trend == 'up';
    final isDown = p.trend == 'down';
    final trendColor = isUp
        ? const Color(0xFFD32F2F)
        : isDown
            ? const Color(0xFF2E7D32)
            : AppTheme.textSecondary;

    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Median price
          Text(
            'Rp ${_formatPrice(p.medianPrice)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
          Text(
            'per $unit',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // Stats row
          Row(
            children: [
              // Min
              Expanded(
                child: _StatItem(
                  label: 'Terendah',
                  value: 'Rp ${_formatPrice(p.minPrice)}',
                  color: const Color(0xFF2E7D32),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.divider,
              ),
              // Max
              Expanded(
                child: _StatItem(
                  label: 'Tertinggi',
                  value: 'Rp ${_formatPrice(p.maxPrice)}',
                  color: const Color(0xFFD32F2F),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.divider,
              ),
              // Sample size
              Expanded(
                child: _StatItem(
                  label: 'Sampel',
                  value: '${p.sampleSize}',
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          // Trend indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp
                      ? Icons.arrow_upward
                      : isDown
                          ? Icons.arrow_downward
                          : Icons.remove,
                  size: 16,
                  color: trendColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isUp ? 'Naik' : isDown ? 'Turun' : 'Stabil'} ${p.changePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ),
        ],
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

// ── Stat Item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Time Period Chip ─────────────────────────────────────────────────────────

class _TimePeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimePeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

// ── Recommended Price Card ───────────────────────────────────────────────────

class _RecommendedPriceCard extends StatelessWidget {
  final RecommendedPrice recommended;
  final double marginPct;
  final ValueChanged<double> onMarginChanged;
  final VoidCallback onUsePrice;

  const _RecommendedPriceCard({
    required this.recommended,
    required this.marginPct,
    required this.onMarginChanged,
    required this.onUsePrice,
  });

  @override
  Widget build(BuildContext context) {
    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga Pasar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_formatNumber(recommended.marketPrice.toInt())}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                color: AppTheme.textSecondary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Harga Jual',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_formatNumber(recommended.suggestedPrice.toInt())}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),

          // Margin slider
          Row(
            children: [
              const Text(
                'Margin:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveTrackColor: AppTheme.primaryGreen.withOpacity(0.2),
                    thumbColor: AppTheme.primaryGreen,
                    overlayColor: AppTheme.primaryGreen.withOpacity(0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: marginPct,
                    min: 10,
                    max: 100,
                    divisions: 18,
                    onChanged: onMarginChanged,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${marginPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),

          SPButton(
            label: 'Gunakan Harga Ini',
            icon: Icons.copy,
            onPressed: onUsePrice,
          ),
        ],
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

// ── Direction Chip ───────────────────────────────────────────────────────────

class _DirectionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? color : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
