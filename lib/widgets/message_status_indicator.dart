import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// WhatsApp-style receipt: two gray ticks = sent, two blue ticks = read.
class MessageReceiptFooter extends StatelessWidget {
  final Message message;
  final bool isMe;
  final DateTime sentAt;
  final bool onColoredBubble;

  const MessageReceiptFooter({
    super.key,
    required this.message,
    required this.isMe,
    required this.sentAt,
    this.onColoredBubble = false,
  });

  static const Color _readBlue = Color(0xFF34B7F1);

  @override
  Widget build(BuildContext context) {
    final timeColor = onColoredBubble
        ? Colors.white.withValues(alpha: 0.78)
        : AppTheme.textHint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(sentAt),
          style: TextStyle(fontSize: 11, color: timeColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildReceiptIcon(),
        ],
      ],
    );
  }

  Widget _buildReceiptIcon() {
    final pendingColor = onColoredBubble
        ? Colors.white.withValues(alpha: 0.65)
        : AppTheme.textHint;
    final sentColor = onColoredBubble
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.textSecondary;

    if (!message.isDelivered) {
      return Icon(
        Icons.schedule,
        size: 12,
        color: pendingColor,
      );
    }

    // Read = blue double ticks. Sent/delivered (not yet read) = gray double ticks.
    return Icon(
      Icons.done_all,
      size: 14,
      color: message.isRead ? _readBlue : sentColor,
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

String messageReceiptLabel(Message message, {required bool isMe}) {
  if (!isMe) {
    return 'Wiadomość';
  }
  if (!message.isDelivered) {
    return 'Wysyłanie…';
  }
  if (message.isRead) {
    return 'Odczytana';
  }
  return 'Wysłana';
}
