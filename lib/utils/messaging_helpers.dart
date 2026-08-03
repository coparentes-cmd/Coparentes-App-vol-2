import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

bool messageIsUnreadForViewer(Message message, String viewerUserId) {
  return !message.isRead && message.senderId != viewerUserId;
}

bool threadHasUnreadForViewer(MessageThread thread, String viewerUserId) {
  if (thread.messages.any(
    (message) => messageIsUnreadForViewer(message, viewerUserId),
  )) {
    return true;
  }
  // Trust server flag when message payloads are stale/inconsistent.
  return thread.hasUnread;
}

int countUnreadThreadsForViewer(
  List<MessageThread> threads,
  String viewerUserId,
) {
  return threads
      .where((thread) => threadHasUnreadForViewer(thread, viewerUserId))
      .length;
}

int countUnreadMessagesForViewer(
  List<MessageThread> threads,
  String viewerUserId,
) {
  return collectUnreadMessagesForViewer(threads, viewerUserId).length;
}

/// Unread incoming messages across threads. If [MessageThread.hasUnread] is set
/// but no message is flagged unread (stale sync), falls back to the latest
/// incoming message so the Nieprzeczytane tab stays accurate.
List<({MessageThread thread, Message message})> collectUnreadMessagesForViewer(
  List<MessageThread> threads,
  String viewerUserId,
) {
  final items = <({MessageThread thread, Message message})>[];
  for (final thread in threads) {
    var foundUnreadMessage = false;
    for (final message in thread.messages) {
      if (messageIsUnreadForViewer(message, viewerUserId)) {
        items.add((thread: thread, message: message));
        foundUnreadMessage = true;
      }
    }
    if (!foundUnreadMessage && thread.hasUnread) {
      Message? latestIncoming;
      for (final message in thread.messages) {
        if (message.senderId == viewerUserId) {
          continue;
        }
        if (latestIncoming == null ||
            message.sentAt.isAfter(latestIncoming.sentAt)) {
          latestIncoming = message;
        }
      }
      if (latestIncoming != null) {
        items.add((thread: thread, message: latestIncoming));
      }
    }
  }
  items.sort((a, b) => b.message.sentAt.compareTo(a.message.sentAt));
  return items;
}

/// Keeps locally-read incoming messages as read when a stale poll returns
/// older unread flags (race with mark-as-read).
MessageThread mergeThreadPreservingLocalReads({
  required MessageThread remote,
  required MessageThread? local,
}) {
  if (local == null || local.messages.isEmpty) {
    return remote;
  }
  final localById = {
    for (final message in local.messages) message.id: message,
  };
  var changed = false;
  final mergedMessages = remote.messages.map((message) {
    final previous = localById[message.id];
    if (previous != null && previous.isRead && !message.isRead) {
      changed = true;
      return message.copyWith(isRead: true);
    }
    return message;
  }).toList();
  if (!changed) {
    return remote;
  }
  return MessageThread(
    id: remote.id,
    subject: remote.subject,
    category: remote.category,
    childId: remote.childId,
    audience: remote.audience,
    lastActivity: remote.lastActivity,
    // Prefer remote viewer-specific flag; clear it when nothing is unread.
    hasUnread: remote.hasUnread && mergedMessages.any((message) => !message.isRead),
    messages: mergedMessages,
  );
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

/// iMessage-style chat canvas background — light and airy.
const Color imessageChatBackground = Color(0xFFF6F7FA);

UserRole? senderRoleForMessage(Message message, Workspace? workspace) {
  if (workspace == null) {
    return null;
  }
  for (final member in workspace.members) {
    if (member.id == message.senderId) {
      return member.role;
    }
  }
  return null;
}

class MessageBubbleStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color senderNameColor;
  final Color attachmentBackground;
  final Color attachmentForeground;

  const MessageBubbleStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.senderNameColor,
    required this.attachmentBackground,
    required this.attachmentForeground,
  });
}

MessageBubbleStyle messageBubbleStyleForRole(UserRole? role) {
  switch (role) {
    case UserRole.parentA:
      return MessageBubbleStyle(
        backgroundColor: AppTheme.coralColor.withValues(alpha: 0.12),
        borderColor: AppTheme.coralColor.withValues(alpha: 0.2),
        textColor: const Color(0xFF3A2A28),
        secondaryTextColor: const Color(0xFF6E5653),
        senderNameColor: AppTheme.coralColor,
        attachmentBackground: AppTheme.coralColor.withValues(alpha: 0.16),
        attachmentForeground: const Color(0xFF5C3330),
      );
    case UserRole.parentB:
      return MessageBubbleStyle(
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
        borderColor: AppTheme.accentColor.withValues(alpha: 0.22),
        textColor: const Color(0xFF1A3348),
        secondaryTextColor: const Color(0xFF4A6278),
        senderNameColor: AppTheme.accentColor,
        attachmentBackground: AppTheme.accentColor.withValues(alpha: 0.14),
        attachmentForeground: const Color(0xFF1A4A7A),
      );
    default:
      return const MessageBubbleStyle(
        backgroundColor: Color(0xFFF1F3F6),
        borderColor: Color(0xFFE3E7EE),
        textColor: AppTheme.textPrimary,
        secondaryTextColor: AppTheme.textSecondary,
        senderNameColor: AppTheme.textSecondary,
        attachmentBackground: Color(0xFFE8ECF2),
        attachmentForeground: AppTheme.textSecondary,
      );
  }
}
