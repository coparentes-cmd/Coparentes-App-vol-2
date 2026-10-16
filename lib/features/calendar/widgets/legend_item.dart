import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool dot;
  final Color? labelColor;
  final double fontSize;
  final double markerSize;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.dot = false,
    this.labelColor,
    this.fontSize = 13,
    this.markerSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final marker = markerSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(
            width: marker * 0.5,
            height: marker * 0.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else if (icon != null)
          Icon(icon, size: marker * 0.875, color: color)
        else
          Container(
            width: marker,
            height: marker,
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
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: labelColor ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
