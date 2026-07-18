import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/common/widgets/rating_widget.dart';
import 'package:sayurpintar/features/pelanggan/data/pelanggan_repository.dart';
import 'package:sayurpintar/features/pelanggan/providers/pelanggan_provider.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantDetailScreen extends ConsumerStatefulWidget {
  final String merchantId;

  const MerchantDetailScreen({super.key, required this.merchantId});

  @override
  ConsumerState<MerchantDetailScreen> createState() =>
      _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends ConsumerState<MerchantDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final merchantAsync =
        ref.watch(merchantDetailProvider(widget.merchantId));

    return Scaffold(
      body: merchantAsync.when(
        data: (merchant) => _MerchantContent(merchant: merchant),
        loading: () => const SPLoading(message: 'Memuat profil pedagang...'),
        error: (e, _) => SPErrorWidget(
          message: 'Gagal memuat profil pedagang.',
          onRetry: () =>
              ref.invalidate(merchantDetailProvider(widget.merchantId)),
        ),
      ),
    );
  }
}

class _MerchantContent extends StatelessWidget {
  final MerchantDetail merchant;

  const _MerchantContent({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Hero Header ──────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppTheme.space24),
                    SPAvatar(
                      imageUrl: merchant.avatarUrl,
                      name: merchant.name,
                      radius: 40,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            merchant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (merchant.isVerified) ...[
                          const SizedBox(width: AppTheme.space8),
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    RatingWidget(
                      rating: merchant.rating.round(),
                      size: 18,
                      activeColor: AppTheme.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stats Row ────────────────────────────────────
                _StatsRow(merchant: merchant),
                const SizedBox(height: AppTheme.space16),

                // ── Description ──────────────────────────────────
                if (merchant.description != null &&
                    merchant.description!.isNotEmpty) ...[
                  Text(
                    merchant.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                ],

                // ── CTA Button ───────────────────────────────────
                SPButton(
                  label: 'Mulai Berlangganan',
                  icon: Icons.shopping_bag_outlined,
                  onPressed: () {
                    if (merchant.packages.isNotEmpty) {
                      context.push('/subscribe', extra: merchant.packages.first);
                    }
                  },
                ),
                const SizedBox(height: AppTheme.space24),

                // ── Available Packages ───────────────────────────
                if (merchant.packages.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Paket Tersedia',
                    count: merchant.packages.length,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  ...merchant.packages.map(
                    (pkg) => _PackageCard(
                      package: pkg,
                      onTap: () =>
                          context.push('/subscribe', extra: pkg),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                ],

                // ── Top Products ─────────────────────────────────
                if (merchant.topProducts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Produk Terlaris',
                    count: merchant.topProducts.length,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: merchant.topProducts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppTheme.space12),
                      itemBuilder: (context, index) {
                        return _ProductCard(
                            product: merchant.topProducts[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                ],

                // ── Contact Section ──────────────────────────────
                _ContactSection(merchant: merchant),
                const SizedBox(height: AppTheme.space32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final MerchantDetail merchant;

  const _StatsRow({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.shopping_bag_outlined,
            value: '${merchant.totalOrders}',
            label: 'Pesanan',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.divider,
        ),
        Expanded(
          child: _StatItem(
            icon: Icons.people_outline,
            value: '${merchant.subscriberCount}',
            label: 'Pelanggan',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.divider,
        ),
        Expanded(
          child: _StatItem(
            icon: Icons.star_outline,
            value: merchant.rating.toStringAsFixed(1),
            label: 'Rating',
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(height: AppTheme.space4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppTheme.space8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Package Card ─────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final SubscriptionPackage package;
  final VoidCallback onTap;

  const _PackageCard({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priceStr = _formatPrice(package.price);

    return SPCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    if (package.description != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        package.description!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  Text(
                    '/ ${package.frequencyText}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          // Items preview
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space4,
            children: package.items.take(4).map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                  vertical: AppTheme.space4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  '${item.name} ${item.qty}${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryDark,
                  ),
                ),
              );
            }).toList(),
          ),
          if (package.items.length > 4) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              '+${package.items.length - 4} item lainnya',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: AppTheme.space4),
              Text(
                'Kirim: ${package.deliveryDaysText}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (package.subscriberCount != null) ...[
                const Icon(Icons.people,
                    size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: AppTheme.space4),
                Text(
                  '${package.subscriberCount}/${package.maxSubscribers}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buf = StringBuffer('Rp ');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ── Product Card ─────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final MerchantProduct product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image / placeholder
          Container(
            height: 70,
            width: double.infinity,
            color: AppTheme.primaryGreen.withOpacity(0.08),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.eco,
                      color: AppTheme.primaryGreen,
                      size: 32,
                    ),
                  )
                : const Icon(
                    Icons.eco,
                    color: AppTheme.primaryGreen,
                    size: 32,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.formattedPrice,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
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

// ── Contact Section ──────────────────────────────────────────────────────

class _ContactSection extends StatelessWidget {
  final MerchantDetail merchant;

  const _ContactSection({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return SPCard(
      color: AppTheme.primaryGreen.withOpacity(0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hubungi Pedagang',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          if (merchant.address != null && merchant.address!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    merchant.address!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
          ],
          if (merchant.phone != null && merchant.phone!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openWhatsApp(merchant.phone!),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Hubungi via WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
