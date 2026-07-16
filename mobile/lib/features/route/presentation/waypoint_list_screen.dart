import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';
import 'package:sayurpintar/features/route/providers/route_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';

class WaypointListScreen extends ConsumerStatefulWidget {
  const WaypointListScreen({super.key});

  @override
  ConsumerState<WaypointListScreen> createState() =>
      _WaypointListScreenState();
}

class _WaypointListScreenState extends ConsumerState<WaypointListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Waypoint> _filterWaypoints(List<Waypoint> waypoints) {
    var filtered = waypoints;

    // Apply filter
    final filter = ref.read(waypointFilterProvider);
    switch (filter) {
      case WaypointFilter.active:
        filtered = filtered.where((wp) => wp.isActive).toList();
        break;
      case WaypointFilter.inactive:
        filtered = filtered.where((wp) => !wp.isActive).toList();
        break;
      case WaypointFilter.all:
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((wp) {
        return wp.label.toLowerCase().contains(query) ||
            (wp.address?.toLowerCase().contains(query) ?? false) ||
            (wp.pelangganName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  void _confirmDelete(Waypoint wp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Hapus Titik?'),
        content: Text(
          'Yakin ingin menghapus "${wp.label}"? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteWaypoint(wp.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWaypoint(String id) async {
    try {
      final repo = ref.read(routeRepositoryProvider);
      await repo.deleteWaypoint(id);
      ref.invalidate(waypointsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik berhasil dihapus'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildPriorityStars(int priority) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < priority ? Icons.star : Icons.star_border,
          size: 16,
          color: i < priority ? AppTheme.accent : AppTheme.divider,
        );
      }),
    );
  }

  Widget _buildWaypointCard(Waypoint wp, int index) {
    return Slidable(
      key: ValueKey(wp.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDelete(wp),
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Hapus',
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(AppTheme.radiusMedium),
            ),
          ),
        ],
      ),
      child: SPCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space4,
        ),
        onTap: () => context.push('/waypoints/add?id=${wp.id}'),
        child: Row(
          children: [
            // Index number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: wp.isActive
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : AppTheme.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: wp.isActive
                        ? AppTheme.primaryGreen
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wp.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: wp.isActive
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildPriorityStars(wp.priority),
                    ],
                  ),
                  if (wp.address != null && wp.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            wp.address!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (wp.pelangganName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wp.pelangganName!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (wp.visitCount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${wp.visitCount} kunjungan',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final currentFilter = ref.watch(waypointFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      child: Row(
        children: [
          _FilterChip(
            label: 'Semua',
            isSelected: currentFilter == WaypointFilter.all,
            onTap: () =>
                ref.read(waypointFilterProvider.notifier).state =
                    WaypointFilter.all,
          ),
          const SizedBox(width: AppTheme.space8),
          _FilterChip(
            label: 'Aktif',
            isSelected: currentFilter == WaypointFilter.active,
            onTap: () =>
                ref.read(waypointFilterProvider.notifier).state =
                    WaypointFilter.active,
          ),
          const SizedBox(width: AppTheme.space8),
          _FilterChip(
            label: 'Nonaktif',
            isSelected: currentFilter == WaypointFilter.inactive,
            onTap: () =>
                ref.read(waypointFilterProvider.notifier).state =
                    WaypointFilter.inactive,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waypointsAsync = ref.watch(waypointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Titik Kunjungan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(waypointsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              AppTheme.space12,
              AppTheme.space16,
              0,
            ),
            child: SPInput(
              label: '',
              hint: 'Cari nama atau alamat...',
              controller: _searchController,
              prefixIcon: Icons.search,
              suffixIcon: _searchQuery.isNotEmpty ? Icons.clear : null,
              onSuffixTap: _searchQuery.isNotEmpty
                  ? () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    }
                  : null,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Filter chips
          _buildFilterChips(),

          // Waypoint list
          Expanded(
            child: waypointsAsync.when(
              data: (waypoints) {
                final filtered = _filterWaypoints(waypoints);

                if (waypoints.isEmpty) {
                  return SPEmptyState(
                    icon: Icons.location_off,
                    title: 'Belum ada pelanggan',
                    message:
                        'Tambah titik pertama untuk memulai rute harian Anda!',
                    actionLabel: 'Tambah Titik',
                    onAction: () => context.push('/waypoints/add'),
                  );
                }

                if (filtered.isEmpty) {
                  return SPEmptyState(
                    icon: Icons.search_off,
                    title: 'Tidak ditemukan',
                    message: _searchQuery.isNotEmpty
                        ? 'Tidak ada titik yang cocok dengan "$_searchQuery"'
                        : 'Tidak ada titik dengan filter ini',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(waypointsProvider);
                  },
                  color: AppTheme.primaryGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppTheme.space8,
                      bottom: 80,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildWaypointCard(filtered[index], index);
                    },
                  ),
                );
              },
              loading: () => const SPLoading(message: 'Memuat titik...'),
              error: (e, _) => SPErrorWidget(
                message: 'Gagal memuat titik kunjungan',
                onRetry: () => ref.invalidate(waypointsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/waypoints/add'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Tambah Titik'),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Filter chip widget
// ──────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
