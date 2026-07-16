import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/storage/database_helper.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';
import 'package:sayurpintar/features/route/data/route_local_storage.dart';

// ──────────────────────────────────────────────
// Infrastructure providers
// ──────────────────────────────────────────────

final routeLocalStorageProvider = Provider<RouteLocalStorage>((ref) {
  return RouteLocalStorage(DatabaseHelper());
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(ApiClient());
});

// ──────────────────────────────────────────────
// Waypoints
// ──────────────────────────────────────────────

final waypointsProvider = FutureProvider<List<Waypoint>>((ref) async {
  final repo = ref.read(routeRepositoryProvider);
  final localStorage = ref.read(routeLocalStorageProvider);

  try {
    final waypoints = await repo.getWaypoints(activeOnly: false);
    await localStorage.cacheWaypoints(waypoints);
    return waypoints;
  } catch (e) {
    // Fallback to cached data
    final cached = await localStorage.getCachedWaypoints();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

final activeWaypointsProvider = Provider<List<Waypoint>>((ref) {
  final waypointsAsync = ref.watch(waypointsProvider);
  return waypointsAsync.when(
    data: (waypoints) => waypoints.where((wp) => wp.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ──────────────────────────────────────────────
// Today's route
// ──────────────────────────────────────────────

final todayRouteProvider = FutureProvider<RouteModel?>((ref) async {
  final repo = ref.read(routeRepositoryProvider);
  final localStorage = ref.read(routeLocalStorageProvider);

  try {
    final route = await repo.getTodayRoute();
    await localStorage.cacheTodayRoute(route);
    return route;
  } catch (e) {
    // Fallback to cached
    final cached = await localStorage.getCachedTodayRoute();
    return cached;
  }
});

final isRouteActiveProvider = StateProvider<bool>((ref) => false);

// ──────────────────────────────────────────────
// Visits
// ──────────────────────────────────────────────

final todayVisitsProvider = FutureProvider<List<Visit>>((ref) async {
  final repo = ref.read(routeRepositoryProvider);
  final localStorage = ref.read(routeLocalStorageProvider);

  try {
    final visits = await repo.getTodayVisits();
    await localStorage.cacheVisits(visits);
    return visits;
  } catch (e) {
    final cached = await localStorage.getCachedVisits();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

final visitSummaryProvider =
    FutureProvider.family<VisitSummary, String>((ref, date) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getVisitSummary(date);
});

// ──────────────────────────────────────────────
// Route optimization
// ──────────────────────────────────────────────

final optimizeRouteProvider = FutureProvider<OptimizedRoute?>((ref) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.optimizeRoute();
});

// ──────────────────────────────────────────────
// Route history
// ──────────────────────────────────────────────

final routeHistoryProvider =
    FutureProvider.family<List<RouteModel>, ({String from, String to})>(
        (ref, params) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getRouteHistory(params.from, params.to);
});

final routeStatsProvider =
    FutureProvider.family<RouteStats, int>((ref, days) async {
  final repo = ref.read(routeRepositoryProvider);
  return await repo.getRouteStats(days);
});

// ──────────────────────────────────────────────
// Offline queue
// ──────────────────────────────────────────────

final pendingActionsProvider = FutureProvider<List<OfflineAction>>((ref) async {
  final localStorage = ref.read(routeLocalStorageProvider);
  return await localStorage.getPendingActions();
});

// ──────────────────────────────────────────────
// Map / UI state
// ──────────────────────────────────────────────

final mapCenterProvider = StateProvider<double>((ref) => -6.2088);
final mapZoomProvider = StateProvider<double>((ref) => 14.0);
final selectedWaypointProvider = StateProvider<Waypoint?>((ref) => null);
final waypointFilterProvider =
    StateProvider<WaypointFilter>((ref) => WaypointFilter.all);

enum WaypointFilter { all, active, inactive }
