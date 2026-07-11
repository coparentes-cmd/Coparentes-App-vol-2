import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/offline_sync_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../config/messaging_categories.dart';
import '../../../../utils/messaging_helpers.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../utils/app_browser_back.dart';
import '../../../../widgets/brand_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../screens/messaging/messaging_screen.dart';
import '../../../screens/calendar/calendar_screen.dart';
import '../../../screens/finance/finance_screen.dart';
import '../../../screens/exports/exports_screen.dart';
import '../../../screens/documents/documents_screen.dart';
import '../../../screens/ai_coach/ai_coach_screen.dart';
import '../../../screens/settings/settings_screen.dart';

import 'dashboard_home.dart';
import 'stat_card.dart';
import 'message_thread_preview.dart';
import 'finance_snapshot_card.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class TodayCard extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> todayEvents;
  final int pendingSwaps;
  final Color roleColor;
  final String? custodyLabel;
  final CustodySlot? nextHandover;
  final VoidCallback onTap;

  const TodayCard({
    required this.date,
    required this.todayEvents,
    required this.pendingSwaps,
    required this.roleColor,
    this.custodyLabel,
    this.nextHandover,
    required this.onTap,
  });

  String get _dateLabel {
    const months = [
      'sty',
      'lut',
      'mar',
      'kwi',
      'maj',
      'cze',
      'lip',
      'sie',
      'wrz',
      'paź',
      'lis',
      'gru',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, color: roleColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Dziś · $_dateLabel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                  if (pendingSwaps > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingSwaps zamiana',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (custodyLabel != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.home, color: roleColor.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Opieka: $custodyLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (nextHandover != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: roleColor.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Następne przekazanie: ${nextHandover!.date.day}.${nextHandover!.date.month}'
                        '${nextHandover!.handoverTime != null ? ' o ${nextHandover!.handoverTime}' : ''}'
                        '${nextHandover!.handoverLocation != null ? ' · ${nextHandover!.handoverLocation}' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (todayEvents.isNotEmpty)
                ...todayEvents.take(3).map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(event.typeIcon, color: event.typeColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (formatEventTimeLabel(event.startDate) != null)
                          Text(
                            formatEventTimeLabel(event.startDate)!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                const Text(
                  'Brak wydarzeń na dziś',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              if (todayEvents.length > 3) ...[
                const SizedBox(height: 4),
                Text(
                  '+ ${todayEvents.length - 3} więcej w kalendarzu',
                  style: TextStyle(
                    fontSize: 12,
                    color: roleColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}
