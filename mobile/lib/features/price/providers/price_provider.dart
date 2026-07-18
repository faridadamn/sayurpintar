import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository();
});

// ── Parameters ───────────────────────────────────────────────────────────────

class PriceTrendParams {
  final String productId;
  final String area;
  final int days;

  const PriceTrendParams({
    required this.productId,
    required this.area,
    this.days = 7,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceTrendParams &&
          productId == other.productId &&
          area == other.area &&
          days == other.days;

  @override
  int get hashCode => productId.hashCode ^ area.hashCode ^ days.hashCode;
}

class RecommendedPriceParams {
  final String productId;
  final String area;
  final double marginPct;

  const RecommendedPriceParams({
    required this.productId,
    required this.area,
    this.marginPct = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendedPriceParams &&
          productId == other.productId &&
          area == other.area &&
          marginPct == other.marginPct;

  @override
  int get hashCode => productId.hashCode ^ area.hashCode ^ marginPct.hashCode;
}

// ── Current prices (typed, for pedagang screens) ─────────────────────────────

final currentPricesProvider =
    FutureProvider.family<List<AggregatedPrice>, String>((ref, area) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getCurrentPrices(area);
});

// ── Price trend ──────────────────────────────────────────────────────────────

final priceTrendProvider =
    FutureProvider.family<PriceTrend, PriceTrendParams>((ref, params) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getPriceTrend(
    params.productId,
    params.area,
    days: params.days,
  );
});

// ── Recommended price ────────────────────────────────────────────────────────

final recommendedPriceProvider =
    FutureProvider.family<RecommendedPrice, RecommendedPriceParams>(
        (ref, params) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getRecommendedPrice(
    params.productId,
    params.area,
    marginPct: params.marginPct,
  );
});

// ── Products (typed) ─────────────────────────────────────────────────────────

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getProducts();
});

final productCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getCategories();
});

// ── Top movers (typed) ───────────────────────────────────────────────────────

final topMoversProvider =
    FutureProvider.family<List<AggregatedPrice>, String>((ref, area) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getTopMovers(area);
});

// ── Area stats ───────────────────────────────────────────────────────────────

final areaStatsProvider =
    FutureProvider.family<AreaPriceStats, String>((ref, area) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getAreaStats(area);
});

// ── UI State ─────────────────────────────────────────────────────────────────

final selectedAreaProvider = StateProvider<String>((ref) => 'jakarta_selatan');

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ── Legacy providers (backward compat for pelanggan screens) ─────────────────

final pricesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getPrices();
});

final priceComparisonProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, productId) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getPriceComparison(productId);
});

final priceTopMoversProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getTopMovers('jakarta_selatan').then(
        (list) => list.map((e) => e.toJson()).toList(),
      );
});

final legacyProductsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(priceRepositoryProvider);
  return await repo.getProductsRaw();
});

// ── Price Alerts (AsyncNotifier for mutation support) ─────────────────────────

class PriceAlertsNotifier extends AsyncNotifier<List<PriceAlert>> {
  @override
  Future<List<PriceAlert>> build() async {
    final repo = ref.read(priceRepositoryProvider);
    return await repo.getMyAlerts();
  }

  Future<void> createAlert(Map<String, dynamic> data) async {
    final repo = ref.read(priceRepositoryProvider);
    final request = CreateAlertRequest(
      productId: data['product_id']?.toString() ?? '',
      area: data['area']?.toString() ?? 'jakarta_selatan',
      threshold: (data['threshold_percent'] as num?)?.toDouble() ??
          (data['threshold'] as num?)?.toDouble() ??
          0,
      direction: data['direction']?.toString() ?? 'up',
    );
    await repo.createAlert(request);
    ref.invalidateSelf();
  }

  Future<void> deleteAlert(String alertId) async {
    final repo = ref.read(priceRepositoryProvider);
    await repo.deleteAlert(alertId);
    ref.invalidateSelf();
  }

  Future<void> toggleAlert(String alertId, bool isActive) async {
    final repo = ref.read(priceRepositoryProvider);
    await repo.toggleAlert(alertId, isActive);
    ref.invalidateSelf();
  }
}

final priceAlertsProvider =
    AsyncNotifierProvider<PriceAlertsNotifier, List<PriceAlert>>(
  PriceAlertsNotifier.new,
);
