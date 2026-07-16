import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sayurpintar/core/utils/connectivity_service.dart';
import 'package:sayurpintar/core/utils/sync_manager.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';

// ─── Models ─────────────────────────────────────────

class WaypointData {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final LatLng position;
  final int order;
  final String status; // 'pending', 'arrived', 'completed', 'skipped'

  const WaypointData({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.position,
    required this.order,
    this.status = 'pending',
  });

  WaypointData copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    LatLng? position,
    int? order,
    String? status,
  }) {
    return WaypointData(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      order: order ?? this.order,
      status: status ?? this.status,
    );
  }
}

class VisitData {
  final String id;
  final String waypointId;
  final String status; // 'pending', 'arrived', 'completed', 'skipped'
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const VisitData({
    required this.id,
    required this.waypointId,
    this.status = 'pending',
    this.arrivedAt,
    this.completedAt,
  });

  VisitData copyWith({
    String? id,
    String? waypointId,
    String? status,
    DateTime? arrivedAt,
    DateTime? completedAt,
  }) {
    return VisitData(
      id: id ?? this.id,
      waypointId: waypointId ?? this.waypointId,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class RouteData {
  final String id;
  final String name;
  final List<WaypointData> waypoints;
  final List<VisitData> visits;

  const RouteData({
    required this.id,
    required this.name,
    required this.waypoints,
    required this.visits,
  });
}

// ─── Tracking State ─────────────────────────────────

class TrackingState {
  final bool isTracking;
  final LatLng? currentLocation;
  final double? speed; // m/s
  final double? speedKmh;
  final double? distanceToNext; // meters
  final int? etaMinutes;
  final int currentStopIndex;
  final List<WaypointData> waypoints;
  final List<VisitData> visits;
  final bool isNearGeofence;
  final String? errorMessage;

  const TrackingState({
    this.isTracking = false,
    this.currentLocation,
    this.speed,
    this.speedKmh,
    this.distanceToNext,
    this.etaMinutes,
    this.currentStopIndex = 0,
    this.waypoints = const [],
    this.visits = const [],
    this.isNearGeofence = false,
    this.errorMessage,
  });

  WaypointData? get currentStop =>
      currentStopIndex < waypoints.length
          ? waypoints[currentStopIndex]
          : null;

  VisitData? get currentVisit {
    final stop = currentStop;
    if (stop == null) return null;
    try {
      return visits.firstWhere((v) => v.waypointId == stop.id);
    } catch (_) {
      return null;
    }
  }

  int get totalStops => waypoints.length;
  int get completedStops =>
      waypoints.where((w) => w.status == 'completed').length;
  int get skippedStops =>
      waypoints.where((w) => w.status == 'skipped').length;
  bool get isRouteFinished =>
      currentStopIndex >= waypoints.length;

  TrackingState copyWith({
    bool? isTracking,
    LatLng? currentLocation,
    double? speed,
    double? speedKmh,
    double? distanceToNext,
    int? etaMinutes,
    int? currentStopIndex,
    List<WaypointData>? waypoints,
    List<VisitData>? visits,
    bool? isNearGeofence,
    String? errorMessage,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      currentLocation: currentLocation ?? this.currentLocation,
      speed: speed ?? this.speed,
      speedKmh: speedKmh ?? this.speedKmh,
      distanceToNext: distanceToNext ?? this.distanceToNext,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      waypoints: waypoints ?? this.waypoints,
      visits: visits ?? this.visits,
      isNearGeofence: isNearGeofence ?? this.isNearGeofence,
      errorMessage: errorMessage,
    );
  }
}

// ─── Tracking Notifier ──────────────────────────────

class TrackingNotifier extends StateNotifier<TrackingState> {
  final RouteRepository _repo;
  final SyncManager _syncManager = SyncManager();
  final ConnectivityService _connectivity = ConnectivityService();

  StreamSubscription<Position>? _positionSub;
  Timer? _locationSender;
  DateTime? _navigationStartTime;

  TrackingNotifier(this._repo) : super(const TrackingState());

  // ─── Start GPS tracking for a route ───────────────

  Future<void> startTracking(RouteData route) async {
    // Build waypoints and visits lists
    final waypoints = route.waypoints;
    final visits = route.visits;

    // Find the first non-completed, non-skipped stop
    int startIndex = 0;
    for (int i = 0; i < waypoints.length; i++) {
      if (waypoints[i].status == 'pending') {
        startIndex = i;
        break;
      }
    }

    state = state.copyWith(
      isTracking: true,
      currentStopIndex: startIndex,
      waypoints: waypoints,
      visits: visits,
      errorMessage: null,
    );

    _navigationStartTime = DateTime.now();

    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          errorMessage: 'Izin lokasi ditolak. Aktifkan di Pengaturan.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        errorMessage:
            'Izin lokasi ditolak permanen. Aktifkan di Pengaturan HP.',
      );
      return;
    }

    // Start listening to position updates
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    ).listen(_onPositionUpdate);

    // Send location to backend every 15 seconds
    _locationSender = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendLocationToBackend(),
    );
  }

  // ─── Stop GPS tracking ───────────────────────────

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _locationSender?.cancel();
    _locationSender = null;
    _navigationStartTime = null;

    state = state.copyWith(isTracking: false);
  }

  // ─── Position update callback ────────────────────

  void _onPositionUpdate(Position position) {
    final current = LatLng(position.latitude, position.longitude);
    final speedMs = position.speed; // m/s from GPS
    final speedKmh = speedMs * 3.6;

    double? distanceMeters;
    int? eta;

    final stop = state.currentStop;
    if (stop != null) {
      distanceMeters = _calculateDistance(current, stop.position);

      // Calculate ETA based on current speed or average 30 km/h
      final effectiveSpeed = speedKmh > 2 ? speedKmh : 30.0;
      eta = (distanceMeters / 1000 / effectiveSpeed * 60).ceil();

      // Geofence check — within 100 meters
      final isNear = distanceMeters <= 100;
      if (isNear && !state.isNearGeofence) {
        // Just entered geofence — mark as arrived automatically
        _onGeofenceEntered();
      }

      state = state.copyWith(
        currentLocation: current,
        speed: speedMs,
        speedKmh: speedKmh,
        distanceToNext: distanceMeters,
        etaMinutes: eta,
        isNearGeofence: isNear,
      );
    } else {
      state = state.copyWith(
        currentLocation: current,
        speed: speedMs,
        speedKmh: speedKmh,
      );
    }
  }

  // ─── Geofence entered ────────────────────────────

  void _onGeofenceEntered() {
    // Auto-mark arrived (the UI will show a notification)
    // Actual arrived marking is done via markArrived()
  }

  // ─── Mark visit arrived ──────────────────────────

  Future<void> markArrived() async {
    final stop = state.currentStop;
    final visit = state.currentVisit;
    if (stop == null || visit == null) return;

    // Update local state
    final updatedWaypoints = List<WaypointData>.from(state.waypoints);
    updatedWaypoints[state.currentStopIndex] =
        stop.copyWith(status: 'arrived');

    final updatedVisits = List<VisitData>.from(state.visits);
    final visitIdx = updatedVisits.indexWhere((v) => v.id == visit.id);
    if (visitIdx >= 0) {
      updatedVisits[visitIdx] = visit.copyWith(
        status: 'arrived',
        arrivedAt: DateTime.now(),
      );
    }

    state = state.copyWith(
      waypoints: updatedWaypoints,
      visits: updatedVisits,
    );

    // Sync to backend (or queue offline)
    final connected = await _connectivity.isConnected;
    if (connected) {
      try {
        await _repo.completeVisit(visit.id, {
          'status': 'arrived',
          'arrived_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        await _syncManager.queueAction('mark_visited', {
          'visit_id': visit.id,
          'arrived_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      await _syncManager.queueAction('mark_visited', {
        'visit_id': visit.id,
        'arrived_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ─── Mark visit completed ────────────────────────

  Future<void> markCompleted(
    List<Map<String, dynamic>> items,
    double amount,
    String paymentMethod,
  ) async {
    final stop = state.currentStop;
    final visit = state.currentVisit;
    if (stop == null || visit == null) return;

    // Update local state
    final updatedWaypoints = List<WaypointData>.from(state.waypoints);
    updatedWaypoints[state.currentStopIndex] =
        stop.copyWith(status: 'completed');

    final updatedVisits = List<VisitData>.from(state.visits);
    final visitIdx = updatedVisits.indexWhere((v) => v.id == visit.id);
    if (visitIdx >= 0) {
      updatedVisits[visitIdx] = visit.copyWith(
        status: 'completed',
        completedAt: DateTime.now(),
      );
    }

    state = state.copyWith(
      waypoints: updatedWaypoints,
      visits: updatedVisits,
    );

    // Sync or queue
    final connected = await _connectivity.isConnected;
    if (connected) {
      try {
        await _repo.completeVisit(visit.id, {
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
          'items': items,
          'amount': amount,
          'payment_method': paymentMethod,
        });
      } catch (_) {
        await _syncManager.queueAction('mark_completed', {
          'visit_id': visit.id,
          'items': items,
          'amount': amount,
          'payment_method': paymentMethod,
        });
      }
    } else {
      await _syncManager.queueAction('mark_completed', {
        'visit_id': visit.id,
        'items': items,
        'amount': amount,
        'payment_method': paymentMethod,
      });
    }
  }

  // ─── Skip current visit ──────────────────────────

  Future<void> skipVisit(String reason) async {
    final stop = state.currentStop;
    final visit = state.currentVisit;
    if (stop == null || visit == null) return;

    final updatedWaypoints = List<WaypointData>.from(state.waypoints);
    updatedWaypoints[state.currentStopIndex] =
        stop.copyWith(status: 'skipped');

    final updatedVisits = List<VisitData>.from(state.visits);
    final visitIdx = updatedVisits.indexWhere((v) => v.id == visit.id);
    if (visitIdx >= 0) {
      updatedVisits[visitIdx] = visit.copyWith(status: 'skipped');
    }

    state = state.copyWith(
      waypoints: updatedWaypoints,
      visits: updatedVisits,
    );

    // Sync or queue
    final connected = await _connectivity.isConnected;
    if (connected) {
      try {
        await _repo.completeVisit(visit.id, {
          'status': 'skipped',
          'reason': reason,
        });
      } catch (_) {
        await _syncManager.queueAction('skip_visit', {
          'visit_id': visit.id,
          'reason': reason,
        });
      }
    } else {
      await _syncManager.queueAction('skip_visit', {
        'visit_id': visit.id,
        'reason': reason,
      });
    }

    // Move to next stop
    nextStop();
  }

  // ─── Move to next stop ──────────────────────────

  void nextStop() {
    if (state.currentStopIndex < state.waypoints.length - 1) {
      state = state.copyWith(
        currentStopIndex: state.currentStopIndex + 1,
        isNearGeofence: false,
        distanceToNext: null,
        etaMinutes: null,
      );
    }
  }

  // ─── Get navigation elapsed time ────────────────

  Duration? get elapsedTime {
    if (_navigationStartTime == null) return null;
    return DateTime.now().difference(_navigationStartTime!);
  }

  // ─── Send location to backend ────────────────────

  Future<void> _sendLocationToBackend() async {
    if (state.currentLocation == null) return;

    final connected = await _connectivity.isConnected;
    final locationData = {
      'latitude': state.currentLocation!.latitude,
      'longitude': state.currentLocation!.longitude,
      'speed': state.speed ?? 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (connected) {
      try {
        // Send via API — the actual endpoint is handled by the backend WebSocket
        // For now, queue it to be safe
        await _syncManager.queueAction('update_location', locationData);
      } catch (_) {
        // Silently fail — next update will cover it
      }
    } else {
      await _syncManager.queueAction('update_location', locationData);
    }
  }

  // ─── Distance calculation (Haversine) ────────────

  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0; // meters
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

  @override
  void dispose() {
    _positionSub?.cancel();
    _locationSender?.cancel();
    super.dispose();
  }
}

// ─── Providers ──────────────────────────────────────

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref.read(routeRepositoryProvider));
});
