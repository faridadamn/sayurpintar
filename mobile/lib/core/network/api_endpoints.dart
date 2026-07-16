class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String webSocketBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );

  // ── Auth ─────────────────────────────────────
  static const String base = '/api/v1';
  static const String register = '$base/auth/register';
  static const String sendOtp = '$base/auth/otp/send';
  static const String verifyOtp = '$base/auth/otp/verify';
  static const String setRole = '$base/auth/role';
  static const String refreshToken = '$base/auth/token/refresh';
  static const String profile = '$base/auth/me';
  static const String logout = '$base/auth/logout';

  // ── Routes & Waypoints ───────────────────────
  static const String routes = '$base/routes';
  static const String waypoints = '$base/routes/customers';
  static const String waypointById = '$base/routes/customers';
  static const String optimizeRoute = '$base/routes/optimize';
  static const String todayRoute = '$base/routes/today';
  static const String startRoute = '$base/routes/today/start';
  static const String completeRoute = '$base/routes/today/complete';
  static const String addToRoute = '$base/routes/today/waypoints';
  static const String nearbyWaypoints = '$base/routes/nearby';
  static const String routeHistory = '$base/routes/history';
  static const String routeStats = '$base/routes/stats';

  // ── Visits ───────────────────────────────────
  static const String todayVisits = '$base/routes/visits/today';
  static const String visitSummary = '$base/routes/visits/summary';
  static const String visitArrive = '$base/routes/visits';
  static const String visitComplete = '$base/routes/visits';
  static const String visitSkip = '$base/routes/visits';

  // ── Tracking ─────────────────────────────────
  static const String trackingWs = '$webSocketBaseUrl$base/routes/track/ws';
  static const String trackingLocation = '$base/routes/track';

  // ── Subscriptions ────────────────────────────
  static const String packages = '$base/subscriptions/packages';
  static const String subscribe = '$base/subscriptions/subscribe';
  static const String mySubscriptions = '$base/subscriptions/my';
  static const String todayOrders = '$base/subscriptions/today-orders';

  // ── Prices ───────────────────────────────────
  static const String prices = '$base/prices';
  static const String priceHistory = '$base/prices/history';
  static const String pricesCurrent = '$base/prices/current';
  static const String pricesTrend = '$base/prices/trend';
  static const String pricesRecommend = '$base/prices/recommend';
  static const String pricesAlerts = '$base/prices/alerts';
  static const String pricesTopMovers = '$base/prices/top-movers';
  static const String pricesAreaStats = '$base/prices/stats/area';
  static const String pricesCompare = '$base/prices/compare';

  // ── Products ─────────────────────────────────
  static const String products = '$base/prices/products';
  static const String productCategories = '$base/prices/products/categories';

  // ── Orders ───────────────────────────────────
  static const String orders = '$base/orders';

  // ── Transactions ─────────────────────────────
  static const String transactions = '$base/transactions';
  static const String transactionSummary = '$base/transactions/summary';
}
