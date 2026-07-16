import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

/// Represents an item sold during a visit.
class VisitItem {
  final String? id;
  final String productName;
  final int quantity;
  final String unit;
  final double pricePerUnit;
  final double get subtotal => quantity * pricePerUnit;

  const VisitItem({
    this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
  });

  VisitItem copyWith({
    String? id,
    String? productName,
    int? quantity,
    String? unit,
    double? pricePerUnit,
  }) {
    return VisitItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'product_name': productName,
        'quantity': quantity,
        'unit': unit,
        'price_per_unit': pricePerUnit,
        'subtotal': subtotal,
      };

  factory VisitItem.fromJson(Map<String, dynamic> json) => VisitItem(
        id: json['id']?.toString(),
        productName: json['product_name'] ?? '',
        quantity: json['quantity'] ?? 0,
        unit: json['unit'] ?? 'pcs',
        pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      );
}

/// Reusable item entry widget for the visit completion screen.
///
/// Displays product name, quantity controls (+/-), unit dropdown,
/// price input, and subtotal. Calls [onChanged] whenever a field updates.
class ItemEntryWidget extends StatefulWidget {
  final VisitItem? item;
  final Function(VisitItem) onChanged;
  final VoidCallback? onRemove;
  final int index;

  const ItemEntryWidget({
    super.key,
    this.item,
    required this.onChanged,
    this.onRemove,
    this.index = 0,
  });

  @override
  State<ItemEntryWidget> createState() => _ItemEntryWidgetState();
}

class _ItemEntryWidgetState extends State<ItemEntryWidget> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late int _quantity;
  late String _unit;

  static const List<String> _units = [
    'pcs',
    'ikat',
    'kg',
    'ons',
    'liter',
    'bungkus',
    'karung',
    'lusin',
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.item?.productName ?? '');
    _priceController = TextEditingController(
        text: widget.item != null && widget.item!.pricePerUnit > 0
            ? _formatCurrency(widget.item!.pricePerUnit)
            : '');
    _quantity = widget.item?.quantity ?? 1;
    _unit = widget.item?.unit ?? 'ikat';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final price = _parseCurrency(_priceController.text);
    widget.onChanged(VisitItem(
      id: widget.item?.id,
      productName: _nameController.text,
      quantity: _quantity,
      unit: _unit,
      pricePerUnit: price,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final price = _parseCurrency(_priceController.text);
    final subtotal = _quantity * price;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Name + Remove ──────────────────
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nama barang',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
              if (widget.onRemove != null)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: AppTheme.error),
                  ),
                ),
            ],
          ),
          const Divider(height: 1),

          // ── Row 2: Quantity + Unit + Price ─────────
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              // Quantity controls
              _buildQtyButton(Icons.remove, () {
                if (_quantity > 1) {
                  setState(() => _quantity--);
                  _notifyChange();
                }
              }),
              GestureDetector(
                onTap: () => _showQtyDialog(),
                child: Container(
                  width: 48,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.divider),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              _buildQtyButton(Icons.add, () {
                setState(() => _quantity++);
                _notifyChange();
              }),
              const SizedBox(width: AppTheme.space8),

              // Unit dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.divider),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unit,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    items: _units
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _unit = v);
                        _notifyChange();
                      }
                    },
                  ),
                ),
              ),

              const Spacer(),

              // Price input
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Harga',
                    isDense: true,
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(AppTheme.radiusSmall)),
                    ),
                  ),
                  onChanged: (_) => _notifyChange(),
                ),
              ),
            ],
          ),

          // ── Subtotal ──────────────────────────────
          if (subtotal > 0) ...[
            const SizedBox(height: AppTheme.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Subtotal: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  'Rp ${_formatCurrency(subtotal)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primaryGreen),
      ),
    );
  }

  void _showQtyDialog() {
    final controller = TextEditingController(text: '$_quantity');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jumlah'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Masukkan jumlah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _quantity = val);
                _notifyChange();
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value == value.roundToDouble()) {
      return _formatNumber(value.round());
    }
    return value.toStringAsFixed(0);
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  double _parseCurrency(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}
