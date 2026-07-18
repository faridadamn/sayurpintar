import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/dashboard/data/dashboard_repository.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:sayurpintar/features/common/widgets/app_bottom_nav.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HomeScreen — Unified Pedagang Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() async {
    ref.read(dashboardRefreshProvider.notifier).state++;
    // Small delay so providers have time to re-fetch
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dailySummaryProvider);
    final insightsAsync = ref.watch(insightsProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final badgeAsync = ref.watch(badgeProvider);
    final streakAsync = ref.watch(streakProvider);
    final balanceAsync = ref.watch(rewardBalanceProvider);
    final weeklyAsync = ref.watch(weeklyComparisonProvider);
    final pricesAsync = ref.watch(todayPricesProvider);

    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primaryGreen,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ─── App Bar ─────────────────────────────────────────────
            _DashboardAppBar(
              greeting: _greeting(),
              unreadCount: unreadCount,
            ),

            // ─── Content ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppTheme.space16),

                    // ── Section 1: Ringkasan Hari Ini ──────────────
                    _RingkasanHariIni(summaryAsync: summaryAsync),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 2: Insight Cards ───────────────────
                    _InsightCardsSection(insightsAsync: insightsAsync),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 3: Jadwal Hari Ini ─────────────────
                    _JadwalHariIni(),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 4: Harga Pasar ─────────────────────
                    _HargaPasarCompact(pricesAsync: pricesAsync),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 5: Reward Points ───────────────────
                    _RewardPointsSection(
                      badgeAsync: badgeAsync,
                      balanceAsync: balanceAsync,
                      streakAsync: streakAsync,
                    ),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 6: Perbandingan Mingguan ───────────
                    _WeeklyComparisonSection(weeklyAsync: weeklyAsync),
                    const SizedBox(height: AppTheme.space24),

                    // ── Section 7: Piutang ─────────────────────────
                    _PiutangSection(summaryAsync: summaryAsync),
                    const SizedBox(height: AppTheme.space32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// App Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardAppBar extends StatelessWidget {
  final String greeting;
  final int unreadCount;

  const _DashboardAppBar({
    required this.greeting,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space20,
                AppTheme.space12,
                AppTheme.space20,
                AppTheme.space8,
              ),
              child: Row(
                children: [
                  const SPAvatar(
                    name: 'P',
                    radius: 22,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$greeting! 👋',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'SayurPintar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  _NotificationBell(unreadCount: unreadCount),
                  const SizedBox(width: AppTheme.space8),
                  // Profile avatar
                  GestureDetector(
                    onTap: () => context.push('/daily-summary'),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;

  const _NotificationBell({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 28,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 1: Ringkasan Hari Ini — Gradient summary card
// ═══════════════════════════════════════════════════════════════════════════════

class _RingkasanHariIni extends StatelessWidget {
  final AsyncValue<DailySummary> summaryAsync;

  const _RingkasanHariIni({required this.summaryAsync});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const _SummaryLoadingSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) => _SummaryGradientCard(summary: s),
    );
  }
}

class _SummaryGradientCard extends StatelessWidget {
  final DailySummary summary;

  const _SummaryGradientCard({required this.summary});

  String _formatRp(double v) {
    if (v >= 1000000) {
      return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    }
    final str = v.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final revPct = summary.revenueVsYesterday;
    final revArrow = revPct >= 0 ? '↑' : '↓';
    final revColor =
        revPct >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A);

    return GestureDetector(
      onTap: () => context.push('/daily-summary'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF43A047)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: const Text(
                    '📊 Ringkasan Hari Ini',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: Colors.white54, size: 22),
              ],
            ),
            const SizedBox(height: AppTheme.space16),

            // Revenue row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Omset',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRp(summary.totalRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: revColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${revPct >= 0 ? '+' : ''}${revPct.toStringAsFixed(1)}% $revArrow',
                              style: TextStyle(
                                color: revColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'dari kemarin',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Profit
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Untung',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRp(summary.grossProfit),
                      style: const TextStyle(
                        color: Color(0xFFFFF176),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      'margin ${summary.profitMargin.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space20),

            // Stats row
            Row(
              children: [
                _MiniStat(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Pesanan',
                  value: '${summary.totalOrders}',
                  sub:
                      '${summary.deliveredOrders} selesai, ${summary.pendingOrders} pending',
                ),
                _MiniStatDivider(),
                _MiniStat(
                  icon: Icons.repeat,
                  label: 'Langganan',
                  value: '${summary.todayDeliveries}',
                  sub: 'antar hari ini',
                ),
                _MiniStatDivider(),
                _MiniStat(
                  icon: Icons.local_shipping_outlined,
                  label: 'Kunjungan',
                  value: '${summary.visitsCompleted}',
                  sub: '${summary.visitsSkipped} dilewati',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MiniStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _SummaryLoadingSkeleton extends StatelessWidget {
  const _SummaryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 2: Insight Cards — Horizontal scroll
// ═══════════════════════════════════════════════════════════════════════════════

class _InsightCardsSection extends StatelessWidget {
  final AsyncValue<List<Insight>> insightsAsync;

  const _InsightCardsSection({required this.insightsAsync});

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFFF9800);
      case 'medium':
        return const Color(0xFF2196F3);
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _priorityBg(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFFFF3E0);
      case 'medium':
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💡 Insight',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: insights.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.space12),
                itemBuilder: (context, index) {
                  final insight = insights[index];
                  final color = _priorityColor(insight.priority);
                  final bg = _priorityBg(insight.priority);
                  return GestureDetector(
                    onTap: () {
                      if (insight.action.isNotEmpty) {
                        context.push(insight.action, extra: insight.actionData);
                      }
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                insight.icon,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: AppTheme.space8),
                              Expanded(
                                child: Text(
                                  insight.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  insight.priority.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space8),
                          Expanded(
                            child: Text(
                              insight.message,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (insight.action.isNotEmpty)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                'Lihat →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 3: Jadwal Hari Ini — Next stops
// ═══════════════════════════════════════════════════════════════════════════════

class _JadwalHariIni extends StatelessWidget {
  // This section pulls from the route feature; we show static schedule cards
  // that navigate to the route screen.
  final List<_ScheduleItem> _items = const [
    _ScheduleItem(
        time: '06:30',
        name: 'Bu Ani',
        address: 'Jl. Merdeka 12',
        status: 'next'),
    _ScheduleItem(
        time: '07:15',
        name: 'Pak Budi',
        address: 'Jl. Sudirman 45',
        status: 'pending'),
    _ScheduleItem(
        time: '08:00',
        name: 'Bu Citra',
        address: 'Jl. Diponegoro 8',
        status: 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📅 Jadwal Hari Ini',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/waypoints'),
              child: const Text('Semua'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        ...List.generate(_items.length, (i) {
          final item = _items[i];
          final isNext = item.status == 'next';
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.space8),
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: isNext ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: isNext
                  ? Border.all(color: AppTheme.primaryGreen, width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Time
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isNext
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isNext ? Colors.white : AppTheme.primaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                // Customer info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isNext ? FontWeight.w700 : FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                if (isNext)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: const Text(
                      'Berikutnya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: AppTheme.space8),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 20),
              ],
            ),
          );
        }),
        const SizedBox(height: AppTheme.space12),
        // Mulai Rute button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/map'),
            icon: const Icon(Icons.navigation, size: 20),
            label: const Text('Mulai Rute'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleItem {
  final String time;
  final String name;
  final String address;
  final String status;

  const _ScheduleItem({
    required this.time,
    required this.name,
    required this.address,
    required this.status,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 4: Harga Pasar — Compact
// ═══════════════════════════════════════════════════════════════════════════════

class _HargaPasarCompact extends StatelessWidget {
  final AsyncValue<List<dynamic>> pricesAsync;

  const _HargaPasarCompact({required this.pricesAsync});

  static const Map<String, String> _emojis = {
    'bayam': '🥬',
    'kangkung': '🥬',
    'sawi': '🥬',
    'wortel': '🥕',
    'kentang': '🥔',
    'bawang merah': '🧅',
    'bawang putih': '🧄',
    'cabai': '🌶️',
    'tomat': '🍅',
    'terong': '🍆',
    'pisang': '🍌',
    'apel': '🍎',
    'jeruk': '🍊',
    'telur': '🥚',
    'ayam': '🍗',
    'tempe': '🫘',
    'tahu': '🧈',
  };

  String _emoji(String name) {
    final lower = name.toLowerCase();
    for (final e in _emojis.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '🥗';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp -';
    final n = price is int ? price : (price as num).toInt();
    final str = n.toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return pricesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prices) {
        if (prices.isEmpty) return const SizedBox.shrink();
        final top5 = prices.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🏷️ Harga Pasar',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/prices'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Container(
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
                children: List.generate(top5.length, (i) {
                  final p = top5[i];
                  final name = p['product_name'] ?? 'Produk';
                  final price = p['price'];
                  final trend = (p['trend'] ?? 'stable').toString();
                  final unit = p['unit'] ?? 'kg';
                  final trendIcon = trend == 'up'
                      ? '⬆️'
                      : trend == 'down'
                          ? '⬇️'
                          : '➡️';
                  final trendLabel = trend == 'up'
                      ? 'Naik'
                      : trend == 'down'
                          ? 'Turun'
                          : 'Stabil';
                  final trendColor = trend == 'up'
                      ? AppTheme.error
                      : trend == 'down'
                          ? AppTheme.primaryGreen
                          : AppTheme.textSecondary;

                  return InkWell(
                    onTap: () {
                      final pid = p['product_id']?.toString() ?? '';
                      context.push('/price-compare', extra: pid);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space10,
                      ),
                      child: Row(
                        children: [
                          Text(_emoji(name),
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: AppTheme.space10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'per $unit',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatPrice(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              Text(
                                '$trendIcon $trendLabel',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: trendColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 5: Reward Points
// ═══════════════════════════════════════════════════════════════════════════════

class _RewardPointsSection extends StatelessWidget {
  final AsyncValue<RewardBadge> badgeAsync;
  final AsyncValue<int> balanceAsync;
  final AsyncValue<int> streakAsync;

  const _RewardPointsSection({
    required this.badgeAsync,
    required this.balanceAsync,
    required this.streakAsync,
  });

  @override
  Widget build(BuildContext context) {
    final badge = badgeAsync.valueOrNull;
    final balance = balanceAsync.valueOrNull ?? 0;
    final streak = streakAsync.valueOrNull ?? 0;

    if (badge == null && balance == 0 && streak == 0) {
      return const SizedBox.shrink();
    }

    final progress = badge != null && badge.maxPoints > badge.minPoints
        ? ((balance - badge.minPoints) / (badge.maxPoints - badge.minPoints))
            .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/rewards'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  badge?.icon ?? '🥉',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge?.name ?? 'Pemula',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5D4037),
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        '$balance poin',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE65100),
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '🔥 $streak hari',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
              ],
            ),
            if (badge != null && badge.pointsToNext != null) ...[
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFFFCC80),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF8F00),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Text(
                    '${badge.pointsToNext} lagi ke ${badge.nextLevel ?? ""}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF795548),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 6: Perbandingan Mingguan — Mini bar chart
// ═══════════════════════════════════════════════════════════════════════════════

class _WeeklyComparisonSection extends StatelessWidget {
  final AsyncValue<WeeklyComparison> weeklyAsync;

  const _WeeklyComparisonSection({required this.weeklyAsync});

  String _formatRpShort(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return weeklyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (weekly) {
        final thisRev = weekly.thisWeek.totalRevenue;
        final lastRev = weekly.lastWeek.totalRevenue;
        final pctChange = weekly.changes.revenueChangePct;
        final isUp = pctChange >= 0;
        final trendEmoji = isUp ? '🎉' : '📉';
        final trendText = isUp
            ? 'Minggu ini naik ${pctChange.toStringAsFixed(1)}%!'
            : 'Minggu ini turun ${pctChange.abs().toStringAsFixed(1)}%';

        // Calculate bar heights (normalized)
        final maxRev = thisRev > lastRev ? thisRev : lastRev;
        final thisBarH = maxRev > 0 ? (thisRev / maxRev) : 0.0;
        final lastBarH = maxRev > 0 ? (lastRev / maxRev) : 0.0;

        return GestureDetector(
          onTap: () => context.push('/weekly-comparison'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '📈 Perbandingan Mingguan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space16),
                // Mini bar chart
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Last week bar
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Rp ${_formatRpShort(lastRev)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * lastBarH,
                            constraints: const BoxConstraints(minHeight: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Kemarin',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space16),
                    // This week bar
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Rp ${_formatRpShort(thisRev)}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isUp ? AppTheme.primaryGreen : AppTheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 80 * thisBarH,
                            constraints: const BoxConstraints(minHeight: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isUp
                                    ? [
                                        AppTheme.primaryGreen,
                                        AppTheme.primaryLight
                                      ]
                                    : [
                                        AppTheme.error,
                                        AppTheme.error.withOpacity(0.6)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Minggu Ini',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                // Trend label
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: isUp
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$trendEmoji $trendText',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isUp ? AppTheme.primaryDark : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section 7: Piutang
// ═══════════════════════════════════════════════════════════════════════════════

class _PiutangSection extends StatelessWidget {
  final AsyncValue<DailySummary> summaryAsync;

  const _PiutangSection({required this.summaryAsync});

  String _formatRp(double v) {
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)}jt';
    final str = v.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.totalPiutang <= 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.push('/daily-summary'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: const Color(0xFFFFCC80),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFE65100),
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Piutang',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRp(summary.totalPiutang),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE65100),
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        'Ada ${summary.piutangCount} pelanggan belum bayar',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF795548),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: const Text(
                    'Tagih',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
