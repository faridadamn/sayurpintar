import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';
import 'package:sayurpintar/features/dashboard/providers/dashboard_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';

// ── Shared Profile Screen (works for both pedagang & pelanggan) ──────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isPedagang = user?.isPedagang ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: () => _showEditProfile(context, user),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
        children: [
          // ── Profile Header ──────────────────────────────────────
          _ProfileHeader(user: user, isPedagang: isPedagang),
          const SizedBox(height: AppTheme.space16),

          // ── Role-specific sections ──────────────────────────────
          if (isPedagang) ...[
            _buildPedagangSections(context, ref),
          ] else ...[
            _buildPelangganSections(context),
          ],

          // ── Common sections ─────────────────────────────────────
          const Divider(height: AppTheme.space32),
          _buildCommonSections(context, ref),
          const SizedBox(height: AppTheme.space24),
        ],
      ),
    );
  }

  // ── Pedagang Sections ────────────────────────────────────────────────

  Widget _buildPedagangSections(
      BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics
        _SectionTitle(title: 'Statistik Saya', icon: Icons.analytics),
        summaryAsync.when(
          data: (summary) => _StatisticsGrid(summary: summary),
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppTheme.space8),

        // Reward Badge
        _RewardBadgeCard(),
        const SizedBox(height: AppTheme.space8),

        // My Packages
        _MenuTile(
          icon: Icons.inventory_2_outlined,
          title: 'Paket Saya',
          subtitle: 'Kelola paket langganan',
          onTap: () => context.push('/subscriptions/packages'),
        ),

        // Subscribers
        _MenuTile(
          icon: Icons.people_outline,
          title: 'Pelanggan Saya',
          subtitle: 'Lihat daftar pelanggan',
          onTap: () => context.push('/subscriptions/subscribers'),
        ),

        // Piutang
        _MenuTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Piutang',
          subtitle: 'Kelola pembayaran pelanggan',
          onTap: () {},
        ),

        // Daily Summary
        _MenuTile(
          icon: Icons.assessment_outlined,
          title: 'Ringkasan Harian',
          subtitle: 'Lihat ringkasan transaksi',
          onTap: () => context.push('/daily-summary'),
        ),

        // Price Management
        _MenuTile(
          icon: Icons.price_change_outlined,
          title: 'Kelola Harga',
          subtitle: 'Input & update harga pasar',
          onTap: () => context.push('/prices/submit'),
        ),
        const SizedBox(height: AppTheme.space8),
      ],
    );
  }

  // ── Pelanggan Sections ───────────────────────────────────────────────

  Widget _buildPelangganSections(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My Addresses
        _SectionTitle(title: 'Alamat Saya', icon: Icons.location_on_outlined),
        _AddressCard(
          label: 'Rumah',
          address: 'Jl. Contoh No. 123, Jakarta',
          isDefault: true,
          onEdit: () {},
          onDelete: () {},
        ),
        const SizedBox(height: AppTheme.space8),

        // My Subscriptions
        _MenuTile(
          icon: Icons.subscriptions_outlined,
          title: 'Langganan Saya',
          subtitle: 'Kelola langganan aktif',
          onTap: () => context.push('/my-subscriptions'),
        ),

        // Order History
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Riwayat Pesanan',
          subtitle: 'Lihat semua pesanan',
          onTap: () => context.push('/order-history'),
        ),

        // Payment Methods
        _MenuTile(
          icon: Icons.payment_outlined,
          title: 'Metode Pembayaran',
          subtitle: 'Kelola metode bayar',
          onTap: () {},
        ),
        const SizedBox(height: AppTheme.space8),
      ],
    );
  }

  // ── Common Sections ──────────────────────────────────────────────────

  Widget _buildCommonSections(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _MenuTile(
          icon: Icons.notifications_outlined,
          title: 'Pengaturan Notifikasi',
          subtitle: 'Atur notifikasi',
          onTap: () {},
        ),
        _MenuTile(
          icon: Icons.language_outlined,
          title: 'Bahasa',
          subtitle: 'Indonesia',
          onTap: () {},
        ),
        _MenuTile(
          icon: Icons.help_outline,
          title: 'Bantuan & FAQ',
          subtitle: 'Pusat bantuan',
          onTap: () {},
        ),
        _MenuTile(
          icon: Icons.info_outline,
          title: 'Tentang SayurPintar',
          subtitle: 'Versi 1.0.0',
          onTap: () => _showAboutDialog(context),
        ),
        const SizedBox(height: AppTheme.space16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
          ),
          child: SPButton(
            label: 'Keluar',
            icon: Icons.logout,
            type: SPButtonType.secondary,
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ),
      ],
    );
  }

  // ── Edit Profile ─────────────────────────────────────────────────────

  void _showEditProfile(BuildContext context, dynamic user) {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.space16,
          right: AppTheme.space16,
          top: AppTheme.space24,
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Center(
              child: Stack(
                children: [
                  SPAvatar(
                    imageUrl: user?.avatarUrl,
                    name: user?.name ?? 'User',
                    radius: 48,
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            SPButton(
              label: 'Simpan',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ── About Dialog ─────────────────────────────────────────────────────

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.eco,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            const Text(
              'SayurPintar',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi 1.0.0'),
            SizedBox(height: AppTheme.space8),
            Text(
              'SayurPintar adalah platform yang menghubungkan '
              'pedagang sayur dengan pelanggan untuk langganan '
              'sayuran segar harian.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: AppTheme.space12),
            Text(
              '© 2026 SayurPintar',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── Logout Dialog ────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content:
            const Text('Anda akan keluar dari akun. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header ───────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final bool isPedagang;

  const _ProfileHeader({required this.user, required this.isPedagang});

  @override
  Widget build(BuildContext context) {
    final roleLabel = isPedagang ? '🚲 Pedagang' : '🛒 Pelanggan';

    return SPCard(
      color: AppTheme.primaryGreen.withOpacity(0.06),
      child: Row(
        children: [
          Stack(
            children: [
              SPAvatar(
                imageUrl: user?.avatarUrl,
                name: user?.name ?? 'User',
                radius: 36,
                backgroundColor: AppTheme.primaryGreen,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Pengguna',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  user?.phone ?? '-',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
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

// ── Section Title ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: AppTheme.space8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Statistics Grid ──────────────────────────────────────────────────────

class _StatisticsGrid extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _StatisticsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Total Pesanan',
              value: '${summary['total_orders'] ?? 0}',
              icon: Icons.receipt_long,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: _StatCard(
              label: 'Pelanggan',
              value: '${summary['subscribers'] ?? 0}',
              icon: Icons.people,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: _StatCard(
              label: 'Pendapatan',
              value: _formatShort(summary['revenue'] ?? summary['omset'] ?? 0),
              icon: Icons.attach_money,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatShort(dynamic value) {
    final amount = value is int ? value : (value as num?)?.toInt() ?? 0;
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp $amount';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppTheme.space4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reward Badge Card ────────────────────────────────────────────────────

class _RewardBadgeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: SPCard(
        color: AppTheme.accent.withOpacity(0.08),
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.orange,
                size: 32,
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge: Pedagang Rajin',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      const Text(
                        '1.250 poin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        'Level 3',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space4),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 6,
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '750 poin lagi ke Level 4',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.push('/rewards'),
              icon: const Icon(Icons.chevron_right),
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Address Card ─────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final String label;
  final String address;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.label,
    required this.address,
    required this.isDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: SPCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(AppTheme.space12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                label == 'Rumah'
                    ? Icons.home_outlined
                    : Icons.location_on_outlined,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: AppTheme.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull),
                          ),
                          child: const Text(
                            'Utama',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete', child: Text('Hapus')),
              ],
              icon: const Icon(Icons.more_vert,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu Tile ────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.space8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}
