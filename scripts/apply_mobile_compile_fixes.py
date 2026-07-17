from pathlib import Path

REPLACEMENTS = {
    "mobile/lib/features/route/presentation/navigation_screen.dart": [
        (
            "import 'package:go_router/go_router.dart';",
            "import 'package:go_router/go_router.dart' hide RouteData;",
        ),
    ],
    "mobile/lib/features/route/presentation/route_optimized_screen.dart": [
        ("        pattern: StrokePattern.dashed(segments: [12, 6]),\n", ""),
    ],
    "mobile/lib/features/route/presentation/map_screen.dart": [
        ("        pattern: StrokePattern.dashed(segments: [10, 5]),\n", ""),
        ("              margin: const EdgeInsets.only(top: 4),\n", ""),
    ],
    "mobile/lib/features/subscription/presentation/modify_delivery_screen.dart": [
        (
            "        title: Text('Ubah Pesanan'),\n"
            "        subtitle: Text(\n"
            "          _formatDate(widget.deliveryDate),\n"
            "          style: const TextStyle(fontSize: 12, color: Colors.white70),\n"
            "        ),",
            "        title: Column(\n"
            "          crossAxisAlignment: CrossAxisAlignment.start,\n"
            "          children: [\n"
            "            const Text('Ubah Pesanan'),\n"
            "            Text(\n"
            "              _formatDate(widget.deliveryDate),\n"
            "              style: const TextStyle(fontSize: 12, color: Colors.white70),\n"
            "            ),\n"
            "          ],\n"
            "        ),",
        ),
    ],
    "mobile/lib/features/subscription/presentation/package_detail_screen.dart": [
        (
            "    text.writeln()..writeln('Langganan di SayurPintar! 🥬');",
            "    text.writeln();\n    text.writeln('Langganan di SayurPintar! 🥬');",
        ),
        (
            "            text.writeln()..writeln('Langganan di SayurPintar! 🥬');",
            "            text.writeln();\n            text.writeln('Langganan di SayurPintar! 🥬');",
        ),
    ],
    "mobile/lib/features/route/data/route_repository.dart": [
        (
            "  Future<VisitSummary> getVisitSummary(String date) async {",
            "  Future<void> completeVisit(\n"
            "    String visitId,\n"
            "    Map<String, dynamic> data,\n"
            "  ) async {\n"
            "    await _dio.patch(\n"
            "      '${ApiEndpoints.routes}/visits/$visitId',\n"
            "      data: data,\n"
            "    );\n"
            "  }\n\n"
            "  Future<VisitSummary> getVisitSummary(String date) async {",
        ),
    ],
    "mobile/lib/features/route/providers/tracking_provider.dart": [
        (
            "import 'package:sayurpintar/features/route/data/route_repository.dart';",
            "import 'package:sayurpintar/features/route/data/route_repository.dart';\n"
            "import 'package:sayurpintar/features/route/providers/route_provider.dart';",
        ),
    ],
    "mobile/lib/features/dashboard/presentation/profile_screen.dart": [
        (
            "    final num = value is int ? value : (value as num?)?.toInt() ?? 0;\n"
            "    if (num >= 1000000) {\n"
            "      return '${(num / 1000000).toStringAsFixed(1)}jt';\n"
            "    }\n"
            "    if (num >= 1000) {\n"
            "      return '${(num / 1000).toStringAsFixed(0)}rb';\n"
            "    }\n"
            "    return 'Rp $num';",
            "    final amount = value is int ? value : (value as num?)?.toInt() ?? 0;\n"
            "    if (amount >= 1000000) {\n"
            "      return '${(amount / 1000000).toStringAsFixed(1)}jt';\n"
            "    }\n"
            "    if (amount >= 1000) {\n"
            "      return '${(amount / 1000).toStringAsFixed(0)}rb';\n"
            "    }\n"
            "    return 'Rp $amount';",
        ),
    ],
    "mobile/lib/features/price/presentation/pelanggan_price_screen.dart": [
        (
            "    final num = price is int ? price : (price as num).toInt();\n"
            "    final str = num.toString();",
            "    final amount = price is int ? price : (price as num).toInt();\n"
            "    final str = amount.toString();",
        ),
    ],
    "mobile/lib/features/price/presentation/price_comparison_screen.dart": [
        (
            "    final num = price is int ? price : (price as num).toInt();\n"
            "    final str = num.toString();",
            "    final amount = price is int ? price : (price as num).toInt();\n"
            "    final str = amount.toString();",
        ),
    ],
    "mobile/lib/features/price/presentation/price_alert_pelanggan_screen.dart": [
        ("onDelete: () => _deleteAlert(alert['id']),", "onDelete: () => _deleteAlert(alert.id),"),
        ("value: p['id']?.toString(),", "value: p.id,"),
        ("child: Text(p['name'] ?? p['product_name'] ?? ''),", "child: Text(p.name),"),
        (
            "_selectedProductName =\n                              p['name'] ?? p['product_name'] ?? '';",
            "_selectedProductName = p.name;",
        ),
    ],
}


def main() -> None:
    for filename, rules in REPLACEMENTS.items():
        path = Path(filename)
        text = path.read_text(encoding="utf-8")
        for old, new in rules:
            if old not in text:
                raise RuntimeError(f"Expected source text not found in {filename}")
            text = text.replace(old, new, 1)
        path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
