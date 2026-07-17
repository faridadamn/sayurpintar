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
            "import 'package:dio/dio.dart';",
            "import 'package:dio/dio.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';",
        ),
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

    repository = Path("mobile/lib/features/route/data/route_repository.dart")
    text = repository.read_text(encoding="utf-8")
    if "final routeRepositoryProvider" not in text:
        text = text.rstrip() + (
            "\n\nfinal routeRepositoryProvider = Provider<RouteRepository>((ref) {\n"
            "  return RouteRepository(ApiClient());\n"
            "});\n"
        )
        repository.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
