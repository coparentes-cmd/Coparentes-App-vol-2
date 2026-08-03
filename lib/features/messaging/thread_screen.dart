import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/messaging_categories.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/exports_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/offline_sync_provider.dart';
import '../../../services/ai_guidance_service.dart';
import '../../../services/message_attachment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/swap_message_utils.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/message_compose_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thread_messages_list.dart';

class ThreadScreen extends StatefulWidget {
  final String threadId;
  final VoidCallback? onBack;
  final bool allowPrivateTags;

  const ThreadScreen({
    super.key,
    required this.threadId,
    this.onBack,
    this.allowPrivateTags = false,
  });

  @override
  State<ThreadScreen> createState() => ThreadScreenState();
}

class ThreadScreenState extends State<ThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageTone _analyzedTone = MessageTone.neutral;
  bool _showAiSuggestion = false;
  String _aiSuggestion = '';
  Timer? _livePollTimer;
  bool _sending = false;
  bool _initialScrollDone = false;
  final List<PendingMessageAttachment> _pendingAttachments = [];

  Future<void> _pickAttachment() async {
    if (_pendingAttachments.length >= maxMessageAttachmentsPerMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Możesz dodać maksymalnie 3 załączniki.'),
        ),
      );
      return;
    }

    try {
      final picked = await MessageAttachmentPicker.pickAttachment();
      if (!mounted || picked == null) {
        return;
      }
      setState(() => _pendingAttachments.add(picked));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void _removeAttachment(String attachmentId) {
    setState(
      () => _pendingAttachments.removeWhere((item) => item.id == attachmentId),
    );
  }

  void _pollThreadMessages() {
    final appProvider = context.read<AppProvider>();
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: false,
          silent: true,
        );
  }

  void _scrollToLatestMessage() {
    if (_initialScrollDone || !_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    _initialScrollDone = true;
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final userId = context.read<AppProvider>().currentUser?.id;
      if (userId == null) {
        return;
      }
      context.read<MessagingProvider>().markThreadRead(
            widget.threadId,
            viewerUserId: userId,
          );
      final thread =
          context.read<MessagingProvider>().getThreadById(widget.threadId);
      if (isSwapScheduleThread(thread?.category)) {
        unawaited(context.read<CalendarProvider>().load(silent: true));
      }
      _pollThreadMessages();
      context.read<OfflineSyncProvider>().pollMessagingNow();
    });

    _livePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted) {
          return;
        }
        _pollThreadMessages();
      },
    );
  }

  @override
  void dispose() {
    _livePollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final isChild = user?.role == UserRole.child;
    final aiCoach =
        !isChild && context.watch<AppProvider>().aiCoachEnabled;
    final aiShield = context.watch<AppProvider>().aiShieldEnabled;
    final isReadOnly = user?.role == UserRole.observer;
    final thread = context.watch<MessagingProvider>().getThreadById(widget.threadId);

    if (thread == null) {
      return const Scaffold(
        body: Center(
          child: Text('Nie znaleziono watku.'),
        ),
      );
    }

    final viewerId = user?.id;
    if (viewerId != null && threadHasUnreadForViewer(thread, viewerId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<MessagingProvider>().markThreadRead(
              widget.threadId,
              viewerUserId: viewerId,
            );
      });
    }

    if (!_initialScrollDone && thread.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToLatestMessage();
        }
      });
    }

    final canPopRoute =
        widget.onBack == null && Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 22),
                        color: AppTheme.textPrimary,
                        tooltip: 'Wróć',
                        onPressed: _handleBack,
                      ),
                      Expanded(
                        child: Text(
                          threadListTitle(thread),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
                        color: AppTheme.textSecondary,
                        tooltip: 'Eksportuj wątek',
                        onPressed: () => _exportThread(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: imessageChatBackground,
                child: ThreadMessagesList(
                  messages: thread.messages,
                  threadId: widget.threadId,
                  threadCategory: thread.category,
                  viewerUserId: user?.id,
                  aiShieldEnabled: aiShield,
                  scrollController: _scrollController,
                  allowPrivateTags: widget.allowPrivateTags,
                ),
              ),
            ),

          // AI Coach area
          if (_showAiSuggestion && aiCoach)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: AppTheme.aiCoachColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sugestia AI Coach',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.aiCoachColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _aiSuggestion,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const AiDisclaimerBanner(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _showAiSuggestion = false);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Użyj oryginału'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _controller.text = _aiSuggestion;
                            setState(() => _showAiSuggestion = false);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Użyj sugestii'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Tone indicator
          if (_controller.text.isNotEmpty && aiCoach)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ToneIndicator(tone: _analyzedTone),
            ),

          // Input area
          if (!isReadOnly)
            MessageComposeBar(
              controller: _controller,
              pendingAttachments: _pendingAttachments,
              onPickAttachment: _pickAttachment,
              onRemoveAttachment: _removeAttachment,
              onSend: _sendMessage,
              sending: _sending,
              cyclingPlaceholderHints:
                  aiCoach ? AiTips.messagingPlaceholders : null,
              cyclingIntervalSeconds: 8,
              onChanged: (value) {
                setState(() {});
                if (aiCoach && value.length > 10) {
                  _analyzeTone(value);
                }
              },
            ),
        ],
      ),
      ),
    );
  }

  void _analyzeTone(String text) {
    final result = AiGuidanceService.analyze(text);
    setState(() => _analyzedTone = result.tone);
  }

  void _getAiSuggestion() {
    final result = AiGuidanceService.analyze(_controller.text);
    setState(() {
      _aiSuggestion = result.rewrite;
      _showAiSuggestion = true;
    });
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _pendingAttachments.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    final attachments =
        _pendingAttachments.map((item) => item.toApiPayload()).toList();
    final sent = await context.read<MessagingProvider>().sendMessage(
          threadId: widget.threadId,
          content: content,
          tone: _analyzedTone,
          attachments: attachments,
        );

    if (!mounted) {
      return;
    }

    setState(() => _sending = false);
    if (sent == null) {
      return;
    }

    _controller.clear();
    setState(() {
      _showAiSuggestion = false;
      _analyzedTone = MessageTone.neutral;
      _pendingAttachments.clear();
    });
  }

  void _exportThread(BuildContext context) {
    final thread = context.read<MessagingProvider>().getThreadById(widget.threadId);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eksport wątku'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Watek: ${thread?.subject ?? 'Brak'}'),
            Text('Wiadomosci: ${thread?.messages.length ?? 0}'),
            const SizedBox(height: 12),
            const Text(
              'Eksport bedzie zawieral:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('• JSON pakietu wiadomosci'),
            const Text('• Manifest integralnosci SHA-256'),
            const Text('• Metadane: czas, nadawca, dostarczenie'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final thread = context.read<MessagingProvider>().getThreadById(widget.threadId);
              if (thread == null) {
                return;
              }

              final created = await context.read<ExportsProvider>().createExport(
                type: ExportType.messages,
                fromDate: thread.messages.isEmpty
                    ? DateTime.now()
                    : thread.messages.first.sentAt,
                toDate: thread.messages.isEmpty
                    ? DateTime.now()
                    : thread.messages.last.sentAt,
                threadId: thread.id,
              );

              if (!context.mounted || created == null) {
                return;
              }

              final saved =
                  await context.read<ExportsProvider>().saveExportAsPdf(created);

              if (!context.mounted) {
                return;
              }

              final provider = context.read<ExportsProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    saved
                        ? 'Eksport wątku zapisany jako PDF.'
                        : provider.error ??
                            'Eksport utworzony, ale nie udało się zapisać PDF.',
                  ),
                  backgroundColor:
                      saved ? AppTheme.successColor : AppTheme.errorColor,
                ),
              );
            },
            child: const Text('Generuj eksport'),
          ),
        ],
      ),
    );
  }
}
