import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<AppProvider>().isDark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 52,
      color: isDark ? Colors.white12 : AppTheme.dividerColor,
    );
  }
}
