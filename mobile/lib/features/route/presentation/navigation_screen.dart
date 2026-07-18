import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/providers/tracking_provider.dart';
import 'package:sayurpintar/features/route/presentation/widgets/route_map_widget.dart';
import 'package:sayurpintar/features/route/presentation/widgets/stop_card.dart';
import 'package:sayurpintar/core/utils/connectivity_service.dart';

// ─── Screen ─────────────────────────────────────────

class NavigationScreen extends ConsumerStatefulWidget {
  final RouteData route;

  const NavigationScreen({super.key, required this.route});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  bool _showStopList = false;
  bool _hasArrivedNotified = false;
  bool _screenKeptOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startNavigation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreScreenTimeout();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep tracking even when app is in background
  }

  Future<void> _startNavigation() async {
    // Keep screen on during navigation
    _keepScreenOn(true);

    // Start GPS tracking
    final notifier = ref.read(trackingProvider.notifier);
    await notifier.startTracking(widget.route);
  }

  void _keepScreenOn(bool on) {
    if (on && !_screenKeptOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _screenKeptOn = true;
    } else if (!on && _screenKeptOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _screenKeptOn = false;
    }
  }

  void _restoreScreenTimeout() {
    _keepScreenOn(false);
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final padding = MediaQuery.of(context).padding;

    // Check for arrival notification
    if (tracking.isNearGeofence && !_hasArrivedNotified) {
      _hasArrivedNotified = true;
      _showArrivalNotification();
    }

    // Reset arrival flag when moving away
    if (!tracking.isNearGeofence) {
      _hasArrivedNotified = false;
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────
          _buildMap(tracking),

          // ── Top info card ────────────────────────
          Positioned(
            top: padding.top + AppTheme.space12,
            left: AppTheme.space12,
            right: AppTheme.space12,
            child: _buildTopCard(tracking),
          ),

          // ── Speed + info strip ───────────────────
          Positioned(
            top: padding.top + 110,
            right: AppTheme.space12,
            child: _buildSpeedBadge(tracking),
          ),

          // ── Offline indicator ────────────────────
          if (!tracking.isTracking)
            Positioned(
              top: padding.top + 110,
              left: AppTheme.space12,
              child: _buildOfflineBadge(),
            ),

          // ── Stop list toggle ─────────────────────
          Positioned(
            right: AppTheme.space12,
            bottom: 200,
            child: _buildToggleListButton(tracking),
          ),

          // ── Center on location button ────────────
          Positioned(
            right: AppTheme.space12,
            bottom: 260,
            child: _buildCenterButton(tracking),
          ),

          // ── Stop list panel ──────────────────────
          if (_showStopList)
            Positioned(
              top: padding.top + 150,
              left: 0,
              right: 0,
              bottom: 180,
              child: _buildStopList(tracking),
            ),

          // ── Bottom action bar ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(tracking),
          ),

          // ── Close / exit button ──────────────────
          Positioned(
            top: padding.top + AppTheme.space8,
            left: AppTheme.space8,
            child: _buildCloseButton(),
          ),
        ],
      ),
    );
  }

  // ─── Map ──────────────────────────────────────────

  Widget _buildMap(TrackingState tracking) {
    final markers = <WaypointMarker>[];
    for (int i = 0; i < tracking.waypoints.length; i++) {
      final wp = tracking.waypoints[i];
      markers.add(WaypointMarker(
        id: wp.id,
        position: wp.position,
        label: wp.name,
        order: wp.order,
        isCurrent: i == tracking.currentStopIndex,
        isCompleted: wp.status == 'completed',
      ));
    }

    // Build polyline to next stop
    List<LatLng>? polyline;
    if (tracking.currentLocation != null && tracking.currentStop != null) {
      polyline = [
        tracking.currentLocation!,
        tracking.currentStop!.position,
      ];
    }

    return RouteMapWidget(
      mapController: _mapController,
      markers: markers,
      polyline: polyline,
      currentLocation: tracking.currentLocation,
      showCurrentLocation: true,
      zoom: 16,
    );
  }

  // ─── Top card ─────────────────────────────────────

  Widget _buildTopCard(TrackingState tracking) {
    final stop = tracking.currentStop;
    final stopNum = tracking.currentStopIndex + 1;
    final total = tracking.totalStops;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Stop info
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    'Stop $stopNum dari $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Text(
                    stop?.name ?? 'Selesai',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Row 2: Address
            if (stop != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stop.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppTheme.space8),

            // Row 3: Distance + ETA
            Row(
              children: [
                // Distance
                if (tracking.distanceToNext != null) ...[
                  const Icon(Icons.straighten,
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Text(
                    _formatDistance(tracking.distanceToNext!),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
                const Spacer(),
                // ETA
                if (tracking.etaMinutes != null) ...[
                  const Icon(Icons.access_time,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Estimasi sampai: ${_formatETA(tracking.etaMinutes!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Speed badge ──────────────────────────────────

  Widget _buildSpeedBadge(TrackingState tracking) {
    final speed = tracking.speedKmh ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${speed.toStringAsFixed(0)} km/j',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Offline badge ────────────────────────────────

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.black87),
          SizedBox(width: 4),
          Text(
            'Mode Offline',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toggle stop list ─────────────────────────────

  Widget _buildToggleListButton(TrackingState tracking) {
    return FloatingActionButton.small(
      heroTag: 'toggle_list',
      backgroundColor: Colors.white,
      onPressed: () => setState(() => _showStopList = !_showStopList),
      child: Icon(
        _showStopList ? Icons.map : Icons.list,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  // ─── Center on location button ────────────────────

  Widget _buildCenterButton(TrackingState tracking) {
    return FloatingActionButton.small(
      heroTag: 'center_location',
      backgroundColor: Colors.white,
      onPressed: () {
        if (tracking.currentLocation != null) {
          _mapController.move(tracking.currentLocation!, 16);
        }
      },
      child: const Icon(Icons.my_location, color: AppTheme.primaryGreen),
    );
  }

  // ─── Stop list panel ──────────────────────────────

  Widget _buildStopList(TrackingState tracking) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white, size: 20),
                const SizedBox(width: AppTheme.space8),
                const Expanded(
                  child: Text(
                    'Daftar Kunjungan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showStopList = false),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              itemCount: tracking.waypoints.length,
              itemBuilder: (context, index) {
                final wp = tracking.waypoints[index];
                final isCurrent = index == tracking.currentStopIndex;
                final distance = tracking.currentLocation != null
                    ? _calculateDistanceMeters(
                        tracking.currentLocation!, wp.position)
                    : null;

                return StopCard(
                  stop: WaypointWithOrder(
                    id: wp.id,
                    name: wp.name,
                    address: wp.address,
                    phone: wp.phone,
                    order: wp.order,
                    latitude: wp.position.latitude,
                    longitude: wp.position.longitude,
                    status: wp.status,
                    distanceKm: distance != null ? distance / 1000 : null,
                  ),
                  isCurrent: isCurrent,
                  isCompleted: wp.status == 'completed',
                  onTap: () {
                    _mapController.move(wp.position, 16);
                    setState(() => _showStopList = false);
                  },
                  onCall: wp.phone != null ? () {} : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom action bar ────────────────────────────

  Widget _buildBottomBar(TrackingState tracking) {
    final stop = tracking.currentStop;
    final isFinished = tracking.isRouteFinished;

    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.space16,
        right: AppTheme.space16,
        top: AppTheme.space16,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.space16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: isFinished
          ? _buildFinishedBar(tracking)
          : _buildActiveBar(tracking, stop),
    );
  }

  Widget _buildFinishedBar(TrackingState tracking) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.celebration, color: AppTheme.accent, size: 36),
        const SizedBox(height: AppTheme.space8),
        const Text(
          'Rute Selesai! 🎉',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${tracking.completedStops} selesai, ${tracking.skippedStops} dilewati',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.space16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _finishRoute(tracking),
            icon: const Icon(Icons.check_circle),
            label: const Text('Selesai & Simpan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBar(TrackingState tracking, WaypointData? stop) {
    final arrived = stop?.status == 'arrived';
    final completed = stop?.status == 'completed';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        Row(
          children: [
            Text(
              '${tracking.completedStops}/${tracking.totalStops} selesai',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: tracking.totalStops > 0
                      ? tracking.completedStops / tracking.totalStops
                      : 0,
                  backgroundColor: AppTheme.divider.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),

        // Action buttons
        Row(
          children: [
            // Sampai button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: arrived || completed
                    ? null
                    : () => _markArrived(tracking),
                icon: Icon(
                  arrived ? Icons.check_circle : Icons.location_on,
                  size: 20,
                ),
                label: Text(arrived ? 'Sudah Sampai' : 'Sampai'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      arrived ? AppTheme.primaryLight : AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),

            // Lewati button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: completed
                    ? null
                    : () => _showSkipDialog(tracking),
                icon: const Icon(Icons.skip_next, size: 20),
                label: const Text('Lewati'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.error),
                  foregroundColor: AppTheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),

            // Telepon button
            if (stop?.phone != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryGreen),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: IconButton(
                  onPressed: () => _callCustomer(stop!.phone!),
                  icon: const Icon(Icons.phone,
                      color: AppTheme.primaryGreen),
                  tooltip: 'Telepon pelanggan',
                ),
              ),
          ],
        ),

        // "Mulai kunjungan" button when arrived
        if (arrived && !completed) ...[
          const SizedBox(height: AppTheme.space8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startVisitCompletion(tracking),
              icon: const Icon(Icons.shopping_cart, size: 20),
              label: const Text('Mulai Kunjungan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Close button ─────────────────────────────────

  Widget _buildCloseButton() {
    return IconButton(
      onPressed: () => _showExitDialog(),
      icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 24),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 2,
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────

  Future<void> _markArrived(TrackingState tracking) async {
    HapticFeedback.mediumImpact();
    await ref.read(trackingProvider.notifier).markArrived();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tiba di lokasi kunjungan'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSkipDialog(TrackingState tracking) {
    final reasons = [
      'Tidak ada di rumah',
      'Tutup / libur',
      'Jalan tidak bisa dilewati',
      'Alasan lain',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Lewati Kunjungan?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih alasan melewati kunjungan ini:'),
              const SizedBox(height: AppTheme.space12),
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedReason = v);
                    },
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(trackingProvider.notifier).skipVisit(selectedReason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Lewati'),
            ),
          ],
        ),
      ),
    );
  }

  void _callCustomer(String phone) {
    // Launch phone dialer
    // In production: launchUrl(Uri.parse('tel:$phone'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📞 Menghubungi $phone...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startVisitCompletion(TrackingState tracking) {
    final stop = tracking.currentStop;
    final visit = tracking.currentVisit;
    if (stop == null || visit == null) return;

    context.push('/visit/complete', extra: {
      'visit': visit,
      'waypoint': stop,
    });
  }

  void _finishRoute(TrackingState tracking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesaikan Rute?'),
        content: Text(
          'Anda sudah menyelesaikan kunjungan hari ini.\n'
          '${tracking.completedStops} selesai, ${tracking.skippedStops} dilewati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingProvider.notifier).stopTracking();
              _restoreScreenTimeout();
              context.go('/home');
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Navigasi?'),
        content: const Text(
          'Navigasi akan berhenti. Anda yakin ingin keluar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(trackingProvider.notifier).stopTracking();
              _restoreScreenTimeout();
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showArrivalNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white),
            const SizedBox(width: AppTheme.space8),
            const Expanded(
              child: Text(
                '📍 Anda sudah dekat tujuan! Ketuk "Sampai" jika sudah tiba.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.accent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m lagi';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km lagi';
  }

  String _formatETA(int minutes) {
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: minutes));
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double _calculateDistanceMeters(LatLng from, LatLng to) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(to.latitude - from.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(from.latitude)) *
            cos(_toRad(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * pi / 180.0;
}
