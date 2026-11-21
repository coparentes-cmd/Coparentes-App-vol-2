import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: onTap != null,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white24 : AppTheme.textHint,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}