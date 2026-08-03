import 'package:flutter/material.dart';

import '../../../config/messaging_categories.dart';
import '../../../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.primaryTeal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(messagingCategoryLabel(category)),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: accent.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? accent : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? accent : AppTheme.dividerColor,
          ),
        ),
      ),
    );
  }
}
