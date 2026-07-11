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
import 'child_chip.dart';

class AiCoachCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final compact = isCompactPhoneLayout(context);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: compact ? 22 : 28,
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  'Napisz neutralną wiadomość z pomocą AI. Pamiętaj: AI może się mylić — zawsze sprawdź przed wysłaniem.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: compact ? 11 : 12,
                    height: 1.3,
                  ),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiCoachScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1565C0),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compact ? 6 : 8),
              ),
            ),
            child: Text(
              'Otwórz',
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
