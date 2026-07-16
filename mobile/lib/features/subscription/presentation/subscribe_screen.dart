import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/subscription/data/subscription_repository.dart';
import 'package:sayurpintar/features/subscription/providers/subscription_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_avatar.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_card.dart';

class SubscribeScreen extends ConsumerStatefulWidget {
  final SubscriptionPackage package;
  const SubscribeScreen({super.key, required this.package});

  @override
  ConsumerState<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends ConsumerState<SubscribeScreen> {
  String _paymentMethod = 'cash';
  String _paymentFrequency = 'per_kirim';
  bool _isLoading = false;

  static const _dayNames = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  String _formatRupiah(double n) {
    return 'Rp ${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  List<String> _getNextDeliveryDates() {
    final pkg = widget.package;
    final now = DateTime.now();
    final dates = <String>[];
    var check = now.add(const Duration(days: 1));

    while (dates.length < 5) {
      if (pkg.deliveryDays.contains(check.weekday)) {
        dates.add(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(check));
      }
      check = check.add(const Duration(days: 1));
    }
    return dates;
  }

  String _getNextDeliveryStartDate() {
    final pkg = widget.package;
    final now = DateTime.now();
    var check = now.add(const Duration(days: 1));
    while (true) {
      if (pkg.deliveryDays.contains(check.weekday)) {
        return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(check);
      }
      check = check.add(const Duration(days: 1));
    }
  }

  double _getWeeklyTotal() {
    final pkg = widget.package;
    final deliveriesPerWeek = pkg.deliveryDays.length;
    return pkg.price * deliveriesPerWeek;
  }

  double _getMonthlyTotal() {
    return _getWeeklyTotal() * 4;
  }

  String _getFrequencyLabel() {
    switch (_paymentFrequency) {
      case 'per_kirim':
        return '${_formatRupiah(widget.package.price)}/kirim';
      case 'mingguan':
        return '${_formatRupiah(_getWeeklyTotal())}/minggu';
      case 'bulanan':
        return '${_formatRupiah(_getMonthlyTotal())}/bulan';
      default:
        return _formatRupiah(widget.package.price);
    }
  }

  String _getFrequencyLabelById(String freq) {
    switch (freq) {
      case 'per_kirim':
        return 'Per Kirim';
      case 'mingguan':
        return 'Mingguan';
      case 'bulanan':
        return 'Bulanan';
      default:
        return freq;
    }
  }

  Future<void> _handleSubscribe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('Konfirmasi Berlangganan'),
        content: Text(
          'Anda akan berlangganan "${widget.package.name}" dari ${widget.package.pedagangId}. '
          'Pembayaran: ${_getFrequencyLabel()}. Konfirmasi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Berlangganan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.subscribeToPackage(
        packageId: widget.package.id,
        paymentMethod: _paymentMethod,
        paymentFrequency: _paymentFrequency,
      );
      ref.invalidate(myActiveSubscriptionsProvider);
      ref.invalidate(availablePackagesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berlangganan berhasil! 🎉'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal berlangganan: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final deliveryDates = _getNextDeliveryDates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berlangganan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Package Preview Header ──
            _buildPackageHeader(pkg),
            const SizedBox(height: AppTheme.space16),

            // ── Items List ──
            _buildSectionTitle('📦 Isi Paket'),
            const SizedBox(height: AppTheme.space8),
            _buildItemsList(pkg),
            const SizedBox(height: AppTheme.space24),

            // ── Payment Section ──
            _buildSectionTitle('💳 Pembayaran'),
            const SizedBox(height: AppTheme.space8),
            _buildPaymentMethodSelector(),
            const SizedBox(height: AppTheme.space16),
            _buildPaymentFrequencySelector(),
            const SizedBox(height: AppTheme.space24),

            // ── Delivery Schedule ──
            _buildSectionTitle('📅 Jadwal Pengiriman'),
            const SizedBox(height: AppTheme.space8),
            _buildDeliverySchedule(deliveryDates),
            const SizedBox(height: AppTheme.space24),

            // ── Summary ──
            _buildSectionTitle('📊 Ringkasan'),
            const SizedBox(height: AppTheme.space8),
            _buildSummary(pkg),
            const SizedBox(height: AppTheme.space24),

            // ── Terms ──
            _buildTerms(),
            const SizedBox(height: AppTheme.space24),

            // ── Subscribe Button ──
            _buildSubscribeButton(),
            const SizedBox(height: AppTheme.space32),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageHeader(SubscriptionPackage pkg) {
    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pedagang info
          Row(
            children: [
              SPAvatar(
                name: pkg.pedagangId,
                radius: 20,
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedagang #${pkg.pedagangId}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          '4.5',
                          style: const TextStyle(
                            fontSize: 12,
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
          const Divider(height: AppTheme.space20),

          // Package info
          Text(
            pkg.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (pkg.description != null && pkg.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space4),
            Text(
              pkg.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space8),

          // Price
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space12,
              vertical: AppTheme.space8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              '${_formatRupiah(pkg.price)} / pengiriman',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space8),

          // Frequency + delivery days
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${pkg.frequencyText} • ${_buildDaysText(pkg.deliveryDays)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildDaysText(List<int> days) {
    return days.map((d) => _dayNames[d] ?? '?').join(', ');
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildItemsList(SubscriptionPackage pkg) {
    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: pkg.items.asMap().entries.map((entry) {
          final item = entry.value;
          final isLast = entry.key == pkg.items.length - 1;
          return Column(
            children: [
              Row(
                children: [
                  // Image or emoji
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Center(
                      child: Text('🥬', style: TextStyle(fontSize: 22)),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${item.qty} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatRupiah(item.subtotal),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              if (!isLast) const Divider(height: AppTheme.space16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final methods = [
      {'id': 'cash', 'label': 'Cash', 'emoji': '💵'},
      {'id': 'qris', 'label': 'QRIS', 'emoji': '📱'},
      {'id': 'transfer', 'label': 'Transfer', 'emoji': '🏦'},
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = _paymentMethod == m['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMethod = m['id']!),
            child: Container(
              margin: EdgeInsets.only(
                right: m != methods.last ? AppTheme.space8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : Colors.white,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Column(
                children: [
                  Text(m['emoji']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    m['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentFrequencySelector() {
    final frequencies = [
      {'id': 'per_kirim', 'label': 'Per Kirim'},
      {'id': 'mingguan', 'label': 'Mingguan'},
      {'id': 'bulanan', 'label': 'Bulanan'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frekuensi Pembayaran',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        ...frequencies.map((f) {
          final isSelected = _paymentFrequency == f['id'];
          return GestureDetector(
            onTap: () =>
                setState(() => _paymentFrequency = f['id']!),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppTheme.space8),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space12,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withOpacity(0.08)
                    : Colors.white,
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primaryGreen : AppTheme.divider,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: f['id']!,
                    groupValue: _paymentFrequency,
                    onChanged: (v) =>
                        setState(() => _paymentFrequency = v!),
                    activeColor: AppTheme.primaryGreen,
                  ),
                  Text(
                    f['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (f['id'] == 'per_kirim')
                    Text(
                      _formatRupiah(widget.package.price),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    )
                  else if (f['id'] == 'mingguan')
                    Text(
                      _formatRupiah(_getWeeklyTotal()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    )
                  else
                    Text(
                      _formatRupiah(_getMonthlyTotal()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeliverySchedule(List<String> dates) {
    final startDate = _getNextDeliveryStartDate();
    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Mulai dari: $startDate',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const Divider(height: AppTheme.space16),
          ...dates.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: entry.key == 0
                          ? AppTheme.primaryGreen
                          : AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: entry.key == 0
                              ? Colors.white
                              : AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: entry.key == 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: entry.key == 0
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummary(SubscriptionPackage pkg) {
    return SPCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _summaryRow(
            'Per pengiriman',
            _formatRupiah(pkg.price),
          ),
          const Divider(height: AppTheme.space16),
          _summaryRow(
            'Per minggu (${pkg.deliveryDays.length}x kirim)',
            _formatRupiah(_getWeeklyTotal()),
          ),
          const Divider(height: AppTheme.space16),
          _summaryRow(
            'Per bulan (estimasi)',
            _formatRupiah(_getMonthlyTotal()),
          ),
          const Divider(height: AppTheme.space16),
          _summaryRow(
            'Pembayaran',
            _getFrequencyLabel(),
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
                  isHighlight ? AppTheme.primaryGreen : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppTheme.accent),
          SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              'Dapat dijeda atau dibatalkan kapan saja',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return SPButton(
      label: 'Berlangganan — ${_getFrequencyLabel()}',
      onPressed: _isLoading ? null : _handleSubscribe,
      isLoading: _isLoading,
      icon: Icons.check_circle,
    );
  }
}
