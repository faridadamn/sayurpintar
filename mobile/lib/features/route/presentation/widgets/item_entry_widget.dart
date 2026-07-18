import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

class VisitItem {
  final String? id;
  final String productName;
  final int quantity;
  final String unit;
  final double pricePerUnit;

  const VisitItem({
    this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
  });

  double get subtotal => quantity * pricePerUnit;

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
        productName: json['product_name']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unit: json['unit']?.toString() ?? 'pcs',
        pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      );
}

class ItemEntryWidget extends StatefulWidget {
  final VisitItem? item;
  final ValueChanged<VisitItem> onChanged;
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
  static const _units = <String>[
    'pcs',
    'ikat',
    'kg',
    'ons',
    'liter',
    'bungkus',
    'karung',
    'lusin',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int _quantity;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.item?.productName ?? '',
    );
    _priceController = TextEditingController(
      text: widget.item == null || widget.item!.pricePerUnit <= 0
          ? ''
          : widget.item!.pricePerUnit.toStringAsFixed(0),
    );
    _quantity = widget.item?.quantity ?? 1;
    _unit = _units.contains(widget.item?.unit) ? widget.item!.unit : 'ikat';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      VisitItem(
        id: widget.item?.id,
        productName: _nameController.text.trim(),
        quantity: _quantity,
        unit: _unit,
        pricePerUnit: double.tryParse(
              _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    final subtotal = _quantity * price;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nama barang',
                    isDense: true,
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close, color: AppTheme.error),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Row(
            children: [
              IconButton(
                onPressed: _quantity <= 1
                    ? null
                    : () {
                        setState(() => _quantity--);
                        _emit();
                      },
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$_quantity',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _quantity++);
                  _emit();
                },
                icon: const Icon(Icons.add),
              ),
              DropdownButton<String>(
                value: _unit,
                items: _units
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _unit = value);
                  _emit();
                },
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                    isDense: true,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _emit();
                  },
                ),
              ),
            ],
          ),
          if (subtotal > 0) ...[
            const SizedBox(height: AppTheme.space8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal: Rp ${subtotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
