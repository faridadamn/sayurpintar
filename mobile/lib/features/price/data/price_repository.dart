import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class PriceSubmission {
  final String id;
  final String productId;
  final String productName;
  final String area;
  final String market;
  final double price;
  final String unit;
  final String date;

  PriceSubmission({
    required this.id,
    required this.productId,
    required this.productName,
    required this.area,
    required this.market,
    required this.price,
    required this.unit,
    required this.date,
  });

  factory PriceSubmission.fromJson(Map<String, dynamic> json) {
    return PriceSubmission(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      market: json['market']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'kg',
      date: json['date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'area': area,
        'market': market,
        'price': price,
        'unit': unit,
        'date': date,
      };
}

class AggregatedPrice {
  final String productId;
  final String productName;
  final String area;
  final double medianPrice;
  final double minPrice;
  final double maxPrice;
  final int sampleSize;
  final String unit;
  final String trend;
  final double changePct;

  AggregatedPrice({
    required this.productId,
    required this.productName,
    required this.area,
    required this.medianPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.sampleSize,
    required this.unit,
    required this.trend,
    required this.changePct,
  });

  factory AggregatedPrice.fromJson(Map<String, dynamic> json) {
    return AggregatedPrice(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      medianPrice: (json['median_price'] as num?)?.toDouble() ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['max_price'] as num?)?.toDouble() ?? 0,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString() ?? 'kg',
      trend: json['trend']?.toString() ?? 'stable',
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'area': area,
        'median_price': medianPrice,
        'min_price': minPrice,
        'max_price': maxPrice,
        'sample_size': sampleSize,
        'unit': unit,
        'trend': trend,
        'change_pct': changePct,
      };
}

class TrendDataPoint {
  final String date;
  final double price;
  final int samples;

  TrendDataPoint({
    required this.date,
    required this.price,
    required this.samples,
  });

  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      date: json['date']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      samples: (json['samples'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'price': price,
        'samples': samples,
      };
}

class PriceTrend {
  final String productId;
  final String productName;
  final String area;
  final List<TrendDataPoint> dataPoints;

  PriceTrend({
    required this.productId,
    required this.productName,
    required this.area,
    required this.dataPoints,
  });

  factory PriceTrend.fromJson(Map<String, dynamic> json) {
    return PriceTrend(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      dataPoints: (json['data_points'] as List<dynamic>?)
              ?.map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'area': area,
        'data_points': dataPoints.map((e) => e.toJson()).toList(),
      };
}

class RecommendedPrice {
  final String productId;
  final String productName;
  final double marketPrice;
  final double suggestedPrice;
  final double margin;
  final String unit;

  RecommendedPrice({
    required this.productId,
    required this.productName,
    required this.marketPrice,
    required this.suggestedPrice,
    required this.margin,
    required this.unit,
  });

  factory RecommendedPrice.fromJson(Map<String, dynamic> json) {
    return RecommendedPrice(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      marketPrice: (json['market_price'] as num?)?.toDouble() ?? 0,
      suggestedPrice: (json['suggested_price'] as num?)?.toDouble() ?? 0,
      margin: (json['margin'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'kg',
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'market_price': marketPrice,
        'suggested_price': suggestedPrice,
        'margin': margin,
        'unit': unit,
      };
}

class PriceAlert {
  final String id;
  final String productId;
  final String productName;
  final String area;
  final double threshold;
  final String direction;
  final bool isActive;

  PriceAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.area,
    required this.threshold,
    required this.direction,
    required this.isActive,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      direction: json['direction']?.toString() ?? 'up',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'area': area,
        'threshold': threshold,
        'direction': direction,
        'is_active': isActive,
      };
}

class Product {
  final String id;
  final String name;
  final String category;
  final String defaultUnit;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultUnit,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      defaultUnit: json['default_unit']?.toString() ?? 'kg',
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'default_unit': defaultUnit,
        'image_url': imageUrl,
      };
}

class AreaPriceStats {
  final String area;
  final int totalProducts;
  final int avgSubmissionsPerDay;
  final String mostSubmittedProduct;

  AreaPriceStats({
    required this.area,
    required this.totalProducts,
    required this.avgSubmissionsPerDay,
    required this.mostSubmittedProduct,
  });

  factory AreaPriceStats.fromJson(Map<String, dynamic> json) {
    return AreaPriceStats(
      area: json['area']?.toString() ?? '',
      totalProducts: (json['total_products'] as num?)?.toInt() ?? 0,
      avgSubmissionsPerDay:
          (json['avg_submissions_per_day'] as num?)?.toInt() ?? 0,
      mostSubmittedProduct: json['most_submitted_product']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'area': area,
        'total_products': totalProducts,
        'avg_submissions_per_day': avgSubmissionsPerDay,
        'most_submitted_product': mostSubmittedProduct,
      };
}

class SubmitPriceRequest {
  final String productId;
  final double price;
  final String market;
  final String area;

  SubmitPriceRequest({
    required this.productId,
    required this.price,
    required this.market,
    required this.area,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'price': price,
        'market': market,
        'area': area,
      };
}

class CreateAlertRequest {
  final String productId;
  final String area;
  final double threshold;
  final String direction;

  CreateAlertRequest({
    required this.productId,
    required this.area,
    required this.threshold,
    required this.direction,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'area': area,
        'threshold': threshold,
        'direction': direction,
      };
}

// ── Repository ───────────────────────────────────────────────────────────────

class PriceRepository {
  final Dio _dio = ApiClient().dio;

  // ── Submit price ─────────────────────────────────────────────────────────

  Future<PriceSubmission> submitPrice(SubmitPriceRequest request) async {
    final response = await _dio.post(
      ApiEndpoints.prices,
      data: request.toJson(),
    );
    return PriceSubmission.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  // ── Current market prices ────────────────────────────────────────────────

  Future<List<AggregatedPrice>> getCurrentPrices(String area) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/current',
      queryParameters: {'area': area},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AggregatedPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Price trend ──────────────────────────────────────────────────────────

  Future<PriceTrend> getPriceTrend(
    String productId,
    String area, {
    int days = 7,
  }) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/trend',
      queryParameters: {
        'product_id': productId,
        'area': area,
        'days': days,
      },
    );
    return PriceTrend.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  // ── Recommended selling price ────────────────────────────────────────────

  Future<RecommendedPrice> getRecommendedPrice(
    String productId,
    String area, {
    double marginPct = 30,
  }) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/recommended',
      queryParameters: {
        'product_id': productId,
        'area': area,
        'margin_pct': marginPct,
      },
    );
    return RecommendedPrice.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  // ── Alerts ───────────────────────────────────────────────────────────────

  Future<PriceAlert> createAlert(CreateAlertRequest request) async {
    final response = await _dio.post(
      '${ApiEndpoints.prices}/alerts',
      data: request.toJson(),
    );
    return PriceAlert.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<List<PriceAlert>> getMyAlerts() async {
    final response = await _dio.get('${ApiEndpoints.prices}/alerts');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => PriceAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteAlert(String id) async {
    await _dio.delete('${ApiEndpoints.prices}/alerts/$id');
  }

  // ── Products ─────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({String? category, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (category != null) queryParams['category'] = category;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get(
      ApiEndpoints.products,
      queryParameters: queryParams,
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getCategories() async {
    final response = await _dio.get('${ApiEndpoints.products}/categories');
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  // ── Analytics ────────────────────────────────────────────────────────────

  Future<List<AggregatedPrice>> getTopMovers(String area) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/top-movers',
      queryParameters: {'area': area},
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AggregatedPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AreaPriceStats> getAreaStats(String area) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/area-stats',
      queryParameters: {'area': area},
    );
    return AreaPriceStats.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  // ── Legacy untyped methods (backward compat for pelanggan screens) ──────

  Future<List<dynamic>> getPrices() async {
    final response = await _dio.get(ApiEndpoints.prices);
    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getProductsRaw() async {
    final response = await _dio.get(ApiEndpoints.products);
    return response.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> getPriceComparison(String productId) async {
    final response = await _dio.get(
      '${ApiEndpoints.prices}/compare/$productId',
    );
    return response.data['data'] ?? {};
  }

  Future<List<dynamic>> getAlertsRaw() async {
    final response = await _dio.get('${ApiEndpoints.prices}/alerts');
    return response.data['data'] ?? [];
  }

  Future<void> createAlertRaw(Map<String, dynamic> data) async {
    await _dio.post('${ApiEndpoints.prices}/alerts', data: data);
  }

  Future<void> deleteAlertRaw(String alertId) async {
    await _dio.delete('${ApiEndpoints.prices}/alerts/$alertId');
  }

  Future<void> toggleAlert(String alertId, bool isActive) async {
    await _dio.patch(
      '${ApiEndpoints.prices}/alerts/$alertId',
      data: {'is_active': isActive},
    );
  }
}
