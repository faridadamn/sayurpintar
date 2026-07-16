import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';

// ── Pelanggan Profile Screen ─────────────────────────────────────────────

class PelangganProfileScreen extends ConsumerWidget {
  const PelangganProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
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
          _ProfileHeader(user: user),
          const SizedBox(height: AppTheme.space16),

          // ── My Addresses ────────────────────────────────────────
          _SectionHeader(
            title: 'Alamat Saya',
            icon: Icons.location_on_outlined,
            onAdd: () => _showAddAddress(context),
          ),
          _AddressCard(
            label: 'Rumah',
            address: user?.address ?? 'Belum diatur',
            isDefault: true,
            onEdit: () => _showEditAddress(context),
            onDelete: () => _showDeleteConfirm(context, 'alamat'),
          ),
          _AddressCard(
            label: 'Kantor',
            address: 'Jl. Sudirman No. 123, Jakarta',
            isDefault: false,
            onEdit: () => _showEditAddress(context),
            onDelete: () => _showDeleteConfirm(context, 'alamat'),
          ),
          const SizedBox(height: AppTheme.space8),

          // ── Payment Methods ─────────────────────────────────────
          _SectionHeader(
            title: 'Metode Pembayaran',
            icon: Icons.payment,
            onAdd: () {},
          ),
          _PaymentMethodCard(
            icon: Icons.money,
            label: 'Tunai (COD)',
            subtitle: 'Bayar saat terima pesanan',
            isSelected: true,
          ),
          _PaymentMethodCard(
            icon: Icons.account_balance,
            label: 'Transfer Bank',
            subtitle: 'BCA •••• 1234',
            isSelected: false,
          ),
          _PaymentMethodCard(
            icon: Icons.account_balance_wallet,
            label: 'E-Wallet',
            subtitle: 'GoPay / OVO / Dana',
            isSelected: false,
          ),
          const SizedBox(height: AppTheme.space8),

          // ── My Subscriptions ────────────────────────────────────
          _MenuTile(
            icon: Icons.subscriptions_outlined,
            title: 'Langganan Saya',
            subtitle: 'Kelola langganan aktif',
            onTap: () => context.push('/my-subscriptions'),
          ),

          // ── Order History ───────────────────────────────────────
          _MenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'Riwayat Pesanan',
            subtitle: 'Lihat semua pesanan',
            onTap: () => context.push('/order-history'),
          ),

          const Divider(height: AppTheme.space32),

          // ── Notification Settings ───────────────────────────────
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: 'Pengaturan Notifikasi',
            subtitle: 'Atur notifikasi pesanan & harga',
            onTap: () => _showNotificationSettings(context),
          ),

          // ── Language Settings ───────────────────────────────────
          _MenuTile(
            icon: Icons.language_outlined,
            title: 'Bahasa',
            subtitle: 'Indonesia',
            onTap: () => _showLanguageSettings(context),
          ),

          // ── Help & Support ──────────────────────────────────────
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Bantuan & Dukungan',
            subtitle: 'FAQ, hubungi kami',
            onTap: () {},
          ),

          const Divider(height: AppTheme.space32),

          // ── Logout ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space8,
            ),
            child: SPButton(
              label: 'Keluar',
              icon: Icons.logout,
              type: SPButtonType.secondary,
              onPressed: () => _showLogoutDialog(context, ref),
            ),
          ),
          const SizedBox(height: AppTheme.space24),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context, dynamic user) {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
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
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space24,
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'No. Telepon',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              readOnly: true,
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

  void _showAddAddress(BuildContext context) {
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
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambah Alamat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Label (Rumah, Kantor, dll)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Alamat Lengkap',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.space12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Catatan untuk kurir (opsional)',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            SPButton(
              label: 'Simpan Alamat',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAddress(BuildContext context) {
    _showAddAddress(context);
  }

  void _showDeleteConfirm(BuildContext context, String item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $item?'),
        content: Text('Anda yakin ingin menghapus $item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    bool orderNotif = true;
    bool priceAlert = true;
    bool promo = false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengaturan Notifikasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              SwitchListTile(
                title: const Text('Notifikasi Pesanan'),
                subtitle: const Text('Status pengiriman & pengingat'),
                value: orderNotif,
                onChanged: (v) => setState(() => orderNotif = v),
                activeColor: AppTheme.primaryGreen,
              ),
              SwitchListTile(
                title: const Text('Peringatan Harga'),
                subtitle: const Text('Notifikasi perubahan harga'),
                value: priceAlert,
                onChanged: (v) => setState(() => priceAlert = v),
                activeColor: AppTheme.primaryGreen,
              ),
              SwitchListTile(
                title: const Text('Promo & Penawaran'),
                subtitle: const Text('Diskon dan penawaran khusus'),
                value: promo,
                onChanged: (v) => setState(() => promo = v),
                activeColor: AppTheme.primaryGreen,
              ),
              const SizedBox(height: AppTheme.space16),
              SPButton(
                label: 'Simpan',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Bahasa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            _LanguageOption(
              language: 'Indonesia',
              flag: '🇮🇩',
              isSelected: true,
              onTap: () => Navigator.pop(ctx),
            ),
            _LanguageOption(
              language: 'English',
              flag: '🇺🇸',
              isSelected: false,
              onTap: () => Navigator.pop(ctx),
            ),
            _LanguageOption(
              language: 'Melayu',
              flag: '🇲🇾',
              isSelected: false,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text(
            'Anda akan keluar dari akun. Lanjutkan?'),
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

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return SPCard(
      color: AppTheme.primaryGreen.withOpacity(0.06),
      child: Row(
        children: [
          Stack(
            children: [
              SPAvatar(
                imageUrl: user?.avatarUrl,
                name: user?.name ?? 'Pelanggan',
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
                  user?.name ?? 'Pelanggan',
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
                  child: const Text(
                    '🛒 Pelanggan',
                    style: TextStyle(
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

// ── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.onAdd,
  });

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
          const Spacer(),
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryGreen,
              iconSize: 24,
            ),
        ],
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
    return SPCard(
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
                  : label == 'Kantor'
                      ? Icons.business_outlined
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
                value: 'edit',
                child: Text('Edit'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Hapus'),
              ),
            ],
            icon: const Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Method Card ──────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SPCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryGreen.withOpacity(0.12)
                  : AppTheme.background,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
        ],
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
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

// ── Language Option ──────────────────────────────────────────────────────

class _LanguageOption extends StatelessWidget {
  final String language;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.language,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(
        language,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen)
          : null,
      onTap: onTap,
    );
  }
}
