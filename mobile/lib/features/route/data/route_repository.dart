import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';

// ──────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────

class Waypoint {
  final String id;
  final String label;
  final String? address;
  final double latitude;
  final double longitude;
  final int priority;
  final bool isActive;
  final String? notes;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;
  final String? pelangganName;
  final int visitCount;

  const Waypoint({
    required this.id,
    required this.label,
    this.address,
    required this.latitude,
    required this.longitude,
    this.priority = 1,
    this.isActive = true,
    this.notes,
    this.preferredTimeStart,
    this.preferredTimeEnd,
    this.pelangganName,
    this.visitCount = 0,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      priority: json['priority'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      preferredTimeStart: json['preferred_time_start'] as String?,
      preferredTimeEnd: json['preferred_time_end'] as String?,
      pelangganName: json['pelanggan_name'] as String?,
      visitCount: json['visit_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'priority': priority,
      'is_active': isActive,
      'notes': notes,
      'preferred_time_start': preferredTimeStart,
      'preferred_time_end': preferredTimeEnd,
      'pelanggan_name': pelangganName,
      'visit_count': visitCount,
    };
  }
}

class RouteModel {
  final String id;
  final String date;
  final List<String> waypointIds;
  final List<String>? optimizedOrder;
  final double? totalDistanceKm;
  final int? estimatedDurationMin;
  final double? estimatedFuelCost;
  final String status;
  final List<WaypointWithOrder>? waypoints;

  const RouteModel({
    required this.id,
    required this.date,
    required this.waypointIds,
    this.optimizedOrder,
    this.totalDistanceKm,
    this.estimatedDurationMin,
    this.estimatedFuelCost,
    this.status = 'planned',
    this.waypoints,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      waypointIds: (json['waypoint_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      optimizedOrder: (json['optimized_order'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
      estimatedDurationMin: json['estimated_duration_min'] as int?,
      estimatedFuelCost: (json['estimated_fuel_cost'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'planned',
      waypoints: (json['waypoints'] as List<dynamic>?)
          ?.map((e) => WaypointWithOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'waypoint_ids': waypointIds,
      'optimized_order': optimizedOrder,
      'total_distance_km': totalDistanceKm,
      'estimated_duration_min': estimatedDurationMin,
      'estimated_fuel_cost': estimatedFuelCost,
      'status': status,
      'waypoints': waypoints?.map((e) => e.toJson()).toList(),
    };
  }
}

class WaypointWithOrder {
  final Waypoint waypoint;
  final int order;
  final String eta;

  const WaypointWithOrder({
    required this.waypoint,
    required this.order,
    required this.eta,
  });

  factory WaypointWithOrder.fromJson(Map<String, dynamic> json) {
    return WaypointWithOrder(
      waypoint: Waypoint.fromJson(json['waypoint'] as Map<String, dynamic>),
      order: json['order'] as int? ?? 0,
      eta: json['eta'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waypoint': waypoint.toJson(),
      'order': order,
      'eta': eta,
    };
  }
}

class OptimizedRoute {
  final List<WaypointWithOrder> orderedWaypoints;
  final double totalDistanceKm;
  final int estimatedDurationMin;
  final double estimatedFuelCost;
  final String? polyline;

  const OptimizedRoute({
    required this.orderedWaypoints,
    required this.totalDistanceKm,
    required this.estimatedDurationMin,
    required this.estimatedFuelCost,
    this.polyline,
  });

  factory OptimizedRoute.fromJson(Map<String, dynamic> json) {
    return OptimizedRoute(
      orderedWaypoints: (json['ordered_waypoints'] as List<dynamic>?)
              ?.map(
                  (e) => WaypointWithOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      estimatedDurationMin: json['estimated_duration_min'] as int? ?? 0,
      estimatedFuelCost: (json['estimated_fuel_cost'] as num?)?.toDouble() ?? 0,
      polyline: json['polyline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ordered_waypoints': orderedWaypoints.map((e) => e.toJson()).toList(),
      'total_distance_km': totalDistanceKm,
      'estimated_duration_min': estimatedDurationMin,
      'estimated_fuel_cost': estimatedFuelCost,
      'polyline': polyline,
    };
  }
}

class Visit {
  final String id;
  final String routeId;
  final String waypointId;
  final int visitOrder;
  final String? plannedArrival;
  final DateTime? actualArrival;
  final List<VisitItem>? itemsSold;
  final double? amount;
  final String status;
  final String? waypointLabel;
  final String? pelangganName;

  const Visit({
    required this.id,
    required this.routeId,
    required this.waypointId,
    this.visitOrder = 0,
    this.plannedArrival,
    this.actualArrival,
    this.itemsSold,
    this.amount,
    this.status = 'pending',
    this.waypointLabel,
    this.pelangganName,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      waypointId: json['waypoint_id'] as String? ?? '',
      visitOrder: json['visit_order'] as int? ?? 0,
      plannedArrival: json['planned_arrival'] as String?,
      actualArrival: json['actual_arrival'] != null
          ? DateTime.tryParse(json['actual_arrival'] as String)
          : null,
      itemsSold: (json['items_sold'] as List<dynamic>?)
          ?.map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      amount: (json['amount'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      waypointLabel: json['waypoint_label'] as String?,
      pelangganName: json['pelanggan_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'waypoint_id': waypointId,
      'visit_order': visitOrder,
      'planned_arrival': plannedArrival,
      'actual_arrival': actualArrival?.toIso8601String(),
      'items_sold': itemsSold?.map((e) => e.toJson()).toList(),
      'amount': amount,
      'status': status,
      'waypoint_label': waypointLabel,
      'pelanggan_name': pelangganName,
    };
  }
}

class VisitItem {
  final String productId;
  final String name;
  final double qty;
  final String unit;
  final double price;
  final double subtotal;

  const VisitItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.subtotal,
  });

  factory VisitItem.fromJson(Map<String, dynamic> json) {
    return VisitItem(
      productId: json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'kg',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'qty': qty,
      'unit': unit,
      'price': price,
      'subtotal': subtotal,
    };
  }
}

class VisitSummary {
  final int totalVisits;
  final int completed;
  final int skipped;
  final double totalRevenue;
  final double avgPerVisit;

  const VisitSummary({
    required this.totalVisits,
    required this.completed,
    required this.skipped,
    required this.totalRevenue,
    required this.avgPerVisit,
  });

  factory VisitSummary.fromJson(Map<String, dynamic> json) {
    return VisitSummary(
      totalVisits: json['total_visits'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      avgPerVisit: (json['avg_per_visit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_visits': totalVisits,
      'completed': completed,
      'skipped': skipped,
      'total_revenue': totalRevenue,
      'avg_per_visit': avgPerVisit,
    };
  }
}

class RouteStats {
  final double avgDistance;
  final double avgDuration;
  final double avgRevenue;
  final int totalRoutes;

  const RouteStats({
    required this.avgDistance,
    required this.avgDuration,
    required this.avgRevenue,
    required this.totalRoutes,
  });

  factory RouteStats.fromJson(Map<String, dynamic> json) {
    return RouteStats(
      avgDistance: (json['avg_distance'] as num?)?.toDouble() ?? 0,
      avgDuration: (json['avg_duration'] as num?)?.toDouble() ?? 0,
      avgRevenue: (json['avg_revenue'] as num?)?.toDouble() ?? 0,
      totalRoutes: json['total_routes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avg_distance': avgDistance,
      'avg_duration': avgDuration,
      'avg_revenue': avgRevenue,
      'total_routes': totalRoutes,
    };
  }
}

class AddWaypointRequest {
  final String label;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int priority;
  final String? notes;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;

  const AddWaypointRequest({
    required this.label,
    this.address,
    this.latitude,
    this.longitude,
    this.priority = 1,
    this.notes,
    this.preferredTimeStart,
    this.preferredTimeEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'priority': priority,
      if (notes != null) 'notes': notes,
      if (preferredTimeStart != null)
        'preferred_time_start': preferredTimeStart,
      if (preferredTimeEnd != null) 'preferred_time_end': preferredTimeEnd,
    };
  }
}

class UpdateWaypointRequest {
  final String? label;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? priority;
  final bool? isActive;
  final String? notes;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;

  const UpdateWaypointRequest({
    this.label,
    this.address,
    this.latitude,
    this.longitude,
    this.priority,
    this.isActive,
    this.notes,
    this.preferredTimeStart,
    this.preferredTimeEnd,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (label != null) map['label'] = label;
    if (address != null) map['address'] = address;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (priority != null) map['priority'] = priority;
    if (isActive != null) map['is_active'] = isActive;
    if (notes != null) map['notes'] = notes;
    if (preferredTimeStart != null) {
      map['preferred_time_start'] = preferredTimeStart;
    }
    if (preferredTimeEnd != null) {
      map['preferred_time_end'] = preferredTimeEnd;
    }
    return map;
  }
}

// ──────────────────────────────────────────────
// Repository
// ──────────────────────────────────────────────

class RouteRepository {
  final ApiClient _apiClient;

  RouteRepository(this._apiClient);

  Dio get _dio => _apiClient.dio;

  // ── Waypoints ────────────────────────────────

  Future<List<Waypoint>> getWaypoints({bool activeOnly = true}) async {
    final response = await _dio.get(
      ApiEndpoints.waypoints,
      queryParameters: {'active_only': activeOnly},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Waypoint> addWaypoint(AddWaypointRequest request) async {
    final response = await _dio.post(
      ApiEndpoints.waypoints,
      data: request.toJson(),
    );
    return Waypoint.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Waypoint> updateWaypoint(
    String id,
    UpdateWaypointRequest request,
  ) async {
    final response = await _dio.put(
      '${ApiEndpoints.waypoints}/$id',
      data: request.toJson(),
    );
    return Waypoint.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteWaypoint(String id) async {
    await _dio.delete('${ApiEndpoints.waypoints}/$id');
  }

  Future<List<Waypoint>> findNearby(
    double lat,
    double lng, {
    double radiusKm = 5,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '${ApiEndpoints.waypoints}/nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
        'limit': limit,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => Waypoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Route ────────────────────────────────────

  Future<RouteModel> getTodayRoute() async {
    final response = await _dio.get(ApiEndpoints.todayRoute);
    return RouteModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<OptimizedRoute> optimizeRoute() async {
    final response = await _dio.post(ApiEndpoints.optimizeRoute);
    return OptimizedRoute.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> startRoute() async {
    await _dio.post('${ApiEndpoints.todayRoute}/start');
  }

  Future<void> completeRoute(
    double actualDistance,
    int actualDuration,
  ) async {
    await _dio.post(
      '${ApiEndpoints.todayRoute}/complete',
      data: {
        'actual_distance': actualDistance,
        'actual_duration': actualDuration,
      },
    );
  }

  Future<void> addWaypointToRoute(String waypointId) async {
    await _dio.post(
      '${ApiEndpoints.todayRoute}/waypoints',
      data: {'waypoint_id': waypointId},
    );
  }

  Future<void> removeWaypointFromRoute(String waypointId) async {
    await _dio.delete(
      '${ApiEndpoints.todayRoute}/waypoints/$waypointId',
    );
  }

  // ── Visits ───────────────────────────────────

  Future<List<Visit>> getTodayVisits() async {
    final response = await _dio.get(
      '${ApiEndpoints.todayRoute}/visits',
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Visit> markVisitArrived(String visitId) async {
    final response = await _dio.post(
      '${ApiEndpoints.routes}/visits/$visitId/arrive',
    );
    return Visit.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Visit> markVisitCompleted(
    String visitId,
    List<VisitItem> items,
    double amount,
    String paymentMethod,
  ) async {
    final response = await _dio.post(
      '${ApiEndpoints.routes}/visits/$visitId/complete',
      data: {
        'items': items.map((e) => e.toJson()).toList(),
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
    return Visit.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> markVisitSkipped(String visitId, String reason) async {
    await _dio.post(
      '${ApiEndpoints.routes}/visits/$visitId/skip',
      data: {'reason': reason},
    );
  }

  Future<VisitSummary> getVisitSummary(String date) async {
    final response = await _dio.get(
      '${ApiEndpoints.routes}/visits/summary',
      queryParameters: {'date': date},
    );
    return VisitSummary.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  // ── History ──────────────────────────────────

  Future<List<RouteModel>> getRouteHistory(String from, String to) async {
    final response = await _dio.get(
      ApiEndpoints.routes,
      queryParameters: {'from': from, 'to': to},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RouteStats> getRouteStats(int days) async {
    final response = await _dio.get(
      '${ApiEndpoints.routes}/stats',
      queryParameters: {'days': days},
    );
    return RouteStats.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
