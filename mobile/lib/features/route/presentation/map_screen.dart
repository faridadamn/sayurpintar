import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';
import 'package:sayurpintar/features/route/providers/route_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Default center: Jakarta
  LatLng _currentCenter = const LatLng(-6.2088, 106.8456);
  LatLng? _userLocation;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showBottomSheet = true;
  Waypoint? _selectedWaypoint;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;

  @override
  void initState() {
    super.initState();
    _bottomSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeInOut,
    );
    _bottomSheetController.forward();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bottomSheetController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _currentCenter = _userLocation!;
        });
        _mapController.move(_currentCenter, 15);
      }
    } catch (_) {
      // Use default location
    }
  }

  void _onMapLongPress(TapPosition position, LatLng point) {
    _showAddWaypointDialog(point);
  }

  void _showAddWaypointDialog(LatLng point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            const Icon(
              Icons.add_location_alt,
              size: 48,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: AppTheme.space12),
            const Text(
              'Tambah Titik di Lokasi Ini?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Lat: ${point.latitude.toStringAsFixed(6)}, '
              'Lng: ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            SPButton(
              label: 'Tambah Waypoint',
              icon: Icons.add_location_alt,
              onPressed: () {
                Navigator.pop(ctx);
                context.push(
                  '/waypoints/add?lat=${point.latitude}&lng=${point.longitude}',
                );
              },
            ),
            const SizedBox(height: AppTheme.space8),
            SPButton(
              label: 'Batal',
              type: SPButtonType.text,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildWaypointMarkers(List<Waypoint> waypoints) {
    return waypoints.asMap().entries.map((entry) {
      final index = entry.key;
      final wp = entry.value;
      final isSelected = _selectedWaypoint?.id == wp.id;

      return Marker(
        point: LatLng(wp.latitude, wp.longitude),
        width: 44,
        height: 56,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedWaypoint = wp);
            _mapController.move(LatLng(wp.latitude, wp.longitude), 16);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent
                      : AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                Icons.location_on,
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.primaryGreen,
                size: 28,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Polyline> _buildRoutePolylines(OptimizedRoute? optimized) {
    if (optimized == null || optimized.orderedWaypoints.isEmpty) return [];

    final points = optimized.orderedWaypoints
        .map((w) => LatLng(w.waypoint.latitude, w.waypoint.longitude))
        .toList();

    return [
      Polyline(
        points: points,
        color: AppTheme.primaryGreen.withOpacity(0.7),
        strokeWidth: 4,
        pattern: StrokePattern.dashed(segments: [10, 5]),
      ),
    ];
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari alamat atau tempat...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
                // In production, debounce and call Nominatim geocoding API
              },
              onSubmitted: (_) {
                // Trigger search
              },
            ),
          ),
          if (_searchResults.isNotEmpty)
            Material(
              elevation: 4,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
              margin: const EdgeInsets.only(top: 4),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final result = _searchResults[i];
                  return ListTile(
                    leading:
                        const Icon(Icons.place, color: AppTheme.primaryGreen),
                    title: Text(result['name'] ?? ''),
                    subtitle: Text(result['address'] ?? ''),
                    onTap: () {
                      final lat = result['lat'] as double;
                      final lng = result['lng'] as double;
                      _mapController.move(LatLng(lat, lng), 16);
                      setState(() {
                        _searchResults = [];
                        _isSearching = false;
                      });
                      _searchController.text = result['name'] ?? '';
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: _showBottomSheet ? 200 : 100,
      child: Column(
        children: [
          _MapButton(
            icon: Icons.add,
            onPressed: () {
              final zoom = _mapController.zoom;
              _mapController.move(_mapController.center, zoom + 1);
            },
          ),
          const SizedBox(height: 8),
          _MapButton(
            icon: Icons.remove,
            onPressed: () {
              final zoom = _mapController.zoom;
              _mapController.move(_mapController.center, zoom - 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton() {
    return Positioned(
      right: 16,
      bottom: _showBottomSheet ? 280 : 180,
      child: _MapButton(
        icon: Icons.my_location,
        onPressed: () {
          if (_userLocation != null) {
            _mapController.move(_userLocation!, 16);
          } else {
            _getCurrentLocation();
          }
        },
      ),
    );
  }

  Widget _buildFABs() {
    return Positioned(
      right: 16,
      bottom: _showBottomSheet ? 140 : 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'optimize',
            backgroundColor: AppTheme.accent,
            onPressed: () {
              // Trigger route optimization
              ref.invalidate(optimizeRouteProvider);
              context.push('/route/optimized');
            },
            child: const Icon(Icons.auto_fix_high, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_waypoint',
            onPressed: () => context.push('/waypoints/add'),
            child: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStopSheet() {
    final visitsAsync = ref.watch(todayVisitsProvider);
    final routeAsync = ref.watch(todayRouteProvider);

    return visitsAsync.when(
      data: (visits) {
        if (visits.isEmpty) {
          return _buildNoRouteSheet();
        }

        final pendingVisits =
            visits.where((v) => v.status == 'pending').toList();
        final currentVisit = pendingVisits.isNotEmpty
            ? pendingVisits.first
            : null;

        return routeAsync.when(
          data: (route) {
            return AnimatedBuilder(
              animation: _bottomSheetAnimation,
              builder: (context, child) {
                return SizeTransition(
                  sizeFactor: _bottomSheetAnimation,
                  child: child,
                );
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLarge),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    GestureDetector(
                      onTap: () {
                        setState(() => _showBottomSheet = !_showBottomSheet);
                        if (_showBottomSheet) {
                          _bottomSheetController.forward();
                        } else {
                          _bottomSheetController.reverse();
                        }
                      },
                      child: Container(
                        margin:
                            const EdgeInsets.only(top: AppTheme.space12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Route stats row
                    if (route != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.space16,
                          AppTheme.space12,
                          AppTheme.space16,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatChip(
                              icon: Icons.route,
                              value:
                                  '${route.totalDistanceKm?.toStringAsFixed(1) ?? '-'} km',
                              label: 'Jarak',
                            ),
                            _StatChip(
                              icon: Icons.access_time,
                              value:
                                  '${route.estimatedDurationMin ?? '-'} min',
                              label: 'Estimasi',
                            ),
                            _StatChip(
                              icon: Icons.location_on,
                              value: '${route.waypointIds.length}',
                              label: 'Titik',
                            ),
                          ],
                        ),
                      ),

                    // Current/next stop
                    if (currentVisit != null)
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.space16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentVisit.waypointLabel ??
                                        currentVisit.pelangganName ??
                                        'Kunjungan Berikutnya',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (currentVisit.plannedArrival != null)
                                    Text(
                                      'ETA: ${currentVisit.plannedArrival}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SPButton(
                              label: 'Mulai',
                              isFullWidth: false,
                              onPressed: () {
                                context.push('/route/navigation');
                              },
                              icon: Icons.play_arrow,
                            ),
                          ],
                        ),
                      ),

                    // Actions row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.space16,
                        0,
                        AppTheme.space16,
                        AppTheme.space16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/waypoints'),
                              icon: const Icon(Icons.list, size: 18),
                              label: const Text('Semua Titik'),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/route/optimized'),
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text('Lihat Rute'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SPLoading(message: 'Memuat rute...'),
          error: (e, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SPLoading(message: 'Memuat kunjungan...'),
      error: (e, _) => SPErrorWidget(
        message: 'Gagal memuat data kunjungan',
        onRetry: () => ref.invalidate(todayVisitsProvider),
      ),
    );
  }

  Widget _buildNoRouteSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          const Icon(
            Icons.route,
            size: 40,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.space12),
          const Text(
            'Belum Ada Rute Hari Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          const Text(
            'Tambah waypoint dan optimasi rute untuk memulai',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space20),
          Row(
            children: [
              Expanded(
                child: SPButton(
                  label: 'Tambah Titik',
                  icon: Icons.add_location_alt,
                  onPressed: () => context.push('/waypoints/add'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: SPButton(
                  label: 'Daftar Titik',
                  type: SPButtonType.secondary,
                  icon: Icons.list,
                  onPressed: () => context.push('/waypoints'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waypointsAsync = ref.watch(waypointsProvider);
    final optimizeAsync = ref.watch(optimizeRouteProvider);
    final activeWaypoints = ref.watch(activeWaypointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Rute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Lokasi Saya',
            onPressed: () {
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 16);
              } else {
                _getCurrentLocation();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.invalidate(waypointsProvider);
              ref.invalidate(todayRouteProvider);
              ref.invalidate(todayVisitsProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentCenter,
              zoom: 14,
              onLongPress: _onMapLongPress,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sayurpintar.app',
                maxZoom: 19,
              ),

              // Route polylines
              optimizeAsync.when(
                data: (optimized) => PolylineLayer(
                  polylines: _buildRoutePolylines(optimized),
                ),
                loading: () => const PolylineLayer(polylines: []),
                error: (_, __) => const PolylineLayer(polylines: []),
              ),

              // Waypoint markers
              waypointsAsync.when(
                data: (waypoints) =>
                    MarkerLayer(markers: _buildWaypointMarkers(waypoints)),
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),

              // User location marker
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Search bar
          _buildSearchBar(),

          // Zoom controls
          _buildZoomControls(),

          // Location button
          _buildLocationButton(),

          // FABs
          _buildFABs(),

          // Selected waypoint info popup
          if (_selectedWaypoint != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Material(
                elevation: 6,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                  ),
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
                          Icons.location_on,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedWaypoint!.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (_selectedWaypoint!.address != null)
                              Text(
                                _selectedWaypoint!.address!,
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
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () =>
                            setState(() => _selectedWaypoint = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Bottom sheet
      bottomSheet: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _showBottomSheet ? _buildCurrentStopSheet() : const SizedBox.shrink(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppTheme.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
