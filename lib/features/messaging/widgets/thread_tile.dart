import 'package:flutter/material.dart';

import '../../../config/messaging_categories.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../widgets/message_tag_widgets.dart';
import 'e2e_message_text.dart';

class ThreadTile extends StatelessWidget {
  final MessageThread thread;
  final String? viewerUserId;
  final Set<String> userTags;
  final bool selected;
  final VoidCallback onTap;

  const ThreadTile({
    super.key,
    required this.thread,
    required this.viewerUserId,
    this.userTags = const {},
    this.selected = false,
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
    final theme = Theme.of(context).textTheme;
    return Material(
      color: selected ? AppTints.tealBg : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.cardPaddingH,
            vertical: 14,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTints.threadDivider, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: thread.categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: selected
                      ? Border.all(color: AppTheme.primaryTeal, width: 2)
                      : null,
                ),
                child: Icon(
                  thread.categoryIcon,
                  color: thread.categoryColor,
                  size: 22,
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
                        Expanded(
                          child: Text(
                            context.tr(threadListTitle(thread)),
                            style: theme.bodyLarge?.copyWith(
                              fontWeight: _hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          _formatThreadListTime(thread.lastActivity),
                          style: theme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (lastMsg != null)
                      Row(
                        children: [
                          Text(
                            '${lastMsg.senderName}: ',
                            style: theme.bodyMedium,
                          ),
                          Expanded(
                            child: E2eMessageText(
                              message: lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    if (userTags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: userTags
                            .map(
                              (tag) => MessageTagChip(
                                tag: tag,
                                compact: true,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_hasUnread)
                Container(
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${thread.messages.length}',
                    style: theme.labelMedium?.copyWith(
                      color: AppTints.onTeal,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

String _formatThreadListTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  return '${diff.inDays}d';
}
