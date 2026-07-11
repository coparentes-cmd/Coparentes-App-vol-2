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
import 'info_tile.dart';
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

class SettingsDivider extends StatelessWidget {
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
