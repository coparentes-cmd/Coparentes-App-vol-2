import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../config/country_profiles.dart';
import '../../../../config/legal_config.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../screens/auth/child_onboarding_sheet.dart';
import '../../../screens/settings/privacy_consents_section.dart';

import 'edit_profile_sheet.dart';
import 'change_password_sheet.dart';
import 'email_invite_sheet.dart';
import 'section_header.dart';
import 'settings_card.dart';
import 'settings_divider.dart';
import 'info_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const ActionTile({
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
      trailing: Icon(Icons.chevron_right,
          color: isDark ? Colors.white24 : AppTheme.textHint, size: 18),
      onTap: onTap,
    );
  }
}
