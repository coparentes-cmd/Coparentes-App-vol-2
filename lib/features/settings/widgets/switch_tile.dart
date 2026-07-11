import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final Color activeColor;
  final bool isDark;
  final ValueChanged<bool>? onChanged;

  const SwitchTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.activeColor,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon,
          color: value
              ? activeColor
              : (isDark ? Colors.white38 : AppTheme.textSecondary),
          size: 20),
      title: Text(label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          )),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : AppTheme.textHint,
              ))
          : null,
      value: value,
      activeColor: activeColor, // ignore: deprecated_member_use
      onChanged: onChanged,
    );
  }
}
