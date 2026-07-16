import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/features/pelanggan/data/pelanggan_repository.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';

// ── Repository ───────────────────────────────────────────────────────────

final pelangganRepositoryProvider = Provider<PelangganRepository>((ref) {
  return PelangganRepository(ApiClient().dio);
});

// ── Merchant Search ──────────────────────────────────────────────────────

final searchMerchantsProvider =
    FutureProvider.family<List<MerchantWithPackages>, MerchantSearchParams>(
        (ref, params) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.searchMerchants(
    area: params.area,
    query: params.query,
    lat: params.lat,
    lng: params.lng,
    radiusKm: params.radiusKm,
    minRating: params.minRating,
    hasPackages: params.hasPackages,
  );
});

final merchantDetailProvider =
    FutureProvider.family<MerchantDetail, String>((ref, id) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.getMerchantDetail(id);
});

final merchantPackagesProvider =
    FutureProvider.family<List<SubscriptionPackage>, String>(
        (ref, merchantId) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.getMerchantPackages(merchantId);
});

// ── Order History ────────────────────────────────────────────────────────

final pelangganOrderHistoryProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.getOrderHistory();
});

final pelangganOrderDetailProvider =
    FutureProvider.family<Order, String>((ref, orderId) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.getOrderDetail(orderId);
});

// ── Addresses ────────────────────────────────────────────────────────────

final addressesProvider = FutureProvider<List<DeliveryAddress>>((ref) async {
  final repo = ref.read(pelangganRepositoryProvider);
  return await repo.getAddresses();
});

// ── UI State ─────────────────────────────────────────────────────────────

final merchantSearchQueryProvider = StateProvider<String>((ref) => '');

final merchantFilterProvider =
    StateProvider<MerchantSearchParams>((ref) => const MerchantSearchParams());

final selectedAddressProvider = StateProvider<DeliveryAddress?>((ref) => null);
