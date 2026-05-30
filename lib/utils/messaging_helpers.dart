import 'package:flutter/material.dart';

import '../models/models.dart';

bool threadHasUnreadForViewer(MessageThread thread, String viewerUserId) {
  return thread.messages.any(
    (message) => !message.isRead && message.senderId != viewerUserId,
  );
}

int countUnreadThreadsForViewer(
  List<MessageThread> threads,
  String viewerUserId,
) {
  return threads
      .where((thread) => threadHasUnreadForViewer(thread, viewerUserId))
      .length;
}

Message? findNewIncomingMessage(
  List<MessageThread> threads,
  String viewerUserId,
  Map<String, Set<String>> knownMessageIds,
) {
  Message? newest;
  for (final thread in threads) {
    final known = knownMessageIds[thread.id] ?? const {};
    for (final message in thread.messages) {
      if (message.senderId == viewerUserId) {
        continue;
      }
      if (known.contains(message.id)) {
        continue;
      }
      if (newest == null || message.sentAt.isAfter(newest.sentAt)) {
        newest = message;
      }
    }
  }
  return newest;
}

void syncKnownMessageIds(
  List<MessageThread> threads,
  Map<String, Set<String>> knownMessageIds,
) {
  for (final thread in threads) {
    knownMessageIds[thread.id] = thread.messages.map((message) => message.id).toSet();
  }
}

String formatMessageNotification(Message message) {
  final preview = message.content.length > 80
      ? '${message.content.substring(0, 80)}…'
      : message.content;
  return '${message.senderName}: $preview';
}

class MessageGroupInfo {
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const MessageGroupInfo({
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  bool get showSenderName => isFirstInGroup;
  double get topSpacing => isFirstInGroup ? 10 : 2;
}

MessageGroupInfo messageGroupInfo(List<Message> messages, int index) {
  final message = messages[index];
  final previous = index > 0 ? messages[index - 1] : null;
  final next = index < messages.length - 1 ? messages[index + 1] : null;
  final sameSenderAsPrevious = previous?.senderId == message.senderId;
  final sameSenderAsNext = next?.senderId == message.senderId;

  return MessageGroupInfo(
    isFirstInGroup: !sameSenderAsPrevious,
    isLastInGroup: !sameSenderAsNext,
  );
}

BorderRadius imessageBubbleRadius({
  required bool isMe,
  required bool isFirstInGroup,
  required bool isLastInGroup,
}) {
  const large = 20.0;
  const small = 5.0;

  if (isMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(large),
      topRight: Radius.circular(isFirstInGroup ? large : small),
      bottomLeft: const Radius.circular(large),
      bottomRight: Radius.circular(isLastInGroup ? small : small),
    );
  }

  return BorderRadius.only(
    topLeft: Radius.circular(isFirstInGroup ? large : small),
    topRight: const Radius.circular(large),
    bottomLeft: Radius.circular(isLastInGroup ? small : small),
    bottomRight: const Radius.circular(large),
  );
}

/// iMessage-style chat canvas background.
const Color imessageChatBackground = Color(0xFFE9E9EB);
