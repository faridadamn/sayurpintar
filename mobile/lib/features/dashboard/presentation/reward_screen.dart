import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';

class RewardScreen extends ConsumerWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(badgeProvider);
    final balanceAsync = ref.watch(rewardBalanceProvider);
    final streakAsync = ref.watch(streakProvider);
    final historyAsync = ref.watch(rewardHistoryProvider);

    final badge = badgeAsync.valueOrNull;
    final balance = balanceAsync.valueOrNull ?? 0;
    final streak = streakAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward & Poin'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(badgeProvider);
              ref.invalidate(rewardBalanceProvider);
              ref.invalidate(streakProvider);
              ref.invalidate(rewardHistoryProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: badgeAsync.when(
        loading: () => const SPLoading(message: 'Memuat reward...'),
        error: (e, _) => SPErrorWidget(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(badgeProvider);
            ref.invalidate(rewardBalanceProvider);
          },
        ),
        data: (_) => _RewardContent(
          badge: badge,
          balance: balance,
          streak: streak,
          historyAsync: historyAsync,
        ),
      ),
    );
  }
}

class _RewardContent extends StatelessWidget {
  final RewardBadge? badge;
  final int balance;
  final int streak;
  final AsyncValue<List<PointTransaction>> historyAsync;

  const _RewardContent({
    required this.badge,
    required this.balance,
    required this.streak,
    required this.historyAsync,
  });

  @override
  Widget build(BuildContext context) {
    final progress = badge != null && badge!.maxPoints > badge!.minPoints
        ? ((balance - badge!.minPoints) / (badge!.maxPoints - badge!.minPoints))
            .clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badge display ─────────────────────────────────────
          _BadgeDisplay(badge: badge, balance: balance, progress: progress),
          const SizedBox(height: AppTheme.space24),

          // ── Streak counter ────────────────────────────────────
          if (streak > 0) ...[
            _StreakCounter(streak: streak),
            const SizedBox(height: AppTheme.space24),
          ],

          // ── Ways to earn ──────────────────────────────────────
          const Text(
            '🎯 Cara Mendapatkan Poin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          const _WaysToEarn(),
          const SizedBox(height: AppTheme.space24),

          // ── Point history ─────────────────────────────────────
          const Text(
            '📜 Riwayat Poin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          historyAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (history) {
              if (history.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada riwayat poin',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return _PointHistoryList(history: history);
            },
          ),
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }
}

class _BadgeDisplay extends StatelessWidget {
  final RewardBadge? badge;
  final int balance;
  final double progress;

  const _BadgeDisplay({
    required this.badge,
    required this.balance,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3), Color(0xFFFFE082)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Badge icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                badge?.icon ?? '🥉',
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          // Badge name
          Text(
            badge?.name ?? 'Pemula',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5D4037),
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Level ${badge?.level ?? "bronze"}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF795548),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          // Points balance
          Text(
            '$balance',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE65100),
              fontFamily: 'Nunito',
            ),
          ),
          const Text(
            'Poin',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF795548),
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          // Progress bar
          if (badge != null && badge!.pointsToNext != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFFFCC80),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF8F00),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              '${badge!.pointsToNext} poin lagi untuk naik ke ${badge!.nextLevel ?? "level berikutnya"}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF795548),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakCounter extends StatelessWidget {
  final int streak;

  const _StreakCounter({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F00).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak hari berturut-turut!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Konsistensi adalah kunci! Terus jualan setiap hari.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaysToEarn extends StatelessWidget {
  const _WaysToEarn();

  @override
  Widget build(BuildContext context) {
    const ways = [
      _EarnWay(
        icon: '📦',
        title: 'Setiap Pesanan Selesai',
        points: '+5 poin',
        color: AppTheme.primaryGreen,
      ),
      _EarnWay(
        icon: '📅',
        title: 'Jualan Setiap Hari (Streak)',
        points: '+10 poin',
        color: Color(0xFFFF6F00),
      ),
      _EarnWay(
        icon: '👤',
        title: 'Pelanggan Baru Berlangganan',
        points: '+50 poin',
        color: Color(0xFF7B1FA2),
      ),
      _EarnWay(
        icon: '💰',
        title: 'Omset Harian > Rp 500rb',
        points: '+25 poin',
        color: Color(0xFF1565C0),
      ),
      _EarnWay(
        icon: '⭐',
        title: 'Rating Bintang 5 dari Pelanggan',
        points: '+15 poin',
        color: Color(0xFFFFB300),
      ),
      _EarnWay(
        icon: '📊',
        title: 'Update Harga Pasar',
        points: '+3 poin',
        color: Color(0xFF00897B),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(ways.length, (i) {
          final way = ways[i];
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  color: AppTheme.divider.withOpacity(0.3),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
                child: Row(
                  children: [
                    Text(way.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(
                        way.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: way.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        way.points,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: way.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _EarnWay {
  final String icon;
  final String title;
  final String points;
  final Color color;

  const _EarnWay({
    required this.icon,
    required this.title,
    required this.points,
    required this.color,
  });
}

class _PointHistoryList extends StatelessWidget {
  final List<PointTransaction> history;

  const _PointHistoryList({required this.history});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(history.length, (i) {
          final tx = history[i];
          final isPositive = tx.amount > 0;
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  color: AppTheme.divider.withOpacity(0.3),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: isPositive ? AppTheme.primaryGreen : AppTheme.error,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.reason,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _timeAgo(tx.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}${tx.amount}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isPositive ? AppTheme.primaryGreen : AppTheme.error,
                          ),
                        ),
                        Text(
                          'Saldo: ${tx.balance}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
