import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.primaryTeal,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? AppTheme.primaryTeal : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppTheme.primaryTeal : AppTheme.dividerColor,
          ),
        ),
      ),
    );
  }
}
