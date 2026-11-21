import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const SectionHeader({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
