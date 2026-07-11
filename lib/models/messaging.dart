import 'package:flutter/material.dart';

import 'enums.dart';

class MessageUserTag {
  final String messageId;
  final String threadId;
  final String tag;

  const MessageUserTag({
    required this.messageId,
    required this.threadId,
    required this.tag,
  });
}

class MessageThread {
  final String id;
  final String subject;
  final String category;
  final List<Message> messages;
  final DateTime lastActivity;
  final bool hasUnread;
  final String? childId;
  final String audience;

  MessageThread({
    required this.id,
    required this.subject,
    required this.category,
    required this.messages,
    required this.lastActivity,
    this.hasUnread = false,
    this.childId,
    this.audience = 'parents',
  });

  bool get isFamilyAudience => audience == 'family';

  IconData get categoryIcon {
    switch (category) {
      case 'Rodzina':
        return Icons.family_restroom;
      case 'Wszystkie':
        return Icons.forum_outlined;
      case 'Szkoła':
        return Icons.school;
      case 'Zdrowie':
        return Icons.medical_services;
      case 'Finanse':
      case 'Finansowe':
        return Icons.account_balance_wallet;
      case 'Zmiana grafiku':
        return Icons.swap_horiz;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'Rodzina':
        return const Color(0xFF00897B);
      case 'Wszystkie':
        return const Color(0xFF546E7A);
      case 'Szkoła':
        return const Color(0xFF1565C0);
      case 'Zdrowie':
        return const Color(0xFFD32F2F);
      case 'Finanse':
      case 'Finansowe':
        return const Color(0xFF388E3C);
      case 'Zmiana grafiku':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

class Message {
  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final String content;
  final String? aiSuggestedContent;
  final MessageTone tone;
  final List<MessageAttachment> attachments;
  final DateTime sentAt;
  final bool isDelivered;
  final bool isRead;
  final String hash;
  final bool isShielded;

  Message({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.aiSuggestedContent,
    required this.tone,
    required this.attachments,
    required this.sentAt,
    this.isDelivered = true,
    this.isRead = false,
    required this.hash,
    this.isShielded = false,
  });
}

class MessageAttachment {
  final String id;
  final String name;
  final String type;
  final int sizeBytes;

  MessageAttachment({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeBytes,
  });
}
