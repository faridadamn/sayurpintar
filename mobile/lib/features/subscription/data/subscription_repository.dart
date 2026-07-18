import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class SubscriptionPackage {
  final String id;
  final String pedagangId;
  final String name;
  final String? description;
  final List<PackageItem> items;
  final double price;
  final String frequency;
  final List<int> deliveryDays;
  final int maxSubscribers;
  final bool isActive;
  final int? subscriberCount;

  SubscriptionPackage({
    required this.id,
    required this.pedagangId,
    required this.name,
    this.description,
    required this.items,
    required this.price,
    required this.frequency,
    required this.deliveryDays,
    required this.maxSubscribers,
    required this.isActive,
    this.subscriberCount,
  });

  String get deliveryDaysText {
    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return deliveryDays.map((d) => dayNames[d - 1]).join(', ');
  }

  String get frequencyText {
    switch (frequency) {
      case 'daily':
        return 'Harian';
      case 'weekly':
        return 'Mingguan';
      case 'twice_weekly':
        return '2x Seminggu';
      default:
        return frequency;
    }
  }

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackage(
      id: json['id'] ?? '',
      pedagangId: json['pedagang_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PackageItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] ?? 'weekly',
      deliveryDays: (json['delivery_days'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      maxSubscribers: json['max_subscribers'] ?? 0,
      isActive: json['is_active'] ?? true,
      subscriberCount: json['subscriber_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedagang_id': pedagangId,
      'name': name,
      'description': description,
      'items': items.map((e) => e.toJson()).toList(),
      'price': price,
      'frequency': frequency,
      'delivery_days': deliveryDays,
      'max_subscribers': maxSubscribers,
      'is_active': isActive,
      'subscriber_count': subscriberCount,
    };
  }
}

class PackageItem {
  final String productId;
  final String name;
  final double qty;
  final String unit;
  final double pricePerUnit;

  PackageItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.pricePerUnit,
  });

  double get subtotal => qty * pricePerUnit;

  factory PackageItem.fromJson(Map<String, dynamic> json) {
    return PackageItem(
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'kg',
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'qty': qty,
      'unit': unit,
      'price_per_unit': pricePerUnit,
    };
  }
}

class Subscription {
  final String id;
  final String packageId;
  final String pedagangId;
  final String pelangganId;
  final String paymentMethod;
  final String status;
  final String startDate;
  final String? endDate;
  final String? packageName;
  final String? pelangganName;
  final String? pelangganPhone;
  final String? nextDelivery;

  Subscription({
    required this.id,
    required this.packageId,
    required this.pedagangId,
    required this.pelangganId,
    required this.paymentMethod,
    required this.status,
    required this.startDate,
    this.endDate,
    this.packageName,
    this.pelangganName,
    this.pelangganPhone,
    this.nextDelivery,
  });

  String get statusText {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'paused':
        return 'Dijeda';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return paymentMethod;
    }
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? '',
      packageId: json['package_id'] ?? '',
      pedagangId: json['pedagang_id'] ?? '',
      pelangganId: json['pelanggan_id'] ?? '',
      paymentMethod: json['payment_method'] ?? 'cash',
      status: json['status'] ?? 'active',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'],
      packageName: json['package_name'],
      pelangganName: json['pelanggan_name'],
      pelangganPhone: json['pelanggan_phone'],
      nextDelivery: json['next_delivery'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'package_id': packageId,
      'pedagang_id': pedagangId,
      'pelanggan_id': pelangganId,
      'payment_method': paymentMethod,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'package_name': packageName,
      'pelanggan_name': pelangganName,
      'pelanggan_phone': pelangganPhone,
      'next_delivery': nextDelivery,
    };
  }
}

class SubscriptionDetail extends Subscription {
  final SubscriptionPackage? package;
  final int deliveryCount;
  final double totalSpent;
  final List<SubscriptionModification> recentModifications;

