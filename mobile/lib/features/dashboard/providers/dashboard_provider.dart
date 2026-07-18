import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';

// ─── Repository ──────────────────────────────────────────────────────────────

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ApiClient());
});

// ─── Refresh trigger ─────────────────────────────────────────────────────────

final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Analytics ───────────────────────────────────────────────────────────────

final dailySummaryProvider = FutureProvider<DailySummary>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getDailySummary();
});

final weeklyComparisonProvider = FutureProvider<WeeklyComparison>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getWeeklyComparison();
});

final monthlyOverviewProvider = FutureProvider<MonthlyOverview>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getMonthlyOverview();
});

final topItemsProvider = FutureProvider<List<TopItem>>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getTopItems();
});

final customerAnalyticsProvider =
    FutureProvider<CustomerAnalytics>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getCustomerAnalytics();
});

final routeAnalyticsProvider = FutureProvider<RouteAnalytics>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getRouteAnalytics();
});

// ─── Insights ────────────────────────────────────────────────────────────────

final insightsProvider = FutureProvider<List<Insight>>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getInsights();
});

// ─── Rewards ─────────────────────────────────────────────────────────────────

final rewardBalanceProvider = FutureProvider<int>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getRewardBalance();
});

final badgeProvider = FutureProvider<RewardBadge>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getBadge();
});

final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getStreak();
});

final rewardHistoryProvider =
    FutureProvider<List<PointTransaction>>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getRewardHistory();
});

// ─── Notifications ───────────────────────────────────────────────────────────

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getNotifications();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(dashboardRefreshProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getUnreadCount();
});

// ─── Legacy compatibility (kept for existing screens) ────────────────────────

final transactionSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ApiClient().dio;
  final response = await dio.get('/api/v1/transactions/summary');
  return response.data['data'] ?? {};
});

final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ApiClient().dio;
  try {
    final response = await dio.get('/api/v1/transactions/summary');
    return response.data['data'] ?? {};
  } catch (e) {
    return {'omset': 0, 'modal': 0, 'untung': 0, 'margin': 0};
  }
});

final todayPricesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return repo.getCurrentPrices('Jakarta');
});

final priceAlertCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(priceAlertsProvider);
  return alerts.whenData((a) => a.length).valueOrNull ?? 0;
});
