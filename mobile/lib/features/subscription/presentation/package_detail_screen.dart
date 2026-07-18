import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_bottom_sheet.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';
import 'package:sayurpintar/shared/widgets/sp_error_widget.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class PackageDetailScreen extends ConsumerWidget {
  final String packageId;

  const PackageDetailScreen({super.key, required this.packageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageAsync = ref.watch(packageDetailProvider(packageId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Paket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan',
            onPressed: () => _sharePackage(context, packageAsync),
          ),
        ],
      ),
      body: packageAsync.when(
        loading: () => const SPLoading(message: 'Memuat detail paket...'),
        error: (error, _) => SPErrorWidget(
          message: 'Gagal memuat paket: $error',
          onRetry: () => ref.invalidate(packageDetailProvider(packageId)),
        ),
        data: (package) => _PackageDetailBody(
          package: package,
          onEdit: () => context.push(
            '/subscriptions/edit-package',
            extra: package.id,
          ),
          onDelete: () => _confirmDelete(context, ref, package),
        ),
      ),
    );
  }

  void _sharePackage(
      BuildContext context, AsyncValue<SubscriptionPackage> async) {
    final pkg = async.valueOrNull;
    if (pkg == null) return;

    final text = StringBuffer()
      ..writeln('📦 ${pkg.name}')
      ..writeln('💰 ${_formatCurrency(pkg.price)} / pengiriman')
      ..writeln('📅 ${pkg.frequencyText} — ${pkg.deliveryDaysText}')
      ..writeln()
      ..writeln('Isi paket:');
    for (final item in pkg.items) {
      text.writeln('  • ${item.name} ${item.qty}${item.unit}');
    }
    text
      ..writeln()
      ..writeln('Langganan di SayurPintar! 🥬');

    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Info paket disalin ke clipboard'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  static String _formatCurrency(double value) {
    final parts = value.toInt().toString().split('');
    final result = <String>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      result.insert(0, parts[i]);
      if ((parts.length - i) % 3 == 0 && i != 0) {
        result.insert(0, '.');
      }
    }
    return 'Rp ${result.join('')}';
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPackage pkg,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text(
          'Yakin ingin menghapus "${pkg.name}"? '
          'Pelanggan yang berlangganan akan terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(subscriptionRepositoryProvider);
                await repo.deletePackage(pkg.id);
                ref.invalidate(myPackagesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Paket "${pkg.name}" dihapus'),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ── Package Detail Body ──────────────────────────────────────────────────────

class _PackageDetailBody extends StatelessWidget {
  final SubscriptionPackage package;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PackageDetailBody({
    required this.package,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatCurrency(double value) {
    final parts = value.toInt().toString().split('');
    final result = <String>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      result.insert(0, parts[i]);
      if ((parts.length - i) % 3 == 0 && i != 0) {
        result.insert(0, '.');
      }
    }
    return 'Rp ${result.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    final estimatedMonthly = package.price *
        package.deliveryDays.length *
        4; // approx 4 weeks

    return ListView(
      padding: const EdgeInsets.all(AppTheme.space16),
      children: [
        // ── Header Card ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      package.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: package.isActive
                          ? Colors.white.withOpacity(0.2)
                          : Colors.red.withOpacity(0.3),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      package.isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        color: package.isActive
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (package.description != null &&
                  package.description!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space8),
                Text(
                  package.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.space16),
              Text(
                '${_formatCurrency(package.price)} / pengiriman',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                '± ${_formatCurrency(estimatedMonthly)} / bulan',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.space16),

        // ── Info Rows ───────────────────────────────────────────────
        SPCard(
          margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.repeat,
                label: 'Frekuensi',
                value: package.frequencyText,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Hari Pengiriman',
                value: package.deliveryDaysText,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.people,
                label: 'Pelanggan',
                value: package.maxSubscribers > 0
                    ? '${package.subscriberCount ?? 0} / ${package.maxSubscribers}'
                    : '${package.subscriberCount ?? 0} (tidak terbatas)',
              ),
              if (package.maxSubscribers > 0) ...[
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kuota Terpakai',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${((package.subscriberCount ?? 0) / package.maxSubscribers * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
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
                          value: (package.subscriberCount ?? 0) /
                              package.maxSubscribers,
                          backgroundColor:
                              AppTheme.divider.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            (package.subscriberCount ?? 0) >=
                                    package.maxSubscribers
                                ? AppTheme.error
                                : AppTheme.primaryGreen,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Items ───────────────────────────────────────────────────
        const SizedBox(height: AppTheme.space16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
          child: Row(
            children: [
              const Text(
                'Isi Paket',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${package.items.length} item',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        SPCard(
          margin: const EdgeInsets.symmetric(vertical: AppTheme.space4),
          child: Column(
            children: [
              ...List.generate(package.items.length, (index) {
                final item = package.items[index];
                final isLast = index == package.items.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall),
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: AppTheme.primaryGreen,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${item.qty} ${item.unit} × ${_formatCurrency(item.pricePerUnit)}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatCurrency(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }),
            ],
          ),
        ),

        // ── Revenue Estimate ────────────────────────────────────────
        const SizedBox(height: AppTheme.space16),
        Container(
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up,
                  color: AppTheme.accent, size: 28),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi Pendapatan',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(estimatedMonthly * (package.subscriberCount ?? 0))} / bulan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.accent,
                      ),
                    ),
                    Text(
                      'dari ${package.subscriberCount ?? 0} pelanggan × ${_formatCurrency(estimatedMonthly)}/bulan',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Action Buttons ──────────────────────────────────────────
        const SizedBox(height: AppTheme.space24),
        Row(
          children: [
            Expanded(
              child: SPButton(
                label: 'Edit',
                icon: Icons.edit,
                type: SPButtonType.secondary,
                onPressed: onEdit,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: SPButton(
                label: 'Hapus',
                icon: Icons.delete,
                onPressed: onDelete,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        SPButton(
          label: 'Bagikan Paket',
          icon: Icons.share,
          type: SPButtonType.text,
          onPressed: () {
            final text = StringBuffer()
              ..writeln('📦 ${package.name}')
              ..writeln(
                  '💰 ${_formatCurrency(package.price)} / pengiriman')
              ..writeln(
                  '📅 ${package.frequencyText} — ${package.deliveryDaysText}')
              ..writeln()
              ..writeln('Isi paket:');
            for (final item in package.items) {
              text.writeln(
                  '  • ${item.name} ${item.qty}${item.unit}');
            }
            text
              ..writeln()
              ..writeln('Langganan di SayurPintar! 🥬');

            Clipboard.setData(ClipboardData(text: text.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Info paket disalin ke clipboard'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.space32),
      ],
    );
  }
}

// ── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryGreen),
          const SizedBox(width: AppTheme.space12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
