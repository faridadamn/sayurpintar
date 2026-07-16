import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';
import 'package:sayurpintar/shared/widgets/bottom_navigation.dart';

// ── Main Shell ───────────────────────────────────────────────────────────
// Wraps child screens with a persistent bottom navigation bar.
// Adapts navigation items based on the current user's role.

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isPedagang = user?.isPedagang ?? true;

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _calculateSelectedIndex(context, isPedagang),
        onTap: (index) => _onItemTapped(index, context, isPedagang),
      ),
    );
  }

  /// Determine which tab is currently selected based on the route.
  int _calculateSelectedIndex(BuildContext context, bool isPedagang) {
    final location = GoRouterState.of(context).uri.toString();

    if (isPedagang) {
      // Pedagang: Home, Rute, Langganan, Harga, Profil
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/map') ||
          location.startsWith('/waypoints') ||
          location.startsWith('/route')) return 1;
      if (location.startsWith('/subscriptions') ||
          location.startsWith('/subscribe')) return 2;
      if (location.startsWith('/prices')) return 3;
      if (location.startsWith('/profile')) return 4;
    } else {
      // Pelanggan: Home, Langganan, Harga, Pesanan, Profil
      if (location.startsWith('/pelanggan/home')) return 0;
      if (location.startsWith('/my-subscriptions') ||
          location.startsWith('/subscription-detail') ||
          location.startsWith('/browse-merchants')) return 1;
      if (location.startsWith('/prices')) return 2;
      if (location.startsWith('/pelanggan/orders') ||
          location.startsWith('/order-history')) return 3;
      if (location.startsWith('/pelanggan/profile')) return 4;
    }

    return 0;
  }

  /// Navigate to the appropriate route when a tab is tapped.
  void _onItemTapped(
      int index, BuildContext context, bool isPedagang) {
    if (isPedagang) {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/map');
          break;
        case 2:
          context.go('/subscriptions/packages');
          break;
        case 3:
          context.go('/prices');
          break;
        case 4:
          context.go('/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/pelanggan/home');
          break;
        case 1:
          context.go('/my-subscriptions');
          break;
        case 2:
          context.go('/prices');
          break;
        case 3:
          context.go('/pelanggan/orders');
          break;
        case 4:
          context.go('/pelanggan/profile');
          break;
      }
    }
  }
}
