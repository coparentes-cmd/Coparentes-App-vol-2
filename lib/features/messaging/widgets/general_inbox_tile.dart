import 'package:flutter/material.dart';

import '../../../config/messaging_categories.dart';
import '../../../theme/app_theme.dart';

class GeneralInboxTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const GeneralInboxTile({
    super.key,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: selected
            ? AppTheme.primaryTeal.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: AppTheme.primaryTeal, width: 2)
                        : null,
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    color: AppTheme.primaryTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allTabDisplayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Wspólne wiadomości bez wyboru wątku',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
