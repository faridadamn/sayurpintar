import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';

/// Subscription API used by both pedagang and pelanggan screens.
///
/// This subclass keeps the existing repository contract intact while exposing
/// the customer operations that are already registered by the backend.
class AppSubscriptionRepository extends SubscriptionRepository {
  final Dio _client;

  AppSubscriptionRepository(this._client) : super(_client);

  List<dynamic> _listData(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      return data is List ? data : const [];
    }
    return body is List ? body : const [];
  }

  Map<String, dynamic> _mapData(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return const {};
  }

  Future<List<Subscription>> getMyActiveSubscriptions() async {
    final response = await _client.get('${ApiEndpoints.base}/subscriptions/active');
    return _listData(response)
        .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
        .where((subscription) => subscription.status == 'active')
        .toList();
  }

  Future<List<Subscription>> getMyPausedSubscriptions() async {
    final response = await _client.get('${ApiEndpoints.base}/subscriptions/active');
    return _listData(response)
        .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
        .where((subscription) => subscription.status == 'paused')
        .toList();
  }

  Future<SubscriptionDetail> getMySubscriptionDetail(String id) async {
    final response =
        await _client.get('${ApiEndpoints.base}/subscriptions/$id/detail');
    return SubscriptionDetail.fromJson(_mapData(response));
  }

  Future<List<SubscriptionPackage>> getAvailablePackages({String? query}) async {
    final response = await _client.get(
      '${ApiEndpoints.base}/subscriptions/packages',
      queryParameters: {
        'active_only': true,
        if (query != null && query.isNotEmpty) 'pedagang_id': query,
      },
    );
    return _listData(response)
        .map((item) =>
            SubscriptionPackage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Subscription> subscribeToPackage({
    required String packageId,
    required String paymentMethod,
    required String paymentFrequency,
  }) async {
    final response = await _client.post(
      '${ApiEndpoints.base}/subscriptions/subscribe',
      data: {
        'package_id': packageId,
        'payment_method': paymentMethod,
        'payment_frequency': paymentFrequency,
      },
    );
    return Subscription.fromJson(_mapData(response));
  }

  Future<void> pauseSubscription(String id, {String? reason}) async {
    await _client.put(
      '${ApiEndpoints.base}/subscriptions/$id/pause',
      data: {'reason': reason ?? ''},
    );
  }

  Future<void> resumeSubscription(String id) async {
    await _client.put('${ApiEndpoints.base}/subscriptions/$id/resume');
  }

  Future<void> pelangganCancelSubscription(String id, {String? reason}) async {
    await _client.delete(
      '${ApiEndpoints.base}/subscriptions/$id',
      data: {'reason': reason ?? ''},
    );
  }

  Future<void> modifyDelivery({
    required String subscriptionId,
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required bool skip,
  }) async {
    await _client.post(
      '${ApiEndpoints.base}/subscriptions/$subscriptionId/modify',
      data: {
        'delivery_date': deliveryDate,
        'items': items,
        'skip_delivery': skip,
      },
    );
  }

  Future<void> skipDelivery(String subscriptionId, String deliveryDate) async {
    await modifyDelivery(
      subscriptionId: subscriptionId,
      deliveryDate: deliveryDate,
      items: const [],
      skip: true,
    );
  }

  Future<List<Order>> getOrderHistory({String? status}) async {
    final response = await _client.get(
      '${ApiEndpoints.orders}/my',
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return _listData(response)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> rateDelivery({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    await _client.post(
      '${ApiEndpoints.orders}/$orderId/rate',
      data: {'rating': rating, 'comment': comment ?? ''},
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(
      String subscriptionId) async {
    final response = await _client.get(
      ApiEndpoints.transactions,
      queryParameters: {'subscription_id': subscriptionId},
    );
    return _listData(response)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
