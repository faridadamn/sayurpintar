import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class DailySummary {
  final String date;
  final double totalRevenue;
  final double cashRevenue;
  final double qrisRevenue;
  final double transferRevenue;
  final double totalExpenses;
  final double grossProfit;
  final double profitMargin;
  final int totalOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final int pendingOrders;
  final int activeSubscriptions;
  final int todayDeliveries;
  final double routeDistanceKm;
  final int routeDurationMin;
  final int visitsCompleted;
  final int visitsSkipped;
  final double totalPiutang;
  final int piutangCount;
  final double revenueVsYesterday;
  final double ordersVsYesterday;
  final List<TopItem> topItems;

  const DailySummary({
    required this.date,
    required this.totalRevenue,
    required this.cashRevenue,
    required this.qrisRevenue,
    required this.transferRevenue,
    required this.totalExpenses,
    required this.grossProfit,
    required this.profitMargin,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.pendingOrders,
    required this.activeSubscriptions,
    required this.todayDeliveries,
    required this.routeDistanceKm,
    required this.routeDurationMin,
    required this.visitsCompleted,
    required this.visitsSkipped,
    required this.totalPiutang,
    required this.piutangCount,
    required this.revenueVsYesterday,
    required this.ordersVsYesterday,
    this.topItems = const [],
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: json['date'] ?? '',
      totalRevenue: _toDouble(json['total_revenue']),
      cashRevenue: _toDouble(json['cash_revenue']),
      qrisRevenue: _toDouble(json['qris_revenue']),
      transferRevenue: _toDouble(json['transfer_revenue']),
      totalExpenses: _toDouble(json['total_expenses']),
      grossProfit: _toDouble(json['gross_profit']),
      profitMargin: _toDouble(json['profit_margin']),
      totalOrders: json['total_orders'] ?? 0,
      deliveredOrders: json['delivered_orders'] ?? 0,
      cancelledOrders: json['cancelled_orders'] ?? 0,
      pendingOrders: json['pending_orders'] ?? 0,
      activeSubscriptions: json['active_subscriptions'] ?? 0,
      todayDeliveries: json['today_deliveries'] ?? 0,
      routeDistanceKm: _toDouble(json['route_distance_km']),
      routeDurationMin: json['route_duration_min'] ?? 0,
      visitsCompleted: json['visits_completed'] ?? 0,
      visitsSkipped: json['visits_skipped'] ?? 0,
      totalPiutang: _toDouble(json['total_piutang']),
      piutangCount: json['piutang_count'] ?? 0,
      revenueVsYesterday: _toDouble(json['revenue_vs_yesterday']),
      ordersVsYesterday: _toDouble(json['orders_vs_yesterday']),
      topItems: (json['top_items'] as List<dynamic>?)
              ?.map((e) => TopItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class WeeklyComparison {
  final WeekStats thisWeek;
  final WeekStats lastWeek;
  final WeekChanges changes;

  const WeeklyComparison({
    required this.thisWeek,
    required this.lastWeek,
    required this.changes,
  });

  factory WeeklyComparison.fromJson(Map<String, dynamic> json) {
    return WeeklyComparison(
      thisWeek: WeekStats.fromJson(json['this_week'] ?? {}),
      lastWeek: WeekStats.fromJson(json['last_week'] ?? {}),
      changes: WeekChanges.fromJson(json['changes'] ?? {}),
    );
  }
}

class WeekStats {
  final String startDate;
  final String endDate;
  final double totalRevenue;
  final int totalOrders;
  final double avgDailyRevenue;
  final String bestDay;
  final String worstDay;
  final List<DayRevenue>? dailyBreakdown;

  const WeekStats({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalOrders,
    required this.avgDailyRevenue,
    required this.bestDay,
    required this.worstDay,
    this.dailyBreakdown,
  });

  factory WeekStats.fromJson(Map<String, dynamic> json) {
    return WeekStats(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalRevenue: _toDouble(json['total_revenue']),
      totalOrders: json['total_orders'] ?? 0,
      avgDailyRevenue: _toDouble(json['avg_daily_revenue']),
      bestDay: json['best_day'] ?? '-',
      worstDay: json['worst_day'] ?? '-',
      dailyBreakdown: (json['daily_breakdown'] as List<dynamic>?)
          ?.map((e) => DayRevenue.fromJson(e))
          .toList(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class DayRevenue {
  final String date;
  final String dayName;
  final double revenue;
  final int orders;

  const DayRevenue({
    required this.date,
    required this.dayName,
    required this.revenue,
    required this.orders,
  });

  factory DayRevenue.fromJson(Map<String, dynamic> json) {
    return DayRevenue(
      date: json['date'] ?? '',
      dayName: json['day_name'] ?? '',
      revenue: _toDouble(json['revenue']),
      orders: json['orders'] ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class WeekChanges {
  final double revenueChangePct;
  final double ordersChangePct;
  final String trend;

  const WeekChanges({
    required this.revenueChangePct,
    required this.ordersChangePct,
    required this.trend,
  });

  factory WeekChanges.fromJson(Map<String, dynamic> json) {
    return WeekChanges(
      revenueChangePct: _toDouble(json['revenue_change_pct']),
      ordersChangePct: _toDouble(json['orders_change_pct']),
      trend: json['trend'] ?? 'stable',
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class MonthlyOverview {
  final String month;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final int totalOrders;
  final int uniqueCustomers;
  final double avgOrderValue;
  final String bestProduct;
  final double growthVsLastMonth;

  const MonthlyOverview({
    required this.month,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.totalOrders,
    required this.uniqueCustomers,
    required this.avgOrderValue,
    required this.bestProduct,
    required this.growthVsLastMonth,
  });

  factory MonthlyOverview.fromJson(Map<String, dynamic> json) {
    return MonthlyOverview(
      month: json['month'] ?? '',
      totalRevenue: _toDouble(json['total_revenue']),
      totalExpenses: _toDouble(json['total_expenses']),
      netProfit: _toDouble(json['net_profit']),
      totalOrders: json['total_orders'] ?? 0,
      uniqueCustomers: json['unique_customers'] ?? 0,
      avgOrderValue: _toDouble(json['avg_order_value']),
      bestProduct: json['best_product'] ?? '-',
      growthVsLastMonth: _toDouble(json['growth_vs_last_month']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class TopItem {
  final String productName;
  final double totalQty;
  final double totalRevenue;
  final int orderCount;
  final String unit;

  const TopItem({
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
    required this.orderCount,
    required this.unit,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      productName: json['product_name'] ?? '',
      totalQty: _toDouble(json['total_qty']),
      totalRevenue: _toDouble(json['total_revenue']),
      orderCount: json['order_count'] ?? 0,
      unit: json['unit'] ?? 'kg',
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class CustomerAnalytics {
  final int totalCustomers;
  final int activeCustomers;
  final int subscriberCustomers;
  final List<CustomerStat> topCustomers;
  final List<CustomerStat> atRiskCustomers;

  const CustomerAnalytics({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.subscriberCustomers,
    required this.topCustomers,
    required this.atRiskCustomers,
  });

  factory CustomerAnalytics.fromJson(Map<String, dynamic> json) {
    return CustomerAnalytics(
      totalCustomers: json['total_customers'] ?? 0,
      activeCustomers: json['active_customers'] ?? 0,
      subscriberCustomers: json['subscriber_customers'] ?? 0,
      topCustomers: (json['top_customers'] as List<dynamic>?)
              ?.map((e) => CustomerStat.fromJson(e))
              .toList() ??
          [],
      atRiskCustomers: (json['at_risk_customers'] as List<dynamic>?)
              ?.map((e) => CustomerStat.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class CustomerStat {
  final String customerName;
  final int totalOrders;
  final double totalSpent;
  final String lastOrderDate;
  final bool isSubscriber;

  const CustomerStat({
    required this.customerName,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastOrderDate,
    required this.isSubscriber,
  });

  factory CustomerStat.fromJson(Map<String, dynamic> json) {
    return CustomerStat(
      customerName: json['customer_name'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
      totalSpent: _toDouble(json['total_spent']),
      lastOrderDate: json['last_order_date'] ?? '',
      isSubscriber: json['is_subscriber'] ?? false,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class RouteAnalytics {
  final double avgDailyDistance;
  final double avgDailyDuration;
  final double avgVisitsPerDay;
  final double completionRate;
  final double efficiencyScore;

  const RouteAnalytics({
    required this.avgDailyDistance,
    required this.avgDailyDuration,
    required this.avgVisitsPerDay,
    required this.completionRate,
    required this.efficiencyScore,
  });

  factory RouteAnalytics.fromJson(Map<String, dynamic> json) {
    return RouteAnalytics(
      avgDailyDistance: _toDouble(json['avg_daily_distance']),
      avgDailyDuration: _toDouble(json['avg_daily_duration']),
      avgVisitsPerDay: _toDouble(json['avg_visits_per_day']),
      completionRate: _toDouble(json['completion_rate']),
      efficiencyScore: _toDouble(json['efficiency_score']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class Insight {
  final String id;
  final String type;
  final String priority;
  final String icon;
  final String title;
  final String message;
  final String action;
  final Map<String, String>? actionData;

  const Insight({
    required this.id,
    required this.type,
    required this.priority,
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.actionData,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      id: json['id'] ?? '',
      type: json['type'] ?? 'general',
      priority: json['priority'] ?? 'low',
      icon: json['icon'] ?? '💡',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      action: json['action'] ?? '',
      actionData: (json['action_data'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

class RewardBadge {
  final String level;
  final String name;
  final String icon;
  final int minPoints;
  final int maxPoints;
  final String? nextLevel;
  final int? pointsToNext;

  const RewardBadge({
    required this.level,
    required this.name,
    required this.icon,
    required this.minPoints,
    required this.maxPoints,
    this.nextLevel,
    this.pointsToNext,
  });

  factory RewardBadge.fromJson(Map<String, dynamic> json) {
    return RewardBadge(
      level: json['level'] ?? 'bronze',
      name: json['name'] ?? 'Pemula',
      icon: json['icon'] ?? '🥉',
      minPoints: json['min_points'] ?? 0,
      maxPoints: json['max_points'] ?? 100,
      nextLevel: json['next_level'],
      pointsToNext: json['points_to_next'],
    );
  }
}

class PointTransaction {
  final String id;
  final int amount;
  final int balance;
  final String reason;
  final DateTime createdAt;

  const PointTransaction({
    required this.id,
    required this.amount,
    required this.balance,
    required this.reason,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'] ?? '',
      amount: json['amount'] ?? 0,
      balance: json['balance'] ?? 0,
      reason: json['reason'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class DashboardRepository {
  final Dio _dio;

  DashboardRepository(ApiClient apiClient) : _dio = apiClient.dio;

  // ── Analytics ────────────────────────────────────────────────────────────

  Future<DailySummary> getDailySummary({String? date}) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/dashboard/daily-summary',
        queryParameters: {if (date != null) 'date': date},
      );
      return DailySummary.fromJson(response.data['data'] ?? {});
    } catch (e) {
      // Fallback: combine transaction summary + route stats
      final txResponse = await _dio.get(ApiEndpoints.transactionSummary);
      final txData = txResponse.data['data'] ?? {};
      return DailySummary(
        date: date ?? DateTime.now().toIso8601String().substring(0, 10),
        totalRevenue: _numToDouble(txData['omset']),
        cashRevenue: 0,
        qrisRevenue: 0,
        transferRevenue: 0,
        totalExpenses: _numToDouble(txData['modal']),
        grossProfit: _numToDouble(txData['untung']),
        profitMargin: _numToDouble(txData['margin']),
        totalOrders: 0,
        deliveredOrders: 0,
        cancelledOrders: 0,
        pendingOrders: 0,
        activeSubscriptions: 0,
        todayDeliveries: 0,
        routeDistanceKm: 0,
        routeDurationMin: 0,
        visitsCompleted: 0,
        visitsSkipped: 0,
        totalPiutang: 0,
        piutangCount: 0,
        revenueVsYesterday: 0,
        ordersVsYesterday: 0,
      );
    }
  }

  Future<WeeklyComparison> getWeeklyComparison() async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/dashboard/weekly-comparison',
    );
    return WeeklyComparison.fromJson(response.data['data'] ?? {});
  }

  Future<MonthlyOverview> getMonthlyOverview({String? month}) async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/dashboard/monthly-overview',
      queryParameters: {if (month != null) 'month': month},
    );
    return MonthlyOverview.fromJson(response.data['data'] ?? {});
  }

  Future<List<TopItem>> getTopItems({int days = 7, int limit = 10}) async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/dashboard/top-items',
      queryParameters: {'days': days, 'limit': limit},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list.map((e) => TopItem.fromJson(e)).toList();
  }

  Future<CustomerAnalytics> getCustomerAnalytics() async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/dashboard/customer-analytics',
    );
    return CustomerAnalytics.fromJson(response.data['data'] ?? {});
  }

  Future<RouteAnalytics> getRouteAnalytics({int days = 7}) async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/dashboard/route-analytics',
      queryParameters: {'days': days},
    );
    return RouteAnalytics.fromJson(response.data['data'] ?? {});
  }

  // ── Insights ─────────────────────────────────────────────────────────────

  Future<List<Insight>> getInsights() async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/dashboard/insights',
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => Insight.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Rewards ──────────────────────────────────────────────────────────────

  Future<int> getRewardBalance() async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/rewards/balance',
      );
      return response.data['data']['balance'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<RewardBadge> getBadge() async {
    try {
      final response = await _dio.get('${ApiEndpoints.base}/rewards/badge');
      return RewardBadge.fromJson(response.data['data'] ?? {});
    } catch (_) {
      return const RewardBadge(
        level: 'bronze',
        name: 'Pemula',
        icon: '🥉',
        minPoints: 0,
        maxPoints: 100,
        nextLevel: 'silver',
        pointsToNext: 100,
      );
    }
  }

  Future<List<PointTransaction>> getRewardHistory({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/rewards/history',
        queryParameters: {'limit': limit},
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => PointTransaction.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getStreak() async {
    try {
      final response = await _dio.get('${ApiEndpoints.base}/rewards/streak');
      return response.data['data']['streak'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/notifications',
        queryParameters: {
          'unread_only': unreadOnly,
          'limit': limit,
        },
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => AppNotification.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.base}/notifications/unread-count',
      );
      return response.data['data']['count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    await _dio.post('${ApiEndpoints.base}/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.post('${ApiEndpoints.base}/notifications/read-all');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static double _numToDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
