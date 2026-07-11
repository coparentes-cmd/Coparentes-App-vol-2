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

import '../calendar_helpers.dart';
import 'legend_item.dart';
import 'selected_day_card.dart';
import 'swap_card.dart';
import 'swap_date_row.dart';
import 'add_event_sheet.dart';
import 'swap_request_sheet.dart';
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class PendingScheduleBanner extends StatelessWidget {
  final CustodySchedule schedule;
  final bool showsPreview;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingScheduleBanner({
    required this.schedule,
    required this.showsPreview,
    required this.canRespond,
    this.keyboardAcceptAutofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canRespond
                    ? 'Propozycja grafiku do akceptacji'
                    : 'Grafik oczekuje na akceptację',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                schedule.endDate != null
                    ? '${schedule.patternLabel} · ${formatScheduleRange(schedule)}'
                    : '${schedule.patternLabel} · start ${schedule.startDate.day}.${schedule.startDate.month}.${schedule.startDate.year}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (showsPreview) ...[
                const SizedBox(height: 6),
                const Text(
                  'Kalendarz pokazuje podgląd proponowanego grafiku — '
                  'taki sam u obojga rodziców.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (canRespond) ...[
                const SizedBox(height: 12),
                EnterAcceptScope(
                  onAccept: onAccept,
                  autofocus: keyboardAcceptAutofocus,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          child: const Text('Odrzuć'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                          ),
                          child: const Text('Akceptuj'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
