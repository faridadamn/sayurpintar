import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ApiClient().dio);
});

// ── Packages ────────────────────────────────────────────────────────────────

final myPackagesProvider =
    FutureProvider<List<SubscriptionPackage>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getMyPackages(activeOnly: false);
});

final activePackagesProvider =
    FutureProvider<List<SubscriptionPackage>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getMyPackages(activeOnly: true);
});

final packageDetailProvider =
    FutureProvider.family<SubscriptionPackage, String>((ref, id) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getPackageDetail(id);
});

// ── Subscribers ─────────────────────────────────────────────────────────────

final subscribersProvider = FutureProvider<List<Subscription>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getSubscribers(status: 'active');
});

final subscriberStatsProvider = FutureProvider<SubscriberStats>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getSubscriberStats();
});

// ── Orders ──────────────────────────────────────────────────────────────────

final todayOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getTodayOrders();
});

final orderSummaryProvider =
    FutureProvider.family<OrderSummary, String>((ref, date) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getOrderSummary(date);
});

// ── UI State ────────────────────────────────────────────────────────────────

final selectedPackageItemsProvider =
    StateProvider<List<PackageItem>>((ref) => []);

// ── Pelanggan: Subscriptions ──────────────────────────────────────────────

final myActiveSubscriptionsProvider =
    FutureProvider<List<Subscription>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getMyActiveSubscriptions();
});

final myPausedSubscriptionsProvider =
    FutureProvider<List<Subscription>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getMyPausedSubscriptions();
});

final subscriptionDetailProvider =
    FutureProvider.family<SubscriptionDetail, String>((ref, id) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getMySubscriptionDetail(id);
});

// ── Pelanggan: Browse ─────────────────────────────────────────────────────

final availablePackagesProvider =
    FutureProvider<List<SubscriptionPackage>>((ref) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getAvailablePackages();
});

final merchantPackagesProvider =
    FutureProvider.family<List<SubscriptionPackage>, String>(
        (ref, merchantId) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getAvailablePackages(query: merchantId);
});

// ── Pelanggan: Order History ──────────────────────────────────────────────

final orderHistoryProvider =
    FutureProvider.family<List<Order>, String>((ref, status) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getOrderHistory(status: status == 'semua' ? null : status);
});

// ── Pelanggan: Payment History ────────────────────────────────────────────

final paymentHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, subscriptionId) async {
  final repo = ref.read(subscriptionRepositoryProvider);
  return await repo.getPaymentHistory(subscriptionId);
});

// ── Pelanggan: UI State ──────────────────────────────────────────────────

final selectedPaymentMethodProvider = StateProvider<String>((ref) => 'cash');

final selectedPaymentFrequencyProvider =
    StateProvider<String>((ref) => 'per_kirim');

final searchQueryProvider = StateProvider<String>((ref) => '');

final orderHistoryFilterProvider = StateProvider<String>((ref) => 'semua');
