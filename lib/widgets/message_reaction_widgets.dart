import 'dart:async';

import 'package:flutter/material.dart';

import '../config/message_reactions.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// WhatsApp-style quick reaction bar.
class MessageReactionPicker extends StatelessWidget {
  final String? selectedEmoji;
  final ValueChanged<String> onSelect;

  const MessageReactionPicker({
    super.key,
    required this.selectedEmoji,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      color: Colors.white,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in quickMessageReactions)
              _ReactionEmojiButton(
                emoji: emoji,
                selected: selectedEmoji == emoji,
                onTap: () => onSelect(emoji),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionEmojiButton extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionEmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryTeal.withValues(alpha: 0.16)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

class MessageReactionChips extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String? viewerUserId;
  final bool alignEnd;
  final ValueChanged<String>? onEmojiTap;

  const MessageReactionChips({
    super.key,
    required this.reactions,
    required this.viewerUserId,
    this.alignEnd = false,
    this.onEmojiTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = <String, int>{};
    final mine = <String>{};
    for (final reaction in reactions) {
      counts.update(reaction.emoji, (value) => value + 1, ifAbsent: () => 1);
      if (viewerUserId != null && reaction.userId == viewerUserId) {
        mine.add(reaction.emoji);
      }
    }

    final ordered = [
      ...quickMessageReactions.where(counts.containsKey),
      ...counts.keys.where((emoji) => !quickMessageReactions.contains(emoji)),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 0 : 6,
        right: 6,
        top: 2,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final emoji in ordered)
            _ReactionCountChip(
              emoji: emoji,
              count: counts[emoji] ?? 0,
              mine: mine.contains(emoji),
              onTap: onEmojiTap == null ? null : () => onEmojiTap!(emoji),
            ),
        ],
      ),
    );
  }
}

class _ReactionCountChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;

  const _ReactionCountChip({
    required this.emoji,
    required this.count,
    required this.mine,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mine
            ? AppTheme.primaryTeal.withValues(alpha: 0.14)
            : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: mine
              ? AppTheme.primaryTeal.withValues(alpha: 0.45)
              : const Color(0xFFD0D5DD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          if (count > 1) ...[
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: mine ? AppTheme.primaryTeal : AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

Future<String?> showMessageReactionPicker({
  required BuildContext context,
  required Offset globalPosition,
  String? selectedEmoji,
}) {
  final overlay = Overlay.of(context);
  final screen = MediaQuery.sizeOf(context);
  const pickerWidth = 280.0;
  final left = (globalPosition.dx - pickerWidth / 2)
      .clamp(12.0, screen.width - pickerWidth - 12);
  final top = (globalPosition.dy - 64).clamp(48.0, screen.height - 80);

  late OverlayEntry entry;
  final completer = Completer<String?>();

  void finish(String? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => finish(null),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: MessageReactionPicker(
              selectedEmoji: selectedEmoji,
              onSelect: finish,
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
  return completer.future;
}
