import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(dashboardRepositoryProvider);
              await repo.markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua notifikasi ditandai sudah dibaca'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Tandai Semua',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const SPLoading(message: 'Memuat notifikasi...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: AppTheme.space16),
              Text('Gagal memuat: $e'),
              const SizedBox(height: AppTheme.space16),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const SPEmptyState(
              icon: Icons.notifications_none,
              title: 'Tidak ada notifikasi',
              message:
                  'Notifikasi akan muncul di sini ketika ada pesanan baru, perubahan harga, atau info penting lainnya.',
            );
          }
          // Group by date
          final grouped = _groupByDate(notifications);
          return RefreshIndicator(
            color: AppTheme.primaryGreen,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
              itemCount: grouped.length,
              itemBuilder: (context, sectionIndex) {
                final section = grouped[sectionIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.space16,
                        AppTheme.space16,
                        AppTheme.space16,
                        AppTheme.space8,
                      ),
                      child: Text(
                        section.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...section.items.map((notif) => _NotificationCard(
                          notification: notif,
                          onDismissed: () async {
                            // Swipe-to-dismiss just marks as read
                            final repo = ref.read(dashboardRepositoryProvider);
                            await repo.markAsRead(notif.id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadCountProvider);
                          },
                          onTap: () async {
                            if (!notif.isRead) {
                              final repo =
                                  ref.read(dashboardRepositoryProvider);
                              await repo.markAsRead(notif.id);
                              ref.invalidate(notificationsProvider);
                              ref.invalidate(unreadCountProvider);
                            }
                            _handleTap(context, notif);
                          },
                        )),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<_NotificationGroup> _groupByDate(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final List<AppNotification> todayItems = [];
    final List<AppNotification> yesterdayItems = [];
    final List<AppNotification> thisWeekItems = [];
    final List<AppNotification> olderItems = [];

    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else if (d.isAfter(weekAgo)) {
        thisWeekItems.add(n);
      } else {
        olderItems.add(n);
      }
    }

    final List<_NotificationGroup> groups = [];
    if (todayItems.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'HARI INI', items: todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'KEMARIN', items: yesterdayItems));
    }
    if (thisWeekItems.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'MINGGU INI', items: thisWeekItems));
    }
    if (olderItems.isNotEmpty) {
      groups.add(_NotificationGroup(label: 'SEBELUMNYA', items: olderItems));
    }
    return groups;
  }

  void _handleTap(BuildContext context, AppNotification notif) {
    // Navigate based on notification type
    switch (notif.type) {
      case 'order':
      case 'subscription':
        // Could navigate to order detail
        break;
      case 'price_alert':
        // Could navigate to price comparison
        break;
      case 'route':
        // Could navigate to route
        break;
      default:
        break;
    }
  }
}

class _NotificationGroup {
  final String label;
  final List<AppNotification> items;

  const _NotificationGroup({required this.label, required this.items});
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onDismissed,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'subscription':
        return Icons.repeat;
      case 'price_alert':
        return Icons.price_change_outlined;
      case 'route':
        return Icons.map_outlined;
      case 'reward':
        return Icons.emoji_events_outlined;
      case 'payment':
        return Icons.payment_outlined;
      case 'reminder':
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'order':
        return AppTheme.primaryGreen;
      case 'subscription':
        return const Color(0xFF7B1FA2);
      case 'price_alert':
        return const Color(0xFFFF9800);
      case 'route':
        return const Color(0xFF1565C0);
      case 'reward':
        return const Color(0xFFFFB300);
      case 'payment':
        return const Color(0xFF00897B);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(notification.type);
    final color = _colorForType(notification.type);
    final isRead = notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.space20),
        color: AppTheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFE3F2FD),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.divider.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppTheme.space12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
