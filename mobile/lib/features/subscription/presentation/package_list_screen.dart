import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PackageListScreen extends ConsumerWidget {
  const PackageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(myPackagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket Langganan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Pelanggan',
            onPressed: () => context.push('/subscriptions/subscribers'),
          ),
        ],
      ),
      body: packagesAsync.when(
        loading: () => const SPLoading(message: 'Memuat paket...'),
        error: (error, _) => SPErrorWidget(
          message: 'Gagal memuat paket: $error',
          onRetry: () => ref.invalidate(myPackagesProvider),
        ),
        data: (packages) {
          if (packages.isEmpty) {
            return SPEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Belum Ada Paket',
              message:
                  'Buat paket langganan untuk pelanggan Anda.\nPelanggan bisa berlangganan dan menerima sayur secara rutin.',
              actionLabel: 'Buat Paket',
              onAction: () =>
                  context.push('/subscriptions/create-package'),
            );
          }

          final activePackages =
              packages.where((p) => p.isActive).toList();
          final inactivePackages =
              packages.where((p) => !p.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPackagesProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.space16),
              children: [
                // ── Stats Bar ───────────────────────────────────────────
                _StatsBar(packages: packages),
                const SizedBox(height: AppTheme.space16),

                // ── Active Packages ─────────────────────────────────────
                if (activePackages.isNotEmpty) ...[
                  _buildSectionTitle(
                      'Aktif (${activePackages.length})'),
                  ...activePackages.map(
                    (pkg) => _PackageCard(
                      package: pkg,
                      onTap: () => context.push(
                        '/subscriptions/package-detail',
                        extra: pkg.id,
                      ),
                      onDelete: () =>
                          _confirmDelete(context, ref, pkg),
                    ),
                  ),
                ],

                // ── Inactive Packages ───────────────────────────────────
                if (inactivePackages.isNotEmpty) ...[
                  _buildSectionTitle(
                      'Nonaktif (${inactivePackages.length})'),
                  ...inactivePackages.map(
                    (pkg) => _PackageCard(
                      package: pkg,
                      onTap: () => context.push(
                        '/subscriptions/package-detail',
                        extra: pkg.id,
                      ),
                      onDelete: () =>
                          _confirmDelete(context, ref, pkg),
                      isInactive: true,
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.space80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/subscriptions/create-package'),
        icon: const Icon(Icons.add),
        label: const Text('Buat Paket'),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.space4,
        top: AppTheme.space12,
        bottom: AppTheme.space8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPackage pkg,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text(
          'Hapus "${pkg.name}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo =
                    ref.read(subscriptionRepositoryProvider);
                await repo.deletePackage(pkg.id);
                ref.invalidate(myPackagesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Paket "${pkg.name}" dihapus'),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ── Stats Bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final List<SubscriptionPackage> packages;

  const _StatsBar({required this.packages});

  @override
  Widget build(BuildContext context) {
    final activeCount = packages.where((p) => p.isActive).length;
    final totalSubscribers = packages.fold<int>(
      0,
      (sum, p) => sum + (p.subscriberCount ?? 0),
    );

    return Row(
      children: [
        _StatChip(
          icon: Icons.inventory_2,
          label: '$activeCount Aktif',
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(width: AppTheme.space8),
        _StatChip(
          icon: Icons.people,
          label: '$totalSubscribers Pelanggan',
          color: AppTheme.accent,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Package Card ─────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final SubscriptionPackage package;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isInactive;

  const _PackageCard({
    required this.package,
    required this.onTap,
    required this.onDelete,
    this.isInactive = false,
  });

  String _formatCurrency(double value) {
    final parts = value.toInt().toString().split('');
    final result = <String>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      result.insert(0, parts[i]);
      if ((parts.length - i) % 3 == 0 && i != 0) {
        result.insert(0, '.');
      }
    }
    return 'Rp ${result.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(package.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.space20),
        margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: SPCard(
        onTap: onTap,
        margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
        color: isInactive ? Colors.grey.shade50 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isInactive
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: package.isActive
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                        AppTheme.radiusFull),
                  ),
                  child: Text(
                    package.isActive ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: package.isActive
                          ? AppTheme.primaryGreen
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                Text(
                  '${_formatCurrency(package.price)} / pengiriman',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    package.frequencyText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  package.deliveryDaysText,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                const Icon(
                  Icons.people,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  '${package.subscriberCount ?? 0} pelanggan',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                const Icon(
                  Icons.shopping_basket,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  '${package.items.length} item',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
