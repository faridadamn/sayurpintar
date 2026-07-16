import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';
import 'package:sayurpintar/features/route/providers/route_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:intl/intl.dart';

class RouteOptimizedScreen extends ConsumerStatefulWidget {
  const RouteOptimizedScreen({super.key});

  @override
  ConsumerState<RouteOptimizedScreen> createState() =>
      _RouteOptimizedScreenState();
}

class _RouteOptimizedScreenState extends ConsumerState<RouteOptimizedScreen> {
  final MapController _mapController = MapController();
  bool _isStarting = false;
  int? _expandedStopIndex;

  @override
  void initState() {
    super.initState();
    // Trigger optimization on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(optimizeRouteProvider);
    });
  }

  List<Marker> _buildNumberedMarkers(OptimizedRoute optimized) {
    return optimized.orderedWaypoints.asMap().entries.map((entry) {
      final index = entry.key;
      final wp = entry.value.waypoint;
      final isExpanded = _expandedStopIndex == index;

      return Marker(
        point: LatLng(wp.latitude, wp.longitude),
        width: isExpanded ? 50 : 44,
        height: isExpanded ? 62 : 56,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _expandedStopIndex = isExpanded ? null : index;
            });
            _mapController.move(LatLng(wp.latitude, wp.longitude), 16);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 10 : 8,
                  vertical: isExpanded ? 5 : 4,
                ),
                decoration: BoxDecoration(
                  color: index == 0
                      ? AppTheme.primaryDark
                      : (isExpanded
                          ? AppTheme.accent
                          : AppTheme.primaryGreen),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isExpanded ? 14 : 12,
                  ),
                ),
              ),
              Icon(
                index == 0 ? Icons.flag : Icons.location_on,
                color: index == 0
                    ? AppTheme.primaryDark
                    : (isExpanded
                        ? AppTheme.accent
                        : AppTheme.primaryGreen),
                size: isExpanded ? 32 : 28,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Polyline> _buildPolylines(OptimizedRoute optimized) {
    if (optimized.orderedWaypoints.length < 2) return [];

    final points = optimized.orderedWaypoints
        .map((w) => LatLng(w.waypoint.latitude, w.waypoint.longitude))
        .toList();

    return [
      Polyline(
        points: points,
        color: AppTheme.primaryGreen.withOpacity(0.8),
        strokeWidth: 4,
        pattern: StrokePattern.dashed(segments: [12, 6]),
      ),
      // Shadow polyline for depth
      Polyline(
        points: points,
        color: AppTheme.primaryDark.withOpacity(0.2),
        strokeWidth: 8,
      ),
    ];
  }

  Future<void> _startNavigation() async {
    setState(() => _isStarting = true);

    try {
      final repo = ref.read(routeRepositoryProvider);
      await repo.startRoute();
      ref.invalidate(todayRouteProvider);
      ref.invalidate(isRouteActiveProvider);
      ref.read(isRouteActiveProvider.notifier).state = true;

      if (mounted) {
        context.push('/route/navigation');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai rute: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _reOptimize() async {
    ref.invalidate(optimizeRouteProvider);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Widget _buildInfoCards(OptimizedRoute optimized) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              icon: Icons.route,
              value: '${optimized.totalDistanceKm.toStringAsFixed(1)} km',
              label: 'Total Jarak',
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: _InfoCard(
              icon: Icons.access_time_filled,
              value: _formatDuration(optimized.estimatedDurationMin),
              label: 'Estimasi Waktu',
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: _InfoCard(
              icon: Icons.local_gas_station,
              value: _formatCurrency(optimized.estimatedFuelCost),
              label: 'Estimasi BBM',
              color: AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mnt';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '$hours j $mins mnt' : '$hours j';
  }

  Widget _buildStopList(OptimizedRoute optimized) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      itemCount: optimized.orderedWaypoints.length,
      itemBuilder: (context, index) {
        final stop = optimized.orderedWaypoints[index];
        final wp = stop.waypoint;
        final isFirst = index == 0;
        final isLast = index == optimized.orderedWaypoints.length - 1;
        final isExpanded = _expandedStopIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              _expandedStopIndex = isExpanded ? null : index;
            });
            _mapController.move(LatLng(wp.latitude, wp.longitude), 16);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isFirst
                              ? AppTheme.primaryDark
                              : (isLast
                                  ? AppTheme.error
                                  : AppTheme.primaryGreen),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isFirst
                              ? const Icon(
                                  Icons.flag,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : isLast
                                  ? const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : Text(
                                      '$index',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 32,
                          color: AppTheme.primaryGreen.withOpacity(0.3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space12),

                // Stop info
                Expanded(
                  child: SPCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(AppTheme.space12),
                    color: isExpanded
                        ? AppTheme.primaryGreen.withOpacity(0.05)
                        : Colors.white,
                    onTap: () {
                      setState(() {
                        _expandedStopIndex = isExpanded ? null : index;
                      });
                      _mapController.move(
                        LatLng(wp.latitude, wp.longitude),
                        16,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wp.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (wp.address != null)
                                    Text(
                                      wp.address!,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull,
                                ),
                              ),
                              child: Text(
                                'ETA ${stop.eta}',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: AppTheme.space8),
                          const Divider(height: 1),
                          const SizedBox(height: AppTheme.space8),
                          Row(
                            children: [
                              const Icon(
                                Icons.my_location,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${wp.latitude.toStringAsFixed(5)}, '
                                '${wp.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (wp.notes != null &&
                              wp.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.note,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    wp.notes!,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (wp.preferredTimeStart != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Jam: ${wp.preferredTimeStart}'
                                  '${wp.preferredTimeEnd != null ? ' - ${wp.preferredTimeEnd}' : ''}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final optimizedAsync = ref.watch(optimizeRouteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rute Dioptimasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Optimasi Ulang',
            onPressed: _reOptimize,
          ),
        ],
      ),
      body: optimizedAsync.when(
        data: (optimized) {
          if (optimized == null || optimized.orderedWaypoints.isEmpty) {
            return SPEmptyState(
              icon: Icons.route,
              title: 'Belum Ada Rute',
              message:
                  'Tambahkan waypoint terlebih dahulu lalu optimasi rute Anda.',
              actionLabel: 'Tambah Titik',
              onAction: () => context.push('/waypoints/add'),
            );
          }

          final bounds = LatLngBounds.fromPoints(
            optimized.orderedWaypoints
                .map((w) => LatLng(w.waypoint.latitude, w.waypoint.longitude))
                .toList(),
          );

          return Column(
            children: [
              // Map
              Expanded(
                flex: 2,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    bounds: bounds,
                    boundsOptions: const FitBoundsOptions(
                      padding: EdgeInsets.all(50),
                    ),
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sayurpintar.app',
                    ),
                    PolylineLayer(
                      polylines: _buildPolylines(optimized),
                    ),
                    MarkerLayer(
                      markers: _buildNumberedMarkers(optimized),
                    ),
                  ],
                ),
              ),

              // Info cards
              _buildInfoCards(optimized),

              // Stop list
              Expanded(
                flex: 3,
                child: Container(
                  color: AppTheme.background,
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: AppTheme.space8,
                      bottom: 100,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space16,
                          vertical: AppTheme.space8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.format_list_numbered,
                              size: 20,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(
                              '${optimized.orderedWaypoints.length} Titik Kunjungan',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _reOptimize,
                              icon: const Icon(Icons.auto_fix_high, size: 16),
                              label: const Text('Optimasi Ulang'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStopList(optimized),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const SPLoading(
          message: 'Mengoptimasi rute...\nIni mungkin butuh beberapa saat',
        ),
        error: (e, _) => SPErrorWidget(
          message: 'Gagal mengoptimasi rute. Coba lagi.',
          onRetry: _reOptimize,
        ),
      ),

      // Bottom action bar
      bottomSheet: optimizedAsync.when(
        data: (optimized) {
          if (optimized == null || optimized.orderedWaypoints.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SPButton(
                label: 'Mulai Navigasi',
                onPressed: _isStarting ? null : _startNavigation,
                isLoading: _isStarting,
                icon: Icons.navigation,
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Info card widget
// ──────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space12,
        horizontal: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
