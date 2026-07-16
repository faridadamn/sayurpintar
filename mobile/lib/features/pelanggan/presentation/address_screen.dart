import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/pelanggan/data/pelanggan_repository.dart';
import 'package:sayurpintar/features/pelanggan/providers/pelanggan_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Pengiriman'),
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return SPEmptyState(
              icon: Icons.location_off_outlined,
              title: 'Belum ada alamat',
              message: 'Tambahkan alamat pengiriman untuk memudahkan pesanan.',
              actionLabel: 'Tambah Alamat',
              onAction: () => _openAddAddress(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(addressesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.space8,
                horizontal: AppTheme.space16,
              ),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                return _AddressCard(
                  address: addresses[index],
                  onEdit: () => _openEditAddress(context, addresses[index]),
                  onDelete: () => _confirmDelete(context, addresses[index]),
                  onSetDefault: () => _setDefault(addresses[index].id),
                );
              },
            ),
          );
        },
        loading: () => const SPLoading(message: 'Memuat alamat...'),
        error: (e, _) => SPErrorWidget(
          message: 'Gagal memuat alamat.',
          onRetry: () => ref.invalidate(addressesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAddress(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Alamat'),
      ),
    );
  }

  void _openAddAddress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (_) => const _AddressFormSheet(),
    ).then((_) => ref.invalidate(addressesProvider));
  }

  void _openEditAddress(BuildContext context, DeliveryAddress address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (_) => _AddressFormSheet(existing: address),
    ).then((_) => ref.invalidate(addressesProvider));
  }

  Future<void> _confirmDelete(
      BuildContext context, DeliveryAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat?'),
        content: Text(
          'Alamat "${address.label}" akan dihapus. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(pelangganRepositoryProvider);
        await repo.deleteAddress(address.id);
        ref.invalidate(addressesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alamat berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus alamat')),
          );
        }
      }
    }
  }

  Future<void> _setDefault(String id) async {
    try {
      final repo = ref.read(pelangganRepositoryProvider);
      await repo.setDefaultAddress(id);
      ref.invalidate(addressesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat utama berhasil diubah')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah alamat utama')),
        );
      }
    }
  }
}

// ── Address Card ─────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final DeliveryAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final labelIcon = _getLabelIcon(address.label);

    return SPCard(
      margin: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  labelIcon,
                  color: AppTheme.primaryGreen,
                  size: 20,
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
                          address.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppTheme.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: const Text(
                              'Utama',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      address.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address.notes != null && address.notes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      address.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              if (!address.isDefault)
                TextButton.icon(
                  onPressed: onSetDefault,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Jadikan Utama'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space8,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: AppTheme.textSecondary),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.error),
                tooltip: 'Hapus',
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'rumah':
        return Icons.home;
      case 'kantor':
        return Icons.work;
      default:
        return Icons.location_on;
    }
  }
}

// ── Address Form Sheet ───────────────────────────────────────────────────

class _AddressFormSheet extends ConsumerStatefulWidget {
  final DeliveryAddress? existing;

  const _AddressFormSheet({this.existing});

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  String _selectedLabel = 'Rumah';
  bool _isDefault = false;
  bool _isSaving = false;

  final List<_LabelOption> _labelOptions = const [
    _LabelOption(label: 'Rumah', icon: Icons.home),
    _LabelOption(label: 'Kantor', icon: Icons.work),
    _LabelOption(label: 'Lainnya', icon: Icons.location_on),
  ];

  @override
  void initState() {
    super.initState();
    _addressCtrl =
        TextEditingController(text: widget.existing?.address ?? '');
    _notesCtrl =
        TextEditingController(text: widget.existing?.notes ?? '');
    _selectedLabel = widget.existing?.label ?? 'Rumah';
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space16,
        right: AppTheme.space16,
        top: AppTheme.space16,
        bottom: bottomPadding + AppTheme.space16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ───────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space16),

            // ── Title ────────────────────────────────────────────
            Text(
              isEditing ? 'Edit Alamat' : 'Tambah Alamat',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: AppTheme.space20),

            // ── Map placeholder ──────────────────────────────────
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.divider,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    const Text(
                      'Ketuk untuk pilih lokasi di peta',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    TextButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Gunakan Lokasi Saat Ini'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space16),

            // ── Label selector ───────────────────────────────────
            const Text(
              'Label',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              children: _labelOptions.map((opt) {
                final isSelected = _selectedLabel == opt.label;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: opt != _labelOptions.last
                          ? AppTheme.space8
                          : 0,
                    ),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLabel = opt.label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreen.withOpacity(0.1)
                              : Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              opt.icon,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(height: AppTheme.space4),
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.space16),

            // ── Address input ────────────────────────────────────
            SPInput(
              label: 'Alamat Lengkap',
              hint: 'Jl. Contoh No. 123, RT/RW, Kelurahan...',
              controller: _addressCtrl,
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Alamat tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.space16),

            // ── Notes input ──────────────────────────────────────
            SPInput(
              label: 'Catatan (opsional)',
              hint: 'Patokan, warna rumah, dll.',
              controller: _notesCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.space16),

            // ── Set as default ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jadikan Alamat Utama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Digunakan sebagai alamat default',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isDefault,
                  onChanged: (val) => setState(() => _isDefault = val),
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space24),

            // ── Save button ──────────────────────────────────────
            SPButton(
              label: isEditing ? 'Simpan Perubahan' : 'Simpan Alamat',
              icon: Icons.check,
              isLoading: _isSaving,
              onPressed: _saveAddress,
            ),
          ],
        ),
      ),
    );
  }

  void _pickLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pemetaan lokasi akan segera tersedia'),
      ),
    );
  }

  void _useCurrentLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mengambil lokasi saat ini...'),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(pelangganRepositoryProvider);
      final address = DeliveryAddress(
        id: widget.existing?.id ?? '',
        label: _selectedLabel,
        address: _addressCtrl.text.trim(),
        latitude: widget.existing?.latitude,
        longitude: widget.existing?.longitude,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        isDefault: _isDefault,
      );

      if (widget.existing != null) {
        await repo.updateAddress(widget.existing!.id, address);
      } else {
        await repo.addAddress(address);
      }

      if (_isDefault && widget.existing?.id != null) {
        await repo.setDefaultAddress(widget.existing!.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'Alamat berhasil diperbarui'
                  : 'Alamat berhasil ditambahkan',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan alamat')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _LabelOption {
  final String label;
  final IconData icon;

  const _LabelOption({required this.label, required this.icon});
}
