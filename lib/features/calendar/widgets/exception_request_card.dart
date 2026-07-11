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
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class ExceptionRequestCard extends StatelessWidget {
  final CustodyException exception;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const ExceptionRequestCard({
    required this.exception,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  String get _rangeLabel {
    final from = exception.fromDate;
    final to = exception.toDate;
    if (from.year == to.year &&
        from.month == to.month &&
        from.day == to.day) {
      return '${from.day}.${from.month}.${from.year}';
    }
    return '${from.day}.${from.month}.${from.year} – ${to.day}.${to.month}.${to.year}';
  }

  String get _custodianLabel =>
      exception.custodian == UserRole.parentA ? 'Mama' : 'Tata';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wniosek o zmianę opiekuna',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Okres: $_rangeLabel'),
                  Text('Opiekun: $_custodianLabel'),
                  if (exception.reason != null)
                    Text('Powód: ${exception.reason}'),
                ],
              ),
            ),
            if (canRespond)
              EnterAcceptScope(
                onAccept: onAccept,
                autofocus: keyboardAcceptAutofocus,
                child: SizedBox(
                  width: 108,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Akceptuj', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('Odrzuć', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
