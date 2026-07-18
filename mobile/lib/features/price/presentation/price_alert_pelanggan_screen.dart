import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/providers/price_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_empty_state.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PriceAlertPelangganScreen extends ConsumerStatefulWidget {
  const PriceAlertPelangganScreen({super.key});

  @override
  ConsumerState<PriceAlertPelangganScreen> createState() =>
      _PriceAlertPelangganScreenState();
}

class _PriceAlertPelangganScreenState
    extends ConsumerState<PriceAlertPelangganScreen> {
  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(priceAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Harga'),
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return SPEmptyState(
              icon: Icons.notifications_none,
              title: 'Belum Ada Alert',
              message:
                  'Buat alert untuk mendapat notifikasi saat harga berubah.',
              actionLabel: 'Buat Alert Baru',
              onAction: () => _showCreateAlertSheet(context),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.space16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return _AlertCard(
                alert: alert,
                onDelete: () => _deleteAlert(alert['id']),
              );
            },
          );
        },
        loading: () => const SPLoading(message: 'Memuat alert...'),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: AppTheme.space12),
              Text('Gagal memuat alert: $e', textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.space16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(priceAlertsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlertSheet(context),
        icon: const Icon(Icons.add_alert),
        label: const Text('Buat Alert'),
      ),
    );
  }

  void _deleteAlert(String? alertId) async {
    if (alertId == null) return;
    try {
      await ref.read(priceAlertsProvider.notifier).deleteAlert(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert berhasil dihapus'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus alert: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showCreateAlertSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => const _CreateAlertSheet(),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final dynamic alert;
  final VoidCallback onDelete;

  const _AlertCard({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final productName = alert['product_name'] ?? 'Produk';
    final threshold = alert['threshold_percent'] ?? 10;
    final direction = (alert['direction'] ?? 'both').toString();
    final isActive = alert['is_active'] != false;

    final directionLabel = direction == 'up'
        ? '⬆️ Naik'
        : direction == 'down'
            ? '⬇️ Turun'
            : '↕️ Keduanya';
    final directionColor = direction == 'up'
        ? AppTheme.error
        : direction == 'down'
            ? AppTheme.primaryGreen
            : Colors.blue;

    return Dismissible(
      key: Key(alert['id']?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Alert?'),
            content: Text('Hapus alert harga untuk $productName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.space20),
        margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16, vertical: AppTheme.space8),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: SPCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: directionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.notifications_active,
                color: directionColor,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: directionColor.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          directionLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: directionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        '±$threshold%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isActive,
                  onChanged: (v) {
                    // Toggle active state
                  },
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAlertSheet extends ConsumerStatefulWidget {
  const _CreateAlertSheet();

  @override
  ConsumerState<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<_CreateAlertSheet> {
  String? _selectedProductId;
  String? _selectedProductName;
  double _threshold = 10;
  String _direction = 'both';

  static const Map<String, String> _directionOptions = {
    'up': '⬆️ Naik',
    'down': '⬇️ Turun',
    'both': '↕️ Keduanya',
  };

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space16,
        right: AppTheme.space16,
        top: AppTheme.space16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          const Text(
            'Buat Alert Baru',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: AppTheme.space16),

          // Product selector
          const Text(
            'Pilih Produk',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          productsAsync.when(
            data: (products) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.divider),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedProductId,
                    hint: const Text('Pilih produk...'),
                    items: products.map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem(
                        value: p['id']?.toString(),
                        child: Text(p['name'] ?? p['product_name'] ?? ''),
                        onTap: () {
                          _selectedProductName =
                              p['name'] ?? p['product_name'] ?? '';
                        },
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Gagal memuat produk'),
          ),
          const SizedBox(height: AppTheme.space16),

          // Threshold slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Threshold Perubahan',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${_threshold.toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 5,
            max: 50,
            divisions: 9,
            activeColor: AppTheme.primaryGreen,
            label: '${_threshold.toInt()}%',
            onChanged: (v) => setState(() => _threshold = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('5%',
                  style:
                      TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('50%',
                  style:
                      TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: AppTheme.space16),

          // Direction selector
          const Text(
            'Arah Perubahan',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: _directionOptions.entries.map((entry) {
              final selected = _direction == entry.key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _direction = entry.key),
                    selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppTheme.primaryGreen
                          : AppTheme.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      side: BorderSide(
                        color:
                            selected ? AppTheme.primaryGreen : AppTheme.divider,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.space24),

          // Submit button
          SPButton(
            label: 'Simpan Alert',
            icon: Icons.check,
            onPressed: _selectedProductId == null ? null : () => _submitAlert(),
          ),
        ],
      ),
    );
  }

  void _submitAlert() async {
    if (_selectedProductId == null) return;
    try {
      await ref.read(priceAlertsProvider.notifier).createAlert({
        'product_id': _selectedProductId,
        'product_name': _selectedProductName ?? '',
        'threshold_percent': _threshold.toInt(),
        'direction': _direction,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert berhasil dibuat!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat alert: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