  SubscriptionDetail({
    required super.id,
    required super.packageId,
    required super.pedagangId,
    required super.pelangganId,
    required super.paymentMethod,
    required super.status,
    required super.startDate,
    super.endDate,
    super.packageName,
    super.pelangganName,
    super.pelangganPhone,
    super.nextDelivery,
    this.package,
    required this.deliveryCount,
    required this.totalSpent,
    required this.recentModifications,
  });

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetail(
      id: json['id'] ?? '',
      packageId: json['package_id'] ?? '',
      pedagangId: json['pedagang_id'] ?? '',
      pelangganId: json['pelanggan_id'] ?? '',
      paymentMethod: json['payment_method'] ?? 'cash',
      status: json['status'] ?? 'active',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'],
      packageName: json['package_name'],
      pelangganName: json['pelanggan_name'],
      pelangganPhone: json['pelanggan_phone'],
      nextDelivery: json['next_delivery'],
      package: json['package'] != null
          ? SubscriptionPackage.fromJson(json['package'] as Map<String, dynamic>)
          : null,
      deliveryCount: json['delivery_count'] ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      recentModifications: (json['recent_modifications'] as List<dynamic>?)
              ?.map((e) =>
                  SubscriptionModification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map.addAll({
      'package': package?.toJson(),
      'delivery_count': deliveryCount,
      'total_spent': totalSpent,
      'recent_modifications':
          recentModifications.map((e) => e.toJson()).toList(),
    });
    return map;
  }
}

class Order {
  final String id;
  final String? subscriptionId;
  final String pedagangId;
  final String pelangganId;
  final List<OrderItem> items;
  final double totalPrice;
  final String status;
  final String deliveryDate;
  final String? deliveryNotes;
  final int? rating;
  final String? ratingComment;
  final String paymentMethod;
  final String paymentStatus;
  final String? pelangganName;
  final String? pelangganPhone;
  final String? pelangganAddress;

  Order({
    required this.id,
    this.subscriptionId,
    required this.pedagangId,
    required this.pelangganId,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.deliveryDate,
    this.deliveryNotes,
    this.rating,
    this.ratingComment,
    required this.paymentMethod,
    required this.paymentStatus,
    this.pelangganName,
    this.pelangganPhone,
    this.pelangganAddress,
  });

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'preparing':
        return 'Disiapkan';
      case 'delivering':
        return 'Diantar';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Batal';
      default:
        return status;
    }
  }

  String get paymentStatusText {
    switch (paymentStatus) {
      case 'paid':
        return 'Lunas';
      case 'unpaid':
        return 'Belum Bayar';
      case 'partial':
        return 'Sebagian';
      default:
        return paymentStatus;
    }
  }

  bool get isRated => rating != null;

  String get paymentMethodText {
    switch (paymentMethod) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return paymentMethod;
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      subscriptionId: json['subscription_id'],
      pedagangId: json['pedagang_id'] ?? '',
      pelangganId: json['pelanggan_id'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'pending',
      deliveryDate: json['delivery_date'] ?? '',
      deliveryNotes: json['delivery_notes'],
      rating: json['rating'],
      ratingComment: json['rating_comment'],
      paymentMethod: json['payment_method'] ?? 'cash',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      pelangganName: json['pelanggan_name'],
      pelangganPhone: json['pelanggan_phone'],
      pelangganAddress: json['pelanggan_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'pedagang_id': pedagangId,
      'pelanggan_id': pelangganId,
      'items': items.map((e) => e.toJson()).toList(),
      'total_price': totalPrice,
      'status': status,
      'delivery_date': deliveryDate,
      'delivery_notes': deliveryNotes,
      'rating': rating,
      'rating_comment': ratingComment,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'pelanggan_name': pelangganName,
      'pelanggan_phone': pelangganPhone,
      'pelanggan_address': pelangganAddress,
    };
  }
}

class OrderItem {
  final String productId;
  final String name;
  final double qty;
  final String unit;
  final double price;
  final double subtotal;

  OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'kg',
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

class OrderSummary {
  final int totalOrders;
  final int delivered;
  final int cancelled;
  final int pending;
  final double totalRevenue;
  final double paidAmount;
  final double unpaidAmount;

