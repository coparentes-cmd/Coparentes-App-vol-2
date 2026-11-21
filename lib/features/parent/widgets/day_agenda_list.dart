import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/calendar_date_utils.dart';

/// Day schedule rows as a simple timeline (Wariant A).
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
    final theme = Theme.of(context).textTheme;

    if (sorted.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEmptyTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.tr('Brak wydarzeń na dziś'),
              style: theme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _TimelineRow(
            event: sorted[i],
            isLast: i == sorted.length - 1,
            onTap: onEventTap == null ? null : () => onEventTap!(sorted[i]),
          ),
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final CalendarEvent event;
  final bool isLast;
  final VoidCallback? onTap;

  const _TimelineRow({
    required this.event,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final timeLabel = formatAgendaTimeColumn(
      start: event.startDate,
      end: event.endDate,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    timeLabel,
                    style: theme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: event.typeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: event.typeColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppTints.timelineLine,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: theme.bodyLarge,
                      ),
                      if (event.location != null &&
                          event.location!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            event.location!,
                            style: theme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
