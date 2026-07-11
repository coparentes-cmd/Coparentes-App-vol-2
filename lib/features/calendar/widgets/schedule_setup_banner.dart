import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/api/app_api_client.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/calendar_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../../widgets/google_style_month_calendar.dart';
import '../../../../widgets/custody_schedule_wizard.dart';

import 'legend_item.dart';
import 'selected_day_card.dart';
import 'swap_card.dart';
import 'swap_date_row.dart';
import 'add_event_sheet.dart';
import 'swap_request_sheet.dart';
import 'swap_reject_sheet.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class ScheduleSetupBanner extends StatelessWidget {
  final VoidCallback onPressed;

  const ScheduleSetupBanner({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: MaterialBanner(
        backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.08),
        content: const Text(
          'Ustawcie wspólny grafik opieki — drugi rodzic musi go zaakceptować.',
        ),
        leading: const Icon(Icons.view_week, color: AppTheme.primaryTeal),
        actions: [
          TextButton(onPressed: onPressed, child: const Text('Utwórz grafik')),
        ],
      ),
    );
  }
}
