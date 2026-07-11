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
import 'finance_snapshot_card.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class MessageThreadPreview extends StatelessWidget {
  final MessageThread thread;
  final String? viewerUserId;
  final VoidCallback onTap;

  const MessageThreadPreview({
    required this.thread,
    this.viewerUserId,
    required this.onTap,
  });

  bool get _hasUnread {
    if (viewerUserId == null) {
      return thread.hasUnread;
    }
    return threadHasUnreadForViewer(thread, viewerUserId!);
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: thread.categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    thread.categoryIcon,
                    color: thread.categoryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            thread.subject,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _formatTime(thread.lastActivity),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (lastMsg != null)
                        Text(
                          '${lastMsg.senderName}: ${lastMsg.content}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _hasUnread
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight: _hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_hasUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryTeal,
                      shape: BoxShape.circle,
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
