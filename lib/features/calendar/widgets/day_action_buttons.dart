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
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'exception_request_sheet.dart';

class DayActionButtons extends StatelessWidget {
  final DateTime day;
  final CustodySlot? slot;
  final VoidCallback onChangeCustodian;
  final VoidCallback onRequestSwap;

  const DayActionButtons({
    required this.day,
    required this.slot,
    required this.onChangeCustodian,
    required this.onRequestSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Zmiany w zatwierdzonym grafiku wymagają akceptacji drugiego rodzica.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onChangeCustodian,
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('Zaproponuj zmianę opiekuna'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRequestSwap,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Prośba o zamianę'),
        ),
      ],
    );
  }
}
