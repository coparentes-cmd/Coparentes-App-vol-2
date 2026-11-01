import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/message_tags.dart';
import '../../../data/api/app_api_client.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../services/message_attachment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/calendar_date_utils.dart';
import '../../../utils/file_download.dart';
import '../../../utils/layout_utils.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/swap_message_utils.dart';
import '../../../widgets/message_reaction_widgets.dart';
import '../../../widgets/message_status_indicator.dart';
import '../../../widgets/message_tag_widgets.dart';
import 'e2e_message_text.dart';
import 'schedule_message_actions.dart';
import 'swap_message_actions.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final String threadId;
  final String? threadCategory;
  final bool isMe;
  final bool allowPrivateTags;
  final MessageGroupInfo group;
  final bool keyboardAcceptAutofocus;

  const MessageBubble({
    super.key,
    required this.message,
    required this.threadId,
    this.threadCategory,
    required this.isMe,
    this.allowPrivateTags = false,
    required this.group,
    this.keyboardAcceptAutofocus = false,
  });

  @override
  State<MessageBubble> createState() => MessageBubbleState();
}

class MessageBubbleState extends State<MessageBubble> {
  bool _downloadingAttachment = false;
  bool _respondingToSwap = false;
  bool _respondingToSchedule = false;
  bool _respondingToException = false;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = chatBubbleMaxWidthFor(context);
    final calendar = context.watch<CalendarProvider>();
    final app = context.watch<AppProvider>();
    final workspace = app.currentWorkspace;
    final senderRole = senderRoleForMessage(widget.message, workspace);
    final bubbleStyle = messageBubbleStyleForRole(senderRole);
    final viewerUserId = app.currentUser?.id;
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
    final messaging = context.watch<MessagingProvider>();
    final messageTags = widget.allowPrivateTags
        ? messaging.tagsForMessage(widget.message.id)
        : const <String>{};
    final reactions = messaging.reactionsForMessage(widget.message.id);
    final isReadOnly = app.currentUser?.role == UserRole.observer;
    final reactAsUserId = (!isReadOnly) ? viewerUserId : null;
    final canReact = reactAsUserId != null;
    final myReaction = canReact
        ? messaging.myReactionEmoji(
            messageId: widget.message.id,
            userId: reactAsUserId,
          )
        : null;

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
          // WhatsApp-style: smiley sits beside the bubble (outer/center side).
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canReact && widget.isMe) ...[
                _buildReactionFaceButton(
                  context,
                  viewerUserId: reactAsUserId,
                  myReaction: myReaction,
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: GestureDetector(
                  // Mobile: long-press. Desktop web: right-click.
                  onLongPressStart: canReact
                      ? (details) => _showReactionPicker(
                            context,
                            details.globalPosition,
                            viewerUserId: reactAsUserId,
                          )
                      : null,
                  onSecondaryTapDown: canReact
                      ? (details) => _showReactionPicker(
                            context,
                            details.globalPosition,
                            viewerUserId: reactAsUserId,
                          )
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
                          if (widget.message.content.isNotEmpty ||
                              widget.message.needsDecryption)
                            E2eMessageText(
                              message: widget.message,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.35,
                                color: bubbleStyle.textColor,
                              ),
                            ),
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
                                          color:
                                              bubbleStyle.attachmentForeground,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${att.name} (${formatAttachmentSize(att.sizeBytes)})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: bubbleStyle
                                                  .attachmentForeground,
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
                                    onTap: () => _editMessageTags(
                                      context,
                                      messageTags,
                                    ),
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
              if (canReact && !widget.isMe) ...[
                const SizedBox(width: 6),
                _buildReactionFaceButton(
                  context,
                  viewerUserId: reactAsUserId,
                  myReaction: myReaction,
                ),
              ],
            ],
          ),
          if (reactions.isNotEmpty) ...[
            const SizedBox(height: 2),
            MessageReactionChips(
              reactions: reactions,
              viewerUserId: viewerUserId,
              alignEnd: widget.isMe,
              onEmojiTap: canReact
                  ? (emoji) => _toggleReaction(
                        context,
                        emoji: emoji,
                        viewerUserId: reactAsUserId,
                      )
                  : null,
            ),
          ],
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
      messenger.showTopSnackBar(
        SnackBar(
          content: Text(
            approve
                ? context.tr('Grafik zaakceptowany — kalendarz zaktualizowany.') : context.tr('Propozycja grafiku odrzucona.'),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showTopSnackBar(
        SnackBar(
          content: Text(context.tr('Nie udało się zapisać odpowiedzi na grafik.')),
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
      messenger.showTopSnackBar(
        SnackBar(
          content: Text(
            approve
                ? context.tr('Wyjątek zaakceptowany — kalendarz zaktualizowany.') : context.tr('Wniosek o wyjątek odrzucony.'),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showTopSnackBar(
        SnackBar(
          content: Text(context.tr('Nie udało się zapisać odpowiedzi na wyjątek.')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingToException = false);
      }
    }
  }

  /// WhatsApp-like circular smiley beside the bubble.
  Widget _buildReactionFaceButton(
    BuildContext context, {
    required String viewerUserId,
    required String? myReaction,
  }) {
    return Tooltip(
      message: context.tr('Reakcja'),
      child: Builder(
        builder: (buttonContext) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final box = buttonContext.findRenderObject() as RenderBox?;
                final origin = box?.localToGlobal(
                      Offset((box.size.width) / 2, 0),
                    ) ??
                    Offset.zero;
                _showReactionPicker(
                  context,
                  origin,
                  viewerUserId: viewerUserId,
                );
              },
              customBorder: const CircleBorder(),
              child: Ink(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2F3A)
                      : const Color(0xFFF0F2F5),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3D4450)
                        : const Color(0xFFE4E6EB),
                  ),
                ),
                child: Center(
                  child: myReaction != null
                      ? Text(myReaction, style: const TextStyle(fontSize: 14))
                      : Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          size: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0B3B8)
                              : const Color(0xFF667781),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReactionPicker(
    BuildContext context,
    Offset globalPosition, {
    required String viewerUserId,
  }) async {
    final messaging = context.read<MessagingProvider>();
    final selected = messaging.myReactionEmoji(
      messageId: widget.message.id,
      userId: viewerUserId,
    );
    final emoji = await showMessageReactionPicker(
      context: context,
      globalPosition: globalPosition,
      selectedEmoji: selected,
    );
    if (!mounted || emoji == null) {
      return;
    }
    await _toggleReaction(
      context,
      emoji: emoji,
      viewerUserId: viewerUserId,
    );
  }

  Future<void> _toggleReaction(
    BuildContext context, {
    required String emoji,
    required String viewerUserId,
  }) async {
    final app = context.read<AppProvider>();
    try {
      await context.read<MessagingProvider>().setMessageReaction(
            messageId: widget.message.id,
            threadId: widget.threadId,
            userId: viewerUserId,
            emoji: emoji,
            localOnly: app.isDemoMode,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is ApiException &&
              error.message == 'reactions_unavailable'
          ? context.tr(
              'Reakcje nie są jeszcze dostępne na serwerze. Spróbuj później.',
            )
          : context.tr('Nie udało się zapisać reakcji.');
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
          ? context.tr('Nie udało się zapisać etykiet — odśwież wiadomości i spróbuj ponownie.') : context.tr('Nie udało się zapisać etykiet.');
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(context.tr(message)),
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

      messenger.showTopSnackBar(
        SnackBar(
          content: Text(
            status == SwapStatus.accepted
                ? context.tr('Zamiana zaakceptowana — kalendarz zaktualizowany.')
                : context.tr('Wniosek o zamianę odrzucony.'),
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showTopSnackBar(
        SnackBar(
          content: Text(context.tr('Nie udało się zapisać odpowiedzi na wniosek.')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingToSwap = false);
      }
    }
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
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text(context.tr('Nie udało się pobrać załącznika.'))),
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
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _formatTime(DateTime dt) => formatClockTime(dt);
}
