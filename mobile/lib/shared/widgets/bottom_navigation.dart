import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';

// ── Unified Bottom Navigation ────────────────────────────────────────────
// Adapts navigation items based on user role (pedagang vs pelanggan).

class AppBottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isPedagang = user?.isPedagang ?? true;

    if (isPedagang) {
      return _PedagangNav(currentIndex: currentIndex, onTap: onTap);
    } else {
      return _PelangganNav(currentIndex: currentIndex, onTap: onTap);
    }
  }
}

// ── Pedagang Navigation ──────────────────────────────────────────────────
// Items: Home, Rute, Langganan, Harga, Profil

class _PedagangNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _PedagangNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Beranda',
      route: '/home',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Rute',
      route: '/map',
    ),
    _NavItem(
      icon: Icons.subscriptions_outlined,
      activeIcon: Icons.subscriptions,
      label: 'Langganan',
      route: '/subscriptions/packages',
    ),
    _NavItem(
      icon: Icons.price_change_outlined,
      activeIcon: Icons.price_change,
      label: 'Harga',
      route: '/prices',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
      route: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryGreen.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Pelanggan Navigation ─────────────────────────────────────────────────
// Items: Home, Langganan, Harga, Pesanan, Profil

class _PelangganNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _PelangganNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Beranda',
      route: '/pelanggan/home',
    ),
    _NavItem(
      icon: Icons.subscriptions_outlined,
      activeIcon: Icons.subscriptions,
      label: 'Langganan',
      route: '/my-subscriptions',
    ),
    _NavItem(
      icon: Icons.price_change_outlined,
      activeIcon: Icons.price_change,
      label: 'Harga',
      route: '/prices',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Pesanan',
      route: '/pelanggan/orders',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
      route: '/pelanggan/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryGreen.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item Model ───────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
