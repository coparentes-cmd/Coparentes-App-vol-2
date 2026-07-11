import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/message_tags.dart';
import '../../../data/api/app_api_client.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../services/ai_guidance_service.dart';
import '../../../services/message_attachment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/file_download.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/swap_message_utils.dart';
import '../../../widgets/message_status_indicator.dart';
import '../../../widgets/message_tag_widgets.dart';
import 'schedule_message_actions.dart';
import 'swap_message_actions.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final String threadId;
  final String? threadCategory;
  final bool isMe;
  final bool aiShieldEnabled;
  final bool allowPrivateTags;
  final MessageGroupInfo group;
  final bool keyboardAcceptAutofocus;

  const MessageBubble({
    super.key,
    required this.message,
    required this.threadId,
    this.threadCategory,
    required this.isMe,
    required this.aiShieldEnabled,
    this.allowPrivateTags = false,
    required this.group,
    this.keyboardAcceptAutofocus = false,
  });

  @override
  State<MessageBubble> createState() => MessageBubbleState();
}

class MessageBubbleState extends State<MessageBubble> {
  bool _showOriginal = false;
  bool _downloadingAttachment = false;
  bool _respondingToSwap = false;
  bool _respondingToSchedule = false;
  bool _respondingToException = false;

  bool get _isShielded =>
      widget.aiShieldEnabled &&
      !widget.isMe &&
      widget.message.tone == MessageTone.tense;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;
    final calendar = context.watch<CalendarProvider>();
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final senderRole = senderRoleForMessage(widget.message, workspace);
    final bubbleStyle = messageBubbleStyleForRole(senderRole);
    final viewerUserId = context.read<AppProvider>().currentUser?.id;
    final swap = isSwapScheduleThread(widget.threadCategory)
        ? findPendingSwapForMessage(
            messageContent: widget.message.content,
            messageSenderId: widget.message.senderId,
            swaps: calendar.swapRequests,
          )
        : null;
    final schedule = isSwapScheduleThread(widget.threadCategory)
        ? findPendingScheduleForMessage(
            messageContent: widget.message.content,
            messageSenderId: widget.message.senderId,
            schedule: calendar.custodySchedule,
          )
        : null;
    final exception = isSwapScheduleThread(widget.threadCategory)
        ? findPendingExceptionForMessage(
            messageContent: widget.message.content,
            messageSenderId: widget.message.senderId,
            exceptions: calendar.custodyExceptions,
          )
        : null;
    final showSwapActions = swap != null &&
        canRespondToSwapMessage(
          swap: swap,
          viewerUserId: viewerUserId,
        );
    final showScheduleActions = schedule != null &&
        canRespondToScheduleMessage(
          schedule: schedule,
          viewerUserId: viewerUserId,
        );
    final showExceptionActions = exception != null &&
        canRespondToExceptionMessage(
          exception: exception,
          viewerUserId: viewerUserId,
        );
    final messageTags = widget.allowPrivateTags
        ? context.watch<MessagingProvider>().tagsForMessage(widget.message.id)
        : const <String>{};
    final isReadOnly =
        context.watch<AppProvider>().currentUser?.role == UserRole.observer;

