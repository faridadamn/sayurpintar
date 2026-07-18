import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/price/data/price_repository.dart';

class PriceTrendChart extends StatelessWidget {
  final List<TrendDataPoint> dataPoints;
  final String timePeriod;

  const PriceTrendChart({
    super.key,
    required this.dataPoints,
    required this.timePeriod,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: AppTheme.textSecondary.withOpacity(0.4),
              ),
              const SizedBox(height: AppTheme.space8),
              const Text(
                'Belum ada data tren',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendChartPainter(
          dataPoints: dataPoints,
          lineColor: AppTheme.primaryGreen,
          fillColor: AppTheme.primaryGreen.withOpacity(0.12),
          gridColor: AppTheme.divider.withOpacity(0.3),
          textColor: AppTheme.textSecondary,
          labelColor: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendDataPoint> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;
  final Color labelColor;

  static const double _leftPadding = 60;
  static const double _rightPadding = 16;
  static const double _topPadding = 16;
  static const double _bottomPadding = 40;

  _TrendChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final chartWidth = size.width - _leftPadding - _rightPadding;
    final chartHeight = size.height - _topPadding - _bottomPadding;

    final prices = dataPoints.map((e) => e.price).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final priceRange = maxPrice - minPrice;
    final adjustedMin =
        priceRange > 0 ? minPrice - priceRange * 0.1 : minPrice - 1000;
    final adjustedMax =
        priceRange > 0 ? maxPrice + priceRange * 0.1 : maxPrice + 1000;
    final adjustedRange = adjustedMax - adjustedMin;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridCount = 4;
    for (var i = 0; i <= gridCount; i++) {
      final y = _topPadding + (chartHeight / gridCount) * i;
      canvas.drawLine(
        Offset(_leftPadding, y),
        Offset(size.width - _rightPadding, y),
        gridPaint,
      );

      // Y axis labels
      final priceValue = adjustedMax - (adjustedRange / gridCount) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: _formatAxisPrice(priceValue),
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPadding - tp.width - 8, y - tp.height / 2));
    }

    // Calculate points
    final points = <Offset>[];
    for (var i = 0; i < dataPoints.length; i++) {
      final x = _leftPadding +
          (dataPoints.length > 1
              ? (chartWidth / (dataPoints.length - 1)) * i
              : chartWidth / 2);
      final y = _topPadding +
          chartHeight -
          ((dataPoints[i].price - adjustedMin) / adjustedRange) * chartHeight;
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    if (points.length > 1) {
      final fillPath = Path()
        ..moveTo(points.first.dx, _topPadding + chartHeight);
      for (final p in points) {
        if (p == points.first) {
          fillPath.lineTo(p.dx, p.dy);
        } else {
          fillPath.lineTo(p.dx, p.dy);
        }
      }
      fillPath.lineTo(points.last.dx, _topPadding + chartHeight);
      fillPath.close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor,
          fillColor.withOpacity(0.0),
        ],
      );
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = fillGradient.createShader(
            Rect.fromLTWH(0, _topPadding, size.width, chartHeight),
          ),
      );
    }

    // Draw line
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw dots
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, dotBorderPaint);
      canvas.drawCircle(points[i], 3.5, dotPaint);
    }

    // X axis labels (show a subset to avoid overlap)
    final labelStep = dataPoints.length <= 7
        ? 1
        : dataPoints.length <= 14
            ? 2
            : dataPoints.length <= 30
                ? 5
                : 10;

    for (var i = 0; i < dataPoints.length; i += labelStep) {
      final dateText = _formatDateLabel(dataPoints[i].date);
      final tp = TextPainter(
        text: TextSpan(
          text: dateText,
          style: TextStyle(
            color: textColor,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = points[i].dx - tp.width / 2;
      tp.paint(
        canvas,
        Offset(x, _topPadding + chartHeight + 8),
      );
    }

    // Min / Max labels
    if (points.length > 1) {
      final minIdx = prices.indexOf(minPrice);
      final maxIdx = prices.indexOf(maxPrice);

      _drawPriceLabel(canvas, points[maxIdx], maxPrice, labelColor, true);
      if (minIdx != maxIdx) {
        _drawPriceLabel(canvas, points[minIdx], minPrice, labelColor, false);
      }
    }
  }

  void _drawPriceLabel(
    Canvas canvas,
    Offset point,
    double price,
    Color color,
    bool isMax,
  ) {
    final text = 'Rp ${_formatAxisPrice(price)}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dy = isMax ? point.dy - tp.height - 6 : point.dy + 6;
    final dx = (point.dx - tp.width / 2).clamp(0.0, double.infinity);
    tp.paint(canvas, Offset(dx, dy));
  }

  String _formatAxisPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}jt';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}rb';
    }
    return price.toStringAsFixed(0);
  }

  String _formatDateLabel(String date) {
    if (date.length >= 10) {
      final parts = date.substring(5, 10).split('-');
      if (parts.length == 2) {
        return '${parts[1]}/${parts[0]}';
      }
      return date.substring(5, 10);
    }
    return date;
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}
