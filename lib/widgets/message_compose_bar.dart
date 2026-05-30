import 'package:flutter/material.dart';

import '../services/message_attachment_service.dart';
import '../theme/app_theme.dart';

class MessageComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final List<PendingMessageAttachment> pendingAttachments;
  final VoidCallback onPickAttachment;
  final ValueChanged<String> onRemoveAttachment;
  final VoidCallback? onSend;
  final bool sending;
  final ValueChanged<String>? onChanged;

  const MessageComposeBar({
    super.key,
    required this.controller,
    required this.pendingAttachments,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onSend,
    this.sending = false,
    this.onChanged,
  });

  bool get _canSend =>
      !sending &&
      (controller.text.trim().isNotEmpty || pendingAttachments.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset > 0 ? bottomInset + 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pendingAttachments
                    .map(
                      (attachment) => InputChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          '${attachment.name} (${formatAttachmentSize(attachment.sizeBytes)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => onRemoveAttachment(attachment.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 28,
                  color: pendingAttachments.length >= maxMessageAttachmentsPerMessage
                      ? AppTheme.textHint
                      : AppTheme.textSecondary,
                ),
                tooltip: 'Dodaj załącznik',
                onPressed:
                    pendingAttachments.length >= maxMessageAttachmentsPerMessage
                        ? null
                        : onPickAttachment,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF4),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE0E0E5)),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (_canSend) {
                        onSend?.call();
                      }
                    },
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Wiadomość',
                      hintStyle: TextStyle(color: AppTheme.textHint),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (sending)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_canSend)
                Material(
                  color: AppTheme.primaryTeal,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSend,
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 34, height: 34),
            ],
          ),
        ],
      ),
    );
  }
}
