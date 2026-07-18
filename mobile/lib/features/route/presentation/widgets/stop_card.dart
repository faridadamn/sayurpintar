import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

/// Represents a waypoint with ordering information for display in route screens.
class WaypointWithOrder {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final int order;
  final double latitude;
  final double longitude;
  final String status; // 'pending', 'arrived', 'completed', 'skipped'
  final String? eta; // e.g. "08:45"
  final double? distanceKm; // distance from current position

  const WaypointWithOrder({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.order,
    required this.latitude,
    required this.longitude,
    this.status = 'pending',
    this.eta,
    this.distanceKm,
  });
}

/// Reusable card widget for displaying a single route stop.
///
/// Shows order number, customer name, address, ETA, distance,
/// and status badge. Tapping the card or call button triggers callbacks.
class StopCard extends StatelessWidget {
  final WaypointWithOrder stop;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onCall;

  const StopCard({
    super.key,
    required this.stop,
    this.isCurrent = false,
    this.isCompleted = false,
    this.onTap,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final statusLabel = _statusLabel();

    return Card(
      elevation: isCurrent ? 4 : 1,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: isCurrent
            ? const BorderSide(color: AppTheme.primaryGreen, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
          child: Row(
            children: [
              // ── Order number circle ────────────────
              _buildOrderBadge(),
              const SizedBox(width: AppTheme.space12),

              // ── Name + address + ETA ───────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w600,
                        color: isCompleted
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stop.eta != null || stop.distanceKm != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (stop.eta != null) ...[
                            const Icon(Icons.access_time,
                                size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              stop.eta!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          if (stop.eta != null && stop.distanceKm != null)
                            const SizedBox(width: AppTheme.space12),
                          if (stop.distanceKm != null) ...[
                            const Icon(Icons.straighten,
                                size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              _formatDistance(stop.distanceKm!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Status badge + call button ─────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (onCall != null && stop.phone != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onCall,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderBadge() {
    final bgColor = isCompleted
        ? AppTheme.textSecondary
        : isCurrent
            ? AppTheme.accent
            : AppTheme.primaryGreen;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '${stop.order}',
                style: TextStyle(
                  color: isCurrent ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: 'Nunito',
                ),
              ),
      ),
    );
  }

  Color _statusColor() {
    switch (stop.status) {
      case 'arrived':
        return AppTheme.accent;
      case 'completed':
        return AppTheme.primaryGreen;
      case 'skipped':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel() {
    switch (stop.status) {
      case 'arrived':
        return 'Di Lokasi';
      case 'completed':
        return 'Selesai';
      case 'skipped':
        return 'Dilewati';
      default:
        return 'Menunggu';
    }
  }

  String _formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}
