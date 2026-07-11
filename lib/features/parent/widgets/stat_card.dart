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
import 'today_card.dart';
import 'message_thread_preview.dart';
import 'finance_snapshot_card.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