  OrderSummary({
    required this.totalOrders,
    required this.delivered,
    required this.cancelled,
    required this.pending,
    required this.totalRevenue,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      totalOrders: json['total_orders'] ?? 0,
      delivered: json['delivered'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      pending: json['pending'] ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      unpaidAmount: (json['unpaid_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_orders': totalOrders,
      'delivered': delivered,
      'cancelled': cancelled,
      'pending': pending,
      'total_revenue': totalRevenue,
      'paid_amount': paidAmount,
      'unpaid_amount': unpaidAmount,
    };
  }
}

class SubscriberStats {
  final int totalSubscribers;
  final int activeSubscribers;
  final int pausedSubscribers;
  final double monthlyRevenue;

  SubscriberStats({
    required this.totalSubscribers,
    required this.activeSubscribers,
    required this.pausedSubscribers,
    required this.monthlyRevenue,
  });

  factory SubscriberStats.fromJson(Map<String, dynamic> json) {
    return SubscriberStats(
      totalSubscribers: json['total_subscribers'] ?? 0,
      activeSubscribers: json['active_subscribers'] ?? 0,
      pausedSubscribers: json['paused_subscribers'] ?? 0,
      monthlyRevenue: (json['monthly_revenue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_subscribers': totalSubscribers,
      'active_subscribers': activeSubscribers,
      'paused_subscribers': pausedSubscribers,
      'monthly_revenue': monthlyRevenue,
    };
  }
}

class SubscriptionModification {
  final String id;
  final String subscriptionId;
  final String deliveryDate;
  final List<PackageItem>? items;
  final bool skipDelivery;
  final String? reason;

  SubscriptionModification({
    required this.id,
    required this.subscriptionId,
    required this.deliveryDate,
    this.items,
    required this.skipDelivery,
    this.reason,
  });

  factory SubscriptionModification.fromJson(Map<String, dynamic> json) {
    return SubscriptionModification(
      id: json['id'] ?? '',
      subscriptionId: json['subscription_id'] ?? '',
      deliveryDate: json['delivery_date'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => PackageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      skipDelivery: json['skip_delivery'] ?? false,
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'delivery_date': deliveryDate,
      'items': items?.map((e) => e.toJson()).toList(),
      'skip_delivery': skipDelivery,
      'reason': reason,
    };
  }
}

class CreatePackageRequest {
  final String name;
  final String? description;
  final List<PackageItem> items;
  final double price;
  final String frequency;
  final List<int> deliveryDays;
  final int maxSubscribers;

  CreatePackageRequest({
    required this.name,
    this.description,
    required this.items,
    required this.price,
    required this.frequency,
    required this.deliveryDays,
    required this.maxSubscribers,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'items': items.map((e) => e.toJson()).toList(),
      'price': price,
      'frequency': frequency,
      'delivery_days': deliveryDays,
      'max_subscribers': maxSubscribers,
    };
  }
}

class UpdatePackageRequest {
  final String? name;
  final String? description;
  final List<PackageItem>? items;
  final double? price;
  final bool? isActive;

  UpdatePackageRequest({
    this.name,
    this.description,
    this.items,
    this.price,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (items != null) map['items'] = items!.map((e) => e.toJson()).toList();
    if (price != null) map['price'] = price;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}

// ── Repository ───────────────────────────────────────────────────────────────

class SubscriptionRepository {
  final Dio _dio;

  SubscriptionRepository(this._dio);

  // ── Package CRUD ─────────────────────────────────────────────────────────

  Future<SubscriptionPackage> createPackage(
      CreatePackageRequest request) async {
    final response =
        await _dio.post(ApiEndpoints.packages, data: request.toJson());
    return SubscriptionPackage.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<SubscriptionPackage>> getMyPackages(
      {bool activeOnly = true}) async {
    final response = await _dio.get(
      ApiEndpoints.packages,
      queryParameters: {'active_only': activeOnly},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionPackage> getPackageDetail(String id) async {
    final response = await _dio.get('${ApiEndpoints.packages}/$id');
    return SubscriptionPackage.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<SubscriptionPackage> updatePackage(
      String id, UpdatePackageRequest request) async {
    final response =
        await _dio.patch('${ApiEndpoints.packages}/$id', data: request.toJson());
    return SubscriptionPackage.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deletePackage(String id) async {
    await _dio.delete('${ApiEndpoints.packages}/$id');
  }

  // ── Subscription management (pedagang view) ─────────────────────────────

  Future<List<Subscription>> getSubscribers({String status = 'active'}) async {
    final response = await _dio.get(
      '${ApiEndpoints.packages}/subscribers',
      queryParameters: {'status': status},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionDetail> getSubscriptionDetail(String id) async {
    final response =
        await _dio.get('${ApiEndpoints.packages}/subscribers/$id');
    return SubscriptionDetail.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<SubscriberStats> getSubscriberStats() async {
    final response =
        await _dio.get('${ApiEndpoints.packages}/subscribers/stats');
    return SubscriberStats.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  // ── Orders ──────────────────────────────────────────────────────────────

  Future<List<Order>> getTodayOrders() async {
    final response = await _dio.get(ApiEndpoints.todayOrders);
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> getOrderDetail(String id) async {
    final response = await _dio.get('${ApiEndpoints.orders}/$id');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _dio
        .patch('${ApiEndpoints.orders}/$id/status', data: {'status': status});
  }

  Future<void> markOrderDelivered(String id) async {
    await _dio.post('${ApiEndpoints.orders}/$id/deliver');
  }

  Future<void> cancelOrder(String id, String reason) async {
    await _dio
        .post('${ApiEndpoints.orders}/$id/cancel', data: {'reason': reason});
  }

  Future<OrderSummary> getOrderSummary(String date) async {
    final response = await _dio.get(
      '${ApiEndpoints.orders}/summary',
      queryParameters: {'date': date},
    );
    return OrderSummary.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<Subscription>> getMyActiveSubscriptions() =>
      _getMySubscriptions('active');

  Future<List<Subscription>> getMyPausedSubscriptions() =>
      _getMySubscriptions('paused');

  Future<List<Subscription>> _getMySubscriptions(String status) async {
    final response = await _dio.get(
      ApiEndpoints.mySubscriptions,
      queryParameters: {'status': status},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionDetail> getMySubscriptionDetail(String id) async {
    final response = await _dio.get('${ApiEndpoints.mySubscriptions}/$id');
    return SubscriptionDetail.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<SubscriptionPackage>> getAvailablePackages({String? query}) async {
    final response = await _dio.get(
      ApiEndpoints.packages,
      queryParameters: {
        'active_only': true,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Subscription> subscribeToPackage({
    required String packageId,
    required String paymentMethod,
    required String paymentFrequency,
  }) async {
    final response = await _dio.post(ApiEndpoints.subscribe, data: {
      'package_id': packageId,
      'payment_method': paymentMethod,
      'payment_frequency': paymentFrequency,
    });
    return Subscription.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<Order>> getOrderHistory({String? status}) async {
    final response = await _dio.get(
      ApiEndpoints.orders,
      queryParameters: {if (status != null) 'status': status},
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String subscriptionId) async {
    final response = await _dio.get(
        '${ApiEndpoints.mySubscriptions}/$subscriptionId/payments');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> pauseSubscription(String id, {String? reason}) async {
    await _dio.post('${ApiEndpoints.mySubscriptions}/$id/pause',
        data: {if (reason != null) 'reason': reason});
  }

  Future<void> resumeSubscription(String id) async {
    await _dio.post('${ApiEndpoints.mySubscriptions}/$id/resume');
  }

  Future<void> pelangganCancelSubscription(String id, {String? reason}) async {
    await _dio.post('${ApiEndpoints.mySubscriptions}/$id/cancel',
        data: {if (reason != null) 'reason': reason});
  }

  Future<void> skipDelivery(String id, String deliveryDate) async {
    await _dio.post('${ApiEndpoints.mySubscriptions}/$id/skip',
        data: {'delivery_date': deliveryDate});
  }

  Future<void> modifyDelivery({
    required String subscriptionId,
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required bool skip,
  }) async {
    await _dio.patch('${ApiEndpoints.mySubscriptions}/$subscriptionId/delivery',
        data: {
          'delivery_date': deliveryDate,
          'items': items,
          'skip_delivery': skip,
        });
  }

  Future<void> rateDelivery({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    await _dio.post('${ApiEndpoints.orders}/$orderId/rating', data: {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }
}
