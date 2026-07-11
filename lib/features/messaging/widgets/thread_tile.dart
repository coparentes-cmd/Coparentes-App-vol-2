import 'package:flutter/material.dart';

import '../../../config/messaging_categories.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../widgets/message_tag_widgets.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: selected
            ? AppTheme.primaryTeal.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: thread.categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
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
                              threadListTitle(thread),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _formatThreadListTime(thread.lastActivity),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (lastMsg != null)
                        Text(
                          '${lastMsg.senderName}: ${lastMsg.content}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
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
                Column(
                  children: [
                    if (_hasUnread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${thread.messages.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
