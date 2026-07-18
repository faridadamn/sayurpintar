import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';

// ── Pelanggan Dashboard Home Screen ─────────────────────────────────────

class PelangganHomeScreen extends ConsumerStatefulWidget {
  const PelangganHomeScreen({super.key});

  @override
  ConsumerState<PelangganHomeScreen> createState() =>
      _PelangganHomeScreenState();
}

class _PelangganHomeScreenState extends ConsumerState<PelangganHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final subscriptionsAsync = ref.watch(myActiveSubscriptionsProvider);
    final orderHistoryAsync = ref.watch(orderHistoryProvider('semua'));
    final pricesAsync = ref.watch(todayPricesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
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
                    padding: const EdgeInsets.all(AppTheme.space20),
                    child: Row(
                      children: [
                        SPAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.name ?? 'Pelanggan',
                          radius: 24,
                          backgroundColor: Colors.white24,
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _greeting(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                user?.name ?? 'Pelanggan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  context.push('/notifications'),
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppTheme.space4),
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: SPAvatar(
                            imageUrl: user?.avatarUrl,
                            name: user?.name ?? 'P',
                            radius: 18,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body Content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section 1: Langganan Saya ────────────────────
                  subscriptionsAsync.when(
                    data: (subs) {
                      if (subs.isNotEmpty) {
                        return _ActiveSubscriptionCard(subscription: subs.first);
                      }
                      return _NoSubscriptionCard();
                    },
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => _NoSubscriptionCard(),
                  ),
                  const SizedBox(height: AppTheme.space16),

                  // ── Section 2: Pesanan Terakhir ──────────────────
                  const Text(
                    'Pesanan Terakhir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),
                  orderHistoryAsync.when(
                    data: (orders) {
                      if (orders.isNotEmpty) {
                        return _LastOrderCard(order: orders.first);
                      }
                      return const SPCard(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.space16),
                            child: Text(
                              'Belum ada pesanan',
                              style:
                                  TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SPCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppTheme.space16),
                          child: Text(
                            'Gagal memuat pesanan',
                            style:
                                TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),

                  // ── Section 3: Harga Pasar Hari Ini ──────────────
                  _MarketPricesSection(pricesAsync: pricesAsync),
                  const SizedBox(height: AppTheme.space16),

                  // ── Section 4: Pedagang Langganan (when no sub) ──
                  subscriptionsAsync.when(
                    data: (subs) {
                      if (subs.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FeaturedPedagangSection(),
                            const SizedBox(height: AppTheme.space16),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // ── Section 5: Rating & Feedback ─────────────────
                  _PendingRatingsCard(),
                  const SizedBox(height: AppTheme.space24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi! 🌅';
    if (hour < 15) return 'Selamat Siang! ☀️';
    if (hour < 18) return 'Selamat Sore! 🌤️';
    return 'Selamat Malam! 🌙';
  }
}

// ── Active Subscription Card ─────────────────────────────────────────────

class _ActiveSubscriptionCard extends StatelessWidget {
  final dynamic subscription; // Subscription model

  const _ActiveSubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final pedagangName = subscription.pedagangName ?? 'Pedagang';
    final packageName = subscription.packageName ?? 'Paket';
    final status = subscription.status ?? 'active';
    final nextDelivery = _formatNextDelivery(subscription.nextDeliveryDate);
    final items = subscription.itemsSummary ?? '';

    return SPCard(
      onTap: () => context.push('/my-subscriptions'),
      color: AppTheme.primaryGreen.withOpacity(0.06),
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SPAvatar(
                name: pedagangName,
                radius: 22,
                backgroundColor: AppTheme.primaryGreen,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedagangName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Text(
                      packageName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengiriman Berikutnya',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        nextDelivery,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountdownChip(date: subscription.nextDeliveryDate),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              items,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/modify-delivery',
                      extra: {
                        'subscription': subscription,
                        'date': '',
                      }),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Ubah Pesanan'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPauseDialog(context),
                  icon: const Icon(Icons.pause_outlined, size: 16),
                  label: const Text('Lewati'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.space8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNextDelivery(dynamic date) {
    if (date == null) return 'Menunggu jadwal';
    try {
      final d = DateTime.parse(date.toString());
      final days = [
        'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
      ];
      final months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final isTomorrow = d.year == tomorrow.year &&
          d.month == tomorrow.month &&
          d.day == tomorrow.day;
      final dayName = days[d.weekday - 1];
      final monthName = months[d.month];
      if (isTomorrow) {
        return 'Besok, $dayName ${d.day} $monthName';
      }
      return '$dayName, ${d.day} $monthName ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  void _showPauseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lewati Pengiriman?'),
        content: const Text(
            'Anda akan melewati pengiriman berikutnya. Paket tetap aktif.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ya, Lewati'),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final color = isActive ? AppTheme.primaryGreen : Colors.orange;
    final label = isActive ? 'Aktif' : 'Dijeda';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Countdown Chip ───────────────────────────────────────────────────────

class _CountdownChip extends StatelessWidget {
  final dynamic date;

  const _CountdownChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final remaining = _calculateRemaining();
    if (remaining == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        remaining,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.orange,
        ),
      ),
    );
  }

  String? _calculateRemaining() {
    if (date == null) return null;
    try {
      final d = DateTime.parse(date.toString());
      final diff = d.difference(DateTime.now());
      if (diff.isNegative) return null;
      if (diff.inHours < 24) {
        return '${diff.inHours}j lagi';
      }
      return '${diff.inDays}h lagi';
    } catch (_) {
      return null;
    }
  }
}

// ── No Subscription Card ─────────────────────────────────────────────────

class _NoSubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SPCard(
      color: AppTheme.accent.withOpacity(0.08),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 48,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: AppTheme.space12),
          const Text(
            'Belum berlangganan?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          const Text(
            'Cari pedagang di sekitarmu dan mulai langganan sayuran segar!',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space16),
          SPButton(
            label: 'Cari Pedagang',
            icon: Icons.search,
            onPressed: () => context.push('/browse-merchants'),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }
}

// ── Last Order Card ──────────────────────────────────────────────────────

class _LastOrderCard extends StatelessWidget {
  final dynamic order; // Order model

  const _LastOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(order.deliveryDate ?? order.createdAt);
    final items = order.itemsSummary ?? 'Pesanan';
    final total = _formatPrice(order.totalPrice ?? order.total ?? 0);
    final status = order.status ?? 'pending';
    final isRated = order.isRated ?? false;
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return SPCard(
      onTap: () => context.push('/order-history'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            items,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                total,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.primaryDark,
                ),
              ),
              if (!isRated && status == 'delivered')
                TextButton.icon(
                  onPressed: () => _showRatingDialog(context),
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('Beri Rating'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8),
                  ),
                ),
            ],
          ),
          if (status == 'delivered' || status == 'cancelled') ...[
            const SizedBox(height: AppTheme.space8),
            SizedBox(
              width: double.infinity,
              child: SPButton(
                label: 'Pesan Lagi',
                icon: Icons.replay,
                onPressed: () => context.push('/browse-merchants'),
                type: SPButtonType.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date.toString());
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatPrice(dynamic price) {
    final amount = price is int ? price : (price as num?)?.toInt() ?? 0;
    final str = amount.toString();
    final buffer = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.primaryGreen;
      case 'in_transit':
      case 'processing':
        return Colors.blue;
      case 'cancelled':
        return AppTheme.error;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Terkirim';
      case 'in_transit':
        return 'Diantar';
      case 'processing':
        return 'Diproses';
      case 'cancelled':
        return 'Dibatalkan';
      case 'pending':
        return 'Menunggu';
      default:
        return status;
    }
  }

  void _showRatingDialog(BuildContext context) {
    int rating = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Beri Rating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bagaimana pesanan Anda?'),
              const SizedBox(height: AppTheme.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star
                          : Icons.star_border,
                      color: AppTheme.accent,
                      size: 36,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () => Navigator.pop(ctx)
                  : null,
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Market Prices Section ────────────────────────────────────────────────

class _MarketPricesSection extends StatelessWidget {
  final AsyncValue<List<dynamic>> pricesAsync;

  const _MarketPricesSection({required this.pricesAsync});

  static const Map<String, String> _productEmojis = {
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
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Harga Pasar Hari Ini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            TextButton(
              onPressed: () => context.push('/prices'),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        pricesAsync.when(
          data: (prices) {
            if (prices.isEmpty) {
              return const SPCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.space16),
                    child: Text(
                      'Belum ada data harga',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              );
            }
            final top5 = prices.take(5).toList();
            return Column(
              children: top5.map((price) {
                final name = price['product_name'] ?? 'Produk';
                final currentPrice = price['price'];
                final trend =
                    (price['trend'] ?? 'stable').toString();
                final unit = price['unit'] ?? 'kg';
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

                String emoji = '🥗';
                final lower = name.toLowerCase();
                for (final entry in _productEmojis.entries) {
                  if (lower.contains(entry.key)) {
                    emoji = entry.value;
                    break;
                  }
                }

                String formattedPrice = 'Rp -';
                if (currentPrice != null) {
                  final p = currentPrice is int
                      ? currentPrice
                      : (currentPrice as num).toInt();
                  final str = p.toString();
                  final buf = StringBuffer('Rp ');
                  for (int i = 0; i < str.length; i++) {
                    if (i > 0 && (str.length - i) % 3 == 0) {
                      buf.write('.');
                    }
                    buf.write(str[i]);
                  }
                  formattedPrice = buf.toString();
                }

                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppTheme.space8),
                  child: SPCard(
                    onTap: () {
                      final productId =
                          price['product_id']?.toString() ?? '';
                      context.push('/price-compare',
                          extra: productId);
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                    child: Row(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
                              formattedPrice,
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
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          error: (_, __) => const SPCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.space12),
                child: Text(
                  'Gagal memuat harga',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Featured Pedagang Section (when no subscription) ─────────────────────

class _FeaturedPedagangSection extends StatelessWidget {
  final List<_FeaturedPedagang> _featured = const [
    _FeaturedPedagang(
      name: 'Pak Budi Sayur',
      rating: 4.8,
      distance: '1.2 km',
      subscribers: 45,
      tagline: 'Sayuran segar setiap hari dari kebun sendiri',
    ),
    _FeaturedPedagang(
      name: 'Ibu Ani Segar',
      rating: 4.6,
      distance: '2.0 km',
      subscribers: 32,
      tagline: 'Buah & sayur organik pilihan',
    ),
    _FeaturedPedagang(
      name: 'Bang Jaya Tani',
      rating: 4.5,
      distance: '3.5 km',
      subscribers: 28,
      tagline: 'Harga grosir, kualitas premium',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pedagang Terdekat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _featured.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTheme.space12),
            itemBuilder: (context, index) {
              final pedagang = _featured[index];
              return SizedBox(
                width: 220,
                child: SPCard(
                  onTap: () => context.push('/browse-merchants'),
                  padding: const EdgeInsets.all(AppTheme.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SPAvatar(
                            name: pedagang.name,
                            radius: 20,
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pedagang.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14,
                                        color: AppTheme.accent),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${pedagang.rating}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.location_on,
                                        size: 14,
                                        color: AppTheme.textSecondary),
                                    Text(
                                      pedagang.distance,
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
                      ),
                      const SizedBox(height: AppTheme.space8),
                      Text(
                        pedagang.tagline,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.people,
                              size: 14,
                              color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            '${pedagang.subscribers} pelanggan',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  }
}

class _FeaturedPedagang {
  final String name;
  final double rating;
  final String distance;
  final int subscribers;
  final String tagline;

  const _FeaturedPedagang({
    required this.name,
    required this.rating,
    required this.distance,
    required this.subscribers,
    required this.tagline,
  });
}

// ── Pending Ratings Card ─────────────────────────────────────────────────

class _PendingRatingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderHistoryProvider('delivered'));

    return ordersAsync.when(
      data: (orders) {
        final unrated =
            orders.where((o) => !(o.isRated ?? false)).toList();
        if (unrated.isEmpty) return const SizedBox.shrink();

        return SPCard(
          onTap: () => context.push('/order-history'),
          color: AppTheme.accent.withOpacity(0.06),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ada ${unrated.length} pesanan menunggu rating',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    const Text(
                      'Beri rating untuk membantu pedagang lain!',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppTheme.textSecondary),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
