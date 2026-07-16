import 'package:flutter/material.dart';
import 'package:sayurpintar/app/theme.dart';

enum SPButtonType { primary, secondary, text }

class SPButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SPButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;

  const SPButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = SPButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppTheme.space8),
              ],
              Text(label),
            ],
          );

    Widget button;
    switch (type) {
      case SPButtonType.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
      case SPButtonType.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
      case SPButtonType.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
