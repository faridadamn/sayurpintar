import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';

// ── Pelanggan-specific Data Models ───────────────────────────────────────

class MerchantWithPackages {
  final String id;
  final String name;
  final String? avatarUrl;
  final double rating;
  final int totalOrders;
  final double distanceKm;
  final int packageCount;
  final List<SubscriptionPackage> packages;

  MerchantWithPackages({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.rating,
    required this.totalOrders,
    required this.distanceKm,
    required this.packageCount,
    required this.packages,
  });

  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  factory MerchantWithPackages.fromJson(Map<String, dynamic> json) {
    return MerchantWithPackages(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      packageCount: json['package_count'] ?? 0,
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) =>
                  SubscriptionPackage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'rating': rating,
      'total_orders': totalOrders,
      'distance_km': distanceKm,
      'package_count': packageCount,
      'packages': packages.map((e) => e.toJson()).toList(),
    };
  }
}

class MerchantDetail {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? address;
  final double rating;
  final int totalOrders;
  final int subscriberCount;
  final List<SubscriptionPackage> packages;
  final List<MerchantProduct> topProducts;
  final bool isVerified;
  final String? phone;
  final String? description;

  MerchantDetail({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.address,
    required this.rating,
    required this.totalOrders,
    required this.subscriberCount,
    required this.packages,
    required this.topProducts,
    required this.isVerified,
    this.phone,
    this.description,
  });

  factory MerchantDetail.fromJson(Map<String, dynamic> json) {
    return MerchantDetail(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      address: json['address'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      subscriberCount: json['subscriber_count'] ?? 0,
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) =>
                  SubscriptionPackage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topProducts: (json['top_products'] as List<dynamic>?)
              ?.map((e) => MerchantProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isVerified: json['is_verified'] ?? false,
      phone: json['phone'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'address': address,
      'rating': rating,
      'total_orders': totalOrders,
      'subscriber_count': subscriberCount,
      'packages': packages.map((e) => e.toJson()).toList(),
      'top_products': topProducts.map((e) => e.toJson()).toList(),
      'is_verified': isVerified,
      'phone': phone,
      'description': description,
    };
  }
}

class MerchantProduct {
  final String id;
  final String name;
  final String? category;
  final double price;
  final String unit;
  final String? imageUrl;
  final int orderCount;

  MerchantProduct({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    required this.unit,
    this.imageUrl,
    required this.orderCount,
  });

  String get formattedPrice {
    final str = price.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return '$buf/$unit';
  }

  factory MerchantProduct.fromJson(Map<String, dynamic> json) {
    return MerchantProduct(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'kg',
      imageUrl: json['image_url'],
      orderCount: json['order_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'unit': unit,
      'image_url': imageUrl,
      'order_count': orderCount,
    };
  }
}

class DeliveryAddress {
  final String id;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  DeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    this.notes,
    required this.isDefault,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] ?? '',
      label: json['label'] ?? 'Lainnya',
      address: json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'],
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'is_default': isDefault,
    };
  }
}

class MerchantSearchParams {
  final String? area;
  final String? query;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final double? minRating;
  final bool? hasPackages;

  const MerchantSearchParams({
    this.area,
    this.query,
    this.lat,
    this.lng,
    this.radiusKm,
    this.minRating,
    this.hasPackages,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (area != null) params['area'] = area;
    if (query != null && query!.isNotEmpty) params['q'] = query;
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    if (radiusKm != null) params['radius'] = radiusKm;
    if (minRating != null) params['min_rating'] = minRating;
    if (hasPackages != null) params['has_packages'] = hasPackages;
    return params;
  }
}

// ── Pelanggan Repository ─────────────────────────────────────────────────

class PelangganRepository {
  final Dio _dio;

  PelangganRepository(this._dio);

  // ── Merchant discovery ──────────────────────────────────────────────────

  Future<List<MerchantWithPackages>> searchMerchants({
    String? area,
    String? query,
    double? lat,
    double? lng,
    double? radiusKm,
    double? minRating,
    bool? hasPackages,
  }) async {
    final params = MerchantSearchParams(
      area: area,
      query: query,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      minRating: minRating,
      hasPackages: hasPackages,
    ).toQueryParams();

    final response = await _dio.get(
      '${ApiEndpoints.base}/merchants',
      queryParameters: params,
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => MerchantWithPackages.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MerchantDetail> getMerchantDetail(String merchantId) async {
    final response =
        await _dio.get('${ApiEndpoints.base}/merchants/$merchantId');
    return MerchantDetail.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<SubscriptionPackage>> getMerchantPackages(
      String merchantId) async {
    final response = await _dio.get(
      '${ApiEndpoints.base}/merchants/$merchantId/packages',
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Order history ───────────────────────────────────────────────────────

  Future<List<Order>> getOrderHistory({
    int limit = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (status != null) params['status'] = status;

    final response = await _dio.get(
      ApiEndpoints.orders,
      queryParameters: params,
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrderDetail(String orderId) async {
    final response = await _dio.get('${ApiEndpoints.orders}/$orderId');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> rateOrder(String orderId, int rating, String? comment) async {
    await _dio.post(
      '${ApiEndpoints.orders}/$orderId/rate',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  Future<void> reorder(String orderId) async {
    await _dio.post('${ApiEndpoints.orders}/$orderId/reorder');
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _dio.post(
      '${ApiEndpoints.orders}/$orderId/cancel',
      data: {'reason': reason},
    );
  }

  // ── Addresses ───────────────────────────────────────────────────────────

  Future<List<DeliveryAddress>> getAddresses() async {
    final response = await _dio.get('${ApiEndpoints.base}/addresses');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => DeliveryAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryAddress> addAddress(DeliveryAddress address) async {
    final response = await _dio.post(
      '${ApiEndpoints.base}/addresses',
      data: address.toJson(),
    );
    return DeliveryAddress.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<DeliveryAddress> updateAddress(
      String id, DeliveryAddress address) async {
    final response = await _dio.put(
      '${ApiEndpoints.base}/addresses/$id',
      data: address.toJson(),
    );
    return DeliveryAddress.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete('${ApiEndpoints.base}/addresses/$id');
  }

  Future<void> setDefaultAddress(String id) async {
    await _dio.post('${ApiEndpoints.base}/addresses/$id/default');
  }
}
