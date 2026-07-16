import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';

class PriceCard extends StatelessWidget {
  final AggregatedPrice price;
  final VoidCallback? onTap;

  const PriceCard({
    super.key,
    required this.price,
    this.onTap,
  });

  Color _trendColor(String trend) {
    switch (trend) {
      case 'up':
        return const Color(0xFFD32F2F);
      case 'down':
        return const Color(0xFF2E7D32);
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'up':
        return Icons.arrow_upward;
      case 'down':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'up':
        return 'Naik';
      case 'down':
        return 'Turun';
      default:
        return 'Stabil';
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}jt';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}rb';
    }
    return price.toStringAsFixed(0);
  }

  Color _reliabilityColor(int sampleSize) {
    if (sampleSize >= 10) return AppTheme.primaryGreen;
    if (sampleSize >= 5) return AppTheme.accent;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _trendColor(price.trend);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Row(
                      children: [
                        Text(
                          'per ${price.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        // Sample size indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _reliabilityColor(price.sampleSize)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 10,
                                color: _reliabilityColor(price.sampleSize),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${price.sampleSize}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _reliabilityColor(price.sampleSize),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Price and trend
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${_formatPrice(price.medianPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _trendIcon(price.trend),
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_trendLabel(price.trend)} ${price.changePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
