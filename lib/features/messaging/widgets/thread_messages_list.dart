import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../providers/calendar_provider.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/swap_message_utils.dart';
import 'message_bubble.dart';

class ThreadMessagesList extends StatelessWidget {
  final List<Message> messages;
  final String threadId;
  final String? threadCategory;
  final String? viewerUserId;
  final bool aiShieldEnabled;
  final bool allowPrivateTags;
  final ScrollController? scrollController;

  const ThreadMessagesList({
    super.key,
    required this.messages,
    required this.threadId,
    this.threadCategory,
    required this.viewerUserId,
    required this.aiShieldEnabled,
    this.allowPrivateTags = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final lastActionableIndex = lastActionableMessageIndex(
      messages: messages,
      threadCategory: threadCategory,
      viewerUserId: viewerUserId,
      swaps: calendar.swapRequests,
      schedule: calendar.custodySchedule,
      exceptions: calendar.custodyExceptions,
    );

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == viewerUserId;
        final group = messageGroupInfo(messages, index);

        return MessageBubble(
          message: message,
          threadId: threadId,
          threadCategory: threadCategory,
          isMe: isMe,
          aiShieldEnabled: aiShieldEnabled,
          group: group,
          allowPrivateTags: allowPrivateTags,
          keyboardAcceptAutofocus: index == lastActionableIndex,
        );
      },
    );
  }
}
