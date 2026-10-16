import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool dot;
  final Color? labelColor;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.dot = false,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
