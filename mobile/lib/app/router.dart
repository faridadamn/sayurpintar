import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import 'package:sayurpintar/app/main_shell.dart';
import 'package:sayurpintar/features/auth/presentation/splash_screen.dart';
import 'package:sayurpintar/features/auth/presentation/login_screen.dart';
import 'package:sayurpintar/features/auth/presentation/otp_screen.dart';
import 'package:sayurpintar/features/auth/presentation/role_selection_screen.dart';
import 'package:sayurpintar/features/auth/presentation/profile_setup_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/home_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/daily_summary_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/notification_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/weekly_comparison_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/reward_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/pelanggan_home_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/pelanggan_order_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/pelanggan_profile_screen.dart';
import 'package:sayurpintar/features/dashboard/presentation/profile_screen.dart';
import 'package:sayurpintar/features/route/presentation/map_screen.dart';
import 'package:sayurpintar/features/route/presentation/waypoint_list_screen.dart';
import 'package:sayurpintar/features/route/presentation/add_waypoint_screen.dart';
import 'package:sayurpintar/features/route/presentation/route_optimized_screen.dart';
import 'package:sayurpintar/features/route/presentation/navigation_screen.dart';
import 'package:sayurpintar/features/route/presentation/visit_completion_screen.dart';
import 'package:sayurpintar/features/route/providers/tracking_provider.dart';
import 'package:sayurpintar/features/subscription/presentation/create_package_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/package_list_screen.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/presentation/subscribe_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/my_subscriptions_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/subscription_detail_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/modify_delivery_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/browse_merchants_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/order_history_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/today_orders_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/subscribers_screen.dart';
import 'package:sayurpintar/features/subscription/presentation/package_detail_screen.dart';
import 'package:sayurpintar/features/price/presentation/price_submit_screen.dart';
import 'package:sayurpintar/features/price/presentation/price_dashboard_screen.dart';
import 'package:sayurpintar/features/price/presentation/pelanggan_price_screen.dart';
import 'package:sayurpintar/features/price/presentation/price_comparison_screen.dart';
import 'package:sayurpintar/features/price/presentation/price_alert_pelanggan_screen.dart';
import 'package:sayurpintar/features/price/presentation/price_detail_screen.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Splash ─────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // ── Auth ───────────────────────────────────
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OTPScreen(phone: phone);
      },
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),

    // ── Pedagang Shell (with bottom nav) ───────
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/subscriptions/packages',
          builder: (context, state) => const PackageListScreen(),
        ),
        GoRoute(
          path: '/prices',
          builder: (context, state) => const PelangganPriceScreen(),
        ),
        GoRoute(
          path: '/prices/dashboard',
          builder: (context, state) => const PriceDashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // ── Pelanggan Shell (with bottom nav) ──────
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/pelanggan/home',
          builder: (context, state) => const PelangganHomeScreen(),
        ),
        GoRoute(
          path: '/my-subscriptions',
          builder: (context, state) => const MySubscriptionsScreen(),
        ),
        GoRoute(
          path: '/pelanggan/orders',
          builder: (context, state) => const PelangganOrderScreen(),
        ),
        GoRoute(
          path: '/pelanggan/profile',
          builder: (context, state) => const PelangganProfileScreen(),
        ),
      ],
    ),

    // ── Dashboard (standalone) ─────────────────
    GoRoute(
      path: '/daily-summary',
      builder: (context, state) => const DailySummaryScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/weekly-comparison',
      builder: (context, state) => const WeeklyComparisonScreen(),
    ),
    GoRoute(
      path: '/rewards',
      builder: (context, state) => const RewardScreen(),
    ),

    // ── Route feature (standalone) ─────────────
    GoRoute(
      path: '/waypoints',
      builder: (context, state) => const WaypointListScreen(),
    ),
    GoRoute(
      path: '/waypoints/add',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final lat = state.uri.queryParameters['lat'];
        final lng = state.uri.queryParameters['lng'];
        return AddWaypointScreen(
          waypointId: id,
          initialLat: lat != null ? double.tryParse(lat) : null,
          initialLng: lng != null ? double.tryParse(lng) : null,
        );
      },
    ),
    GoRoute(
      path: '/route/optimized',
      builder: (context, state) {
        final extra = state.extra;
        if (extra != null && extra is Map) {
          return const RouteOptimizedScreen();
        }
        return const RouteOptimizedScreen();
      },
    ),
    GoRoute(
      path: '/route/navigation',
      builder: (context, state) {
        final route = state.extra as RouteData;
        return NavigationScreen(route: route);
      },
    ),
    GoRoute(
      path: '/visit/complete',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return VisitCompletionScreen(
          visit: args['visit'] as VisitData,
          waypoint: args['waypoint'] as WaypointData,
        );
      },
    ),

    // ── Subscription feature (standalone) ──────
    GoRoute(
      path: '/subscriptions/create-package',
      builder: (context, state) => const CreatePackageScreen(),
    ),
    GoRoute(
      path: '/subscriptions/subscribe',
      builder: (context, state) {
        return const PackageListScreen();
      },
    ),
    GoRoute(
      path: '/subscribe',
      builder: (context, state) =>
          SubscribeScreen(package: state.extra as SubscriptionPackage),
    ),
    GoRoute(
      path: '/subscription-detail',
      builder: (context, state) => SubscriptionDetailScreen(
          subscription: state.extra as Subscription),
    ),
    GoRoute(
      path: '/modify-delivery',
      builder: (context, state) {
        final args = state.extra as Map;
        return ModifyDeliveryScreen(
          subscription: args['subscription'] as Subscription,
          deliveryDate: args['date'] as String,
        );
      },
    ),
    GoRoute(
      path: '/browse-merchants',
      builder: (context, state) => const BrowseMerchantsScreen(),
    ),
    GoRoute(
      path: '/order-history',
      builder: (context, state) => const OrderHistoryScreen(),
    ),
    GoRoute(
      path: '/subscriptions/today-orders',
      builder: (context, state) => const TodayOrdersScreen(),
    ),
    GoRoute(
      path: '/subscriptions/subscribers',
      builder: (context, state) => const SubscribersScreen(),
    ),
    GoRoute(
      path: '/subscriptions/package-detail',
      builder: (context, state) {
        final packageId = state.extra as String;
        return PackageDetailScreen(packageId: packageId);
      },
    ),
    GoRoute(
      path: '/subscriptions/edit-package',
      builder: (context, state) {
        final packageId = state.extra as String;
        return CreatePackageScreen(packageId: packageId);
      },
    ),

    // ── Price feature (standalone) ─────────────
    GoRoute(
      path: '/prices/submit',
      builder: (context, state) => const PriceSubmitScreen(),
    ),
    GoRoute(
      path: '/price-compare',
      builder: (context, state) {
        final productId = state.extra as String;
        return PriceComparisonScreen(productId: productId);
      },
    ),
    GoRoute(
      path: '/price-alerts',
      builder: (context, state) => const PriceAlertPelangganScreen(),
    ),
    GoRoute(
      path: '/prices/detail',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return PriceDetailScreen(
          product: args['product'] as Product,
          area: args['area'] as String,
        );
      },
    ),

    // ── Notifications & Rewards (real screens) ──
  ],
);

// ── Placeholder Screen (for routes referenced but not yet built) ─────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Segera hadir',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
