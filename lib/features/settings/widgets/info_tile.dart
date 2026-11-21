import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    // Never put unbounded Text in ListTile.trailing — on narrow phones that
    // asserts "Trailing widget consumes the entire tile width" and white-screens.
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? Colors.white54 : AppTheme.textSecondary,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white70 : AppTheme.textSecondary,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: valueColor ??
              (isDark ? Colors.white : AppTheme.textPrimary),
        ),
      ),
    );
  }
}
