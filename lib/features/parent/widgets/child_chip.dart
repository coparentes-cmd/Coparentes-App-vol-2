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
import 'stat_card.dart';
import 'message_thread_preview.dart';
import 'finance_snapshot_card.dart';
import 'ai_coach_cta.dart';

class ChildChip extends StatelessWidget {
  final ChildProfile child;

  const ChildChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.childColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.childColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.child_care,
              color: AppTheme.childColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            child.name.split(' ').first,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            '${child.age} lat · ${child.school?.split(' ').take(2).join(' ') ?? ''}',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
