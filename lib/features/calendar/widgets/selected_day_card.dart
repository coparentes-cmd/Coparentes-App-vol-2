import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/api/app_api_client.dart';
import '../../../../l10n/locale_policy.dart';
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
import 'swap_card.dart';
import 'swap_date_row.dart';
import 'add_event_sheet.dart';
import 'swap_request_sheet.dart';
import 'swap_reject_sheet.dart';
import 'schedule_setup_banner.dart';
import 'pending_schedule_banner.dart';
import 'schedule_request_card.dart';
import 'exception_request_card.dart';
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';
import 'package:coparentes/l10n/app_strings.dart';

class SelectedDayCard extends StatelessWidget {
  final DateTime day;
  final CustodySlot? slot;
  final List<CalendarEvent> events;
  final bool isException;
  final bool isPending;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;

  const SelectedDayCard({
    required this.day,
    required this.slot,
    required this.events,
    this.isException = false,
    this.isPending = false,
    this.onEventDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    final children =
        context.watch<AppProvider>().currentWorkspace?.children ?? const [];
    final isParentA = slot?.custodian == UserRole.parentA;
    final color = slot == null
        ? AppTheme.textSecondary
        : (isParentA ? AppTheme.parentAColor : AppTheme.parentBColor);
    final label = slot == null
        ? null
        : (isParentA ? 'U Mamy' : 'U Taty');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDayHeader(context, day),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isException || isPending) ...[
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (isException)
                      StatusChip(
                        label: context.tr('Wyjątek'),
                        color: AppTheme.warningColor,
                      ),
                    if (isPending)
                      StatusChip(
                        label: context.tr('Oczekuje akceptacji'),
                        color: AppTheme.warningColor,
                      ),
                  ],
                ),
              ],
              if (slot != null && label != null) ...[
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.home, color: color, size: 20),
                    SizedBox(width: 8),
                    Text(
                      context.tr(label),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (slot!.handoverTime != null) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${context.tr('Przekazanie')}: ${slot!.handoverTime}',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (slot!.handoverLocation != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          context.tr(slot!.handoverLocation!),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (sortedEvents.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...sortedEvents.map(
                  (e) {
                    final timeLabel = formatEventTimeLabel(e.startDate);
                    String? childLabel;
                    if (e.childId != null) {
                      for (final child in children) {
                        if (child.id == e.childId) {
                          childLabel = child.name.split(' ').first;
                          break;
                        }
                      }
                    }
                    final titleCore = timeLabel == null
                        ? e.title
                        : '$timeLabel  ${e.title}';
                    final titleText = childLabel == null
                        ? titleCore
                        : '$titleCore · $childLabel';
                    return GestureDetector(
                      onDoubleTap: onEventDoubleTap == null
                          ? null
                          : () => onEventDoubleTap!(e),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            e.typeIcon,
                            size: 16,
                            color: e.typeColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (e.description != null)
                                Text(
                                  e.description!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                    );
                  },
                ),
              ] else if (slot == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr('Brak zdarzeń tego dnia'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  String _formatDayHeader(BuildContext context, DateTime date) {
    final locale = dateFormattingLocale(Localizations.localeOf(context));
    final raw = DateFormat('EEEE, d MMMM', locale).format(date);
    if (raw.isEmpty) {
      return raw;
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}
