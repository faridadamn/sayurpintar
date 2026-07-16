import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

class RatingWidget extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final bool interactive;
  final Function(int)? onRatingChanged;
  final Color activeColor;
  final Color inactiveColor;

  const RatingWidget({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
    this.activeColor = AppTheme.accent,
    this.inactiveColor = const Color(0xFFE0E0E0),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;
        final isHalf = !isFilled && starValue - 0.5 <= rating;

        return GestureDetector(
          onTap: interactive && onRatingChanged != null
              ? () => onRatingChanged!(starValue)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: interactive ? 4.0 : 1.0,
            ),
            child: Icon(
              isFilled
                  ? Icons.star
                  : isHalf
                      ? Icons.star_half
                      : Icons.star_border,
              size: size,
              color: isFilled || isHalf ? activeColor : inactiveColor,
            ),
          ),
        );
      }),
    );
  }
}

class RatingDisplayRow extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double iconSize;
  final TextStyle? textStyle;

  const RatingDisplayRow({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingWidget(
          rating: rating.round(),
          size: iconSize,
        ),
        const SizedBox(width: AppTheme.space4),
        Text(
          rating.toStringAsFixed(1),
          style: textStyle ??
              TextStyle(
                fontSize: iconSize * 0.85,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(width: AppTheme.space4),
        Text(
          '($reviewCount)',
          style: TextStyle(
            fontSize: iconSize * 0.75,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class InteractiveRatingDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Function(int rating, String? comment) onSubmit;

  const InteractiveRatingDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Function(int rating, String? comment) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => InteractiveRatingDialog(
        title: title,
        subtitle: subtitle,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<InteractiveRatingDialog> createState() =>
      _InteractiveRatingDialogState();
}

class _InteractiveRatingDialogState extends State<InteractiveRatingDialog> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
          ],
          RatingWidget(
            rating: _rating,
            size: 40,
            interactive: true,
            onRatingChanged: (val) => setState(() => _rating = val),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            _ratingLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _rating > 0 ? AppTheme.primaryDark : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              hintText: 'Tulis komentar (opsional)',
              isDense: true,
            ),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        ElevatedButton(
          onPressed: _rating > 0
              ? () {
                  widget.onSubmit(_rating, _commentCtrl.text);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Kirim'),
        ),
      ],
    );
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Sangat Kurang';
      case 2:
        return 'Kurang';
      case 3:
        return 'Cukup';
      case 4:
        return 'Bagus';
      case 5:
        return 'Sangat Bagus';
      default:
        return 'Beri rating Anda';
    }
  }
}
