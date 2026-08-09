import 'package:flutter/material.dart';

import '../../../../models/models.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/common_widgets.dart';

import '../calendar_helpers.dart';

class PendingScheduleBanner extends StatelessWidget {
  final CustodySchedule schedule;
  final bool canRespond;
  final bool keyboardAcceptAutofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingScheduleBanner({
    required this.schedule,
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
