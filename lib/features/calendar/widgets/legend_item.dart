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
import 'day_action_buttons.dart';
import 'exception_request_sheet.dart';

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool dot;

  const LegendItem({
    required this.color,
    required this.label,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
