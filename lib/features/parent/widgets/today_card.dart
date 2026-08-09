import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Compact Today header: date and custody — handover has its own bar below.
class TodayCard extends StatelessWidget {
  final DateTime date;
  final Color roleColor;
  final String? custodyLabel;
  final VoidCallback onTap;

  const TodayCard({
    super.key,
    required this.date,
    required this.roleColor,
    this.custodyLabel,
    required this.onTap,
  });

  String get _dateLabel {
    const weekdays = [
      'poniedziałek',
      'wtorek',
      'środa',
      'czwartek',
      'piątek',
      'sobota',
      'niedziela',
    ];
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
    final weekday = weekdays[date.weekday - 1];
    return '$weekday · ${date.day} ${months[date.month - 1]}';
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
                  children: [
                    Icon(Icons.event, color: roleColor, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Dziś · $_dateLabel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (custodyLabel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.home,
                        color: roleColor.withValues(alpha: 0.7),
                        size: 16,
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
