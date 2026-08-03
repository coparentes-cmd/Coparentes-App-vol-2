import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/calendar_date_utils.dart';

/// Day schedule rows in Google Calendar agenda style.
class DayAgendaList extends StatelessWidget {
  final List<CalendarEvent> events;
  final VoidCallback? onEmptyTap;
  final ValueChanged<CalendarEvent>? onEventTap;

  const DayAgendaList({
    super.key,
    required this.events,
    this.onEmptyTap,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));

    if (sorted.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEmptyTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Brak wydarzeń na dziś',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: sorted.map((event) {
        final timeLabel = formatAgendaTimeColumn(
          start: event.startDate,
          end: event.endDate,
        );
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEventTap == null ? null : () => onEventTap!(event),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: event.typeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              event.location!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
