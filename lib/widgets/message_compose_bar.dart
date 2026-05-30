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
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                  Icons.attach_file,
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
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (_canSend) {
                      onSend?.call();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Napisz wiadomość...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      borderSide: BorderSide(color: AppTheme.dividerColor),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.send,
                        color: _canSend ? AppTheme.primaryTeal : AppTheme.textHint,
                      ),
                onPressed: _canSend ? onSend : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