    return Padding(
      padding: EdgeInsets.only(top: widget.group.topSpacing),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.group.showSenderName && !widget.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                widget.message.senderName,
                style: TextStyle(
                  fontSize: 11,
                  color: bubbleStyle.senderNameColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
              onLongPress: widget.allowPrivateTags && !isReadOnly
                  ? () => _editMessageTags(context, messageTags)
                  : null,
              child: IntrinsicWidth(
                child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              decoration: BoxDecoration(
                color: bubbleStyle.backgroundColor,
                border: Border.all(color: bubbleStyle.borderColor),
                borderRadius: imessageBubbleRadius(
                  isMe: widget.isMe,
                  isFirstInGroup: widget.group.isFirstInGroup,
                  isLastInGroup: widget.group.isLastInGroup,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isShielded && !_showOriginal) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield,
                          size: 12,
                          color: bubbleStyle.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'AI Shield – wersja logistyczna',
                            style: TextStyle(
                              fontSize: 11,
                              color: bubbleStyle.secondaryTextColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _extractLogistics(widget.message.content),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: bubbleStyle.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _showOriginal = true),
                      child: Text(
                        'Pokaż oryginał',
                        style: TextStyle(
                          fontSize: 11,
                          color: bubbleStyle.senderNameColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else ...[
                    if (widget.message.content.isNotEmpty)
                      Text(
                        widget.message.content,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: bubbleStyle.textColor,
                        ),
                      ),
                    if (_isShielded && _showOriginal) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _showOriginal = false),
                        child: Text(
                          'Ukryj oryginał',
                          style: TextStyle(
                            fontSize: 11,
                            color: bubbleStyle.senderNameColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (widget.message.attachments.isNotEmpty) ...[
                    if (widget.message.content.isNotEmpty)
                      const SizedBox(height: 8),
                    ...widget.message.attachments.map(
                      (att) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: _downloadingAttachment
                              ? null
                              : () => _downloadAttachment(att),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleStyle.attachmentBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _downloadingAttachment
                                      ? Icons.hourglass_top
                                      : Icons.attach_file,
                                  size: 14,
                                  color: bubbleStyle.attachmentForeground,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${att.name} (${formatAttachmentSize(att.sizeBytes)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: bubbleStyle.attachmentForeground,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.allowPrivateTags && !isReadOnly)
                        Tooltip(
                          message: 'Etykiety',
                          child: InkWell(
                            onTap: () =>
                                _editMessageTags(context, messageTags),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                messageTags.isEmpty
                                    ? Icons.label_outline
                                    : Icons.label,
                                size: 14,
                                color: messageTags.isEmpty
                                    ? bubbleStyle.secondaryTextColor
                                    : messageTagColor(
                                        messageTags.first,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.allowPrivateTags && !isReadOnly)
                        const SizedBox(width: 4),
                      Tooltip(
                        message: widget.isMe
                            ? messageReceiptLabel(
                                widget.message,
                                isMe: true,
                              )
                            : _formatTime(widget.message.sentAt),
                        child: MessageReceiptFooter(
                          message: widget.message,
                          isMe: widget.isMe,
                          sentAt: widget.message.sentAt,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
          if (widget.allowPrivateTags && messageTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: widget.isMe ? 0 : 6, right: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment:
                    widget.isMe ? WrapAlignment.end : WrapAlignment.start,
                children: messageTags
                    .map(
                      (tag) => MessageTagChip(
                        tag: tag,
                        compact: true,
                        onTap: isReadOnly
                            ? null
                            : () => _editMessageTags(context, messageTags),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (showSwapActions) ...[
            const SizedBox(height: 6),
            SwapMessageActions(
              swap: swap,
              alignEnd: widget.isMe,
              isLoading: _respondingToSwap,
              autofocus: widget.keyboardAcceptAutofocus,
              onAccept: () => _respondToSwap(swap, SwapStatus.accepted),
              onReject: () => _respondToSwap(swap, SwapStatus.rejected),
            ),
          ],
          if (showScheduleActions) ...[
            const SizedBox(height: 6),
            ScheduleMessageActions(
              alignEnd: widget.isMe,
              isLoading: _respondingToSchedule,
              autofocus: widget.keyboardAcceptAutofocus,
              onAccept: () => _respondToSchedule(schedule, approve: true),
              onReject: () => _respondToSchedule(schedule, approve: false),
            ),
          ],
          if (showExceptionActions) ...[
            const SizedBox(height: 6),
            ScheduleMessageActions(
              alignEnd: widget.isMe,
              isLoading: _respondingToException,
              autofocus: widget.keyboardAcceptAutofocus,
              onAccept: () => _respondToException(exception, approve: true),
              onReject: () => _respondToException(exception, approve: false),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respondToSchedule(
    CustodySchedule schedule, {
    required bool approve,
  }) async {
    if (_respondingToSchedule) {
      return;
    }

    setState(() => _respondingToSchedule = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppProvider>();
    final calendar = context.read<CalendarProvider>();
    final messaging = context.read<MessagingProvider>();

    try {
      if (app.isDemoMode) {
        await calendar.respondToScheduleDemo(
          approve: approve,
          approvedById: app.currentUser?.id,
        );
      } else {
        await calendar.respondToSchedule(
          scheduleId: schedule.id,
          approve: approve,
        );
      }
      await messaging.loadThreads(
        viewerUserId: app.currentUser?.id,
        silent: true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Grafik zaakceptowany — kalendarz zaktualizowany.'
                : 'Propozycja grafiku odrzucona.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać odpowiedzi na grafik.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingToSchedule = false);
      }
    }
  }

  Future<void> _respondToException(
    CustodyException exception, {
    required bool approve,
  }) async {
    if (_respondingToException) {
      return;
    }

    setState(() => _respondingToException = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppProvider>();
    final calendar = context.read<CalendarProvider>();
    final messaging = context.read<MessagingProvider>();

    try {
      await calendar.respondToException(
        exceptionId: exception.id,
        approve: approve,
      );
      await messaging.loadThreads(
        viewerUserId: app.currentUser?.id,
        silent: true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Wyjątek zaakceptowany — kalendarz zaktualizowany.'
                : 'Wniosek o wyjątek odrzucony.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać odpowiedzi na wyjątek.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingToException = false);
      }
    }
  }

  Future<void> _editMessageTags(
    BuildContext context,
    Set<String> currentTags,
  ) async {
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MessageTagEditorSheet(
        initialTags: currentTags.toList(),
        customSuggestions: customMessageTags(
          context.read<MessagingProvider>().allUserTags,
        ).toList(),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    try {
      await context.read<MessagingProvider>().setMessageTags(
            messageId: widget.message.id,
            tags: updated,
            localOnly: context.read<AppProvider>().isDemoMode,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is ApiException && error.message == 'message_not_found'
          ? 'Nie udało się zapisać etykiet — odśwież wiadomości i spróbuj ponownie.'
          : 'Nie udało się zapisać etykiet.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _respondToSwap(SwapRequest swap, SwapStatus status) async {
    if (_respondingToSwap) {
      return;
    }

    setState(() => _respondingToSwap = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppProvider>();
    final calendar = context.read<CalendarProvider>();
    final messaging = context.read<MessagingProvider>();

    try {
      if (calendar.swapRequests.isEmpty) {
        await calendar.load(silent: true);
      }

      await calendar.respondToSwap(
        swap.id,
        status,
        note: status == SwapStatus.rejected ? 'Odrzucono z czatu.' : null,
      );

      await messaging.loadThreads(
        viewerUserId: app.currentUser?.id,
        silent: true,
      );

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == SwapStatus.accepted
                ? 'Zamiana zaakceptowana — kalendarz zaktualizowany.'
                : 'Wniosek o zamianę odrzucony.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać odpowiedzi na wniosek.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingToSwap = false);
      }
    }
  }

  String _extractLogistics(String content) {
    return AiGuidanceService.analyze(content).logisticsSummary;
  }

  Future<void> _downloadAttachment(MessageAttachment attachment) async {
    setState(() => _downloadingAttachment = true);
    final payload = await context.read<MessagingProvider>().downloadMessageAttachment(
          threadId: widget.threadId,
          messageId: widget.message.id,
          attachmentId: attachment.id,
        );
    if (!mounted) {
      return;
    }
    setState(() => _downloadingAttachment = false);

    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się pobrać załącznika.')),
      );
      return;
    }

    try {
      final contentBase64 = payload['contentBase64'] as String?;
      if (contentBase64 == null || contentBase64.isEmpty) {
        throw StateError('Brak danych pliku.');
      }
      await saveBytesAsFile(
        fileName: payload['name'] as String? ?? attachment.name,
        mimeType: payload['type'] as String? ?? attachment.type,
        bytes: decodeAttachmentBase64(contentBase64),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class ToneIndicator extends StatelessWidget {
  final MessageTone tone;

  const ToneIndicator({super.key, required this.tone});

  @override
  Widget build(BuildContext context) {
    final isNeutral = tone == MessageTone.neutral || tone == MessageTone.positive;
    final label = switch (tone) {
      MessageTone.neutral => 'Ton: Neutralny',
      MessageTone.positive => 'Ton: Pozytywny',
      MessageTone.tense => 'Ton: Napięty – rozważ AI Coach',
      MessageTone.aggressive => 'Ton: Agresywny – rozważ AI Coach',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isNeutral ? AppTheme.successColor : AppTheme.warningColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNeutral ? Icons.sentiment_satisfied : Icons.sentiment_neutral,
            size: 14,
            color: isNeutral ? AppTheme.successColor : AppTheme.warningColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isNeutral ? AppTheme.successColor : AppTheme.warningColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
