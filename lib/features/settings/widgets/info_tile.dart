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
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: isDark ? Colors.white54 : AppTheme.textSecondary, size: 20),
      title: Text(label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          )),
      trailing: Text(
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
