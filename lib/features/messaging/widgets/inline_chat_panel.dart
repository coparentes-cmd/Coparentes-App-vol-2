import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/messaging_categories.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/offline_sync_provider.dart';
import '../../../services/ai_guidance_service.dart';
import '../../../services/message_attachment_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/message_tag_search.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/swap_message_utils.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/message_compose_bar.dart';
import 'thread_messages_list.dart';

class InlineCategoryChatPanel extends StatefulWidget {
  final String? category;
  final String? threadId;
  final bool showChildQuickReplies;
  final bool allowPrivateTags;
  final MessageSearchQuery? messageSearchQuery;

  const InlineCategoryChatPanel({
    super.key,
    this.category,
    this.threadId,
    this.showChildQuickReplies = false,
    this.allowPrivateTags = false,
    this.messageSearchQuery,
  }) : assert(
          (category != null) ^ (threadId != null),
          'Provide either category or threadId',
        );

  @override
  State<InlineCategoryChatPanel> createState() =>
      InlineCategoryChatPanelState();
}

class InlineCategoryChatPanelState extends State<InlineCategoryChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageTone _analyzedTone = MessageTone.neutral;
  Timer? _livePollTimer;
  String? _threadId;
  bool _initializing = true;
  bool _sending = false;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureThread();
      _startLivePollIfNeeded();
    });
  }

  void _startLivePollIfNeeded() {
    if (_livePollTimer != null || !mounted) {
      return;
    }
    if (context.read<AppProvider>().isDemoMode) {
      return;
    }
    _livePollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollMessages(),
    );
  }

  @override
  void dispose() {
    _livePollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureThread() async {
    final messaging = context.read<MessagingProvider>();
    final appProvider = context.read<AppProvider>();

    if (!appProvider.isDemoMode && messaging.threads.isEmpty) {
      await messaging.loadThreads(
        viewerUserId: appProvider.currentUser?.id,
        notifyEnabled: false,
      );
    }

    MessageThread? thread;
    if (widget.threadId != null) {
      thread = messaging.getThreadById(widget.threadId!);
    } else if (appProvider.isDemoMode) {
      thread = messaging.getCategoryChannel(widget.category!);
    } else {
      thread = await messaging.openCategoryChannel(widget.category!);
    }

    if (!mounted) {
      return;
    }

    if (thread == null) {
      setState(() => _initializing = false);
      return;
    }

    final userId = context.read<AppProvider>().currentUser?.id;
    _threadId = thread.id;
    if (userId != null && !appProvider.isDemoMode) {
      await messaging.markThreadRead(thread.id, viewerUserId: userId);
    }

    final category = widget.category ?? thread.category;
    if (isSwapScheduleThread(category)) {
      unawaited(context.read<CalendarProvider>().load(silent: true));
    }

    setState(() => _initializing = false);
    _scrollToBottom();
    if (!appProvider.isDemoMode) {
      context.read<OfflineSyncProvider>().pollMessagingNow();
    }
  }

  void _pollMessages() {
    if (!mounted) {
      return;
    }
    final appProvider = context.read<AppProvider>();
    if (appProvider.isDemoMode) {
      return;
    }
    final messaging = context.read<MessagingProvider>();
    messaging
        .loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: false,
          silent: true,
        )
        .then((_) {
      if (!mounted || widget.category == null) {
        return;
      }
      final current = messaging.getCategoryChannel(widget.category!);
      if (current != null &&
          current.id != _threadId &&
          !current.id.startsWith('local_')) {
        setState(() => _threadId = current.id);
      }
    });
  }

  Future<String?> _resolveActiveThreadId(MessagingProvider messaging) async {
    if (widget.threadId != null) {
      return widget.threadId;
    }
    if (widget.category == null) {
      return _threadId;
    }

    final isDemo = context.read<AppProvider>().isDemoMode;
    if (isDemo) {
      final thread = messaging.getCategoryChannel(widget.category!);
      if (thread != null) {
        _threadId = thread.id;
        return thread.id;
      }
      return null;
    }

    final thread = await messaging.openCategoryChannel(widget.category!);
    if (thread != null) {
      _threadId = thread.id;
      return thread.id;
    }
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if ((content.isEmpty && _pendingAttachments.isEmpty) || _sending) {
      return;
    }

    final messaging = context.read<MessagingProvider>();
    final appProvider = context.read<AppProvider>();
    final threadId = await _resolveActiveThreadId(messaging);
    if (threadId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się otworzyć rozmowy.')),
        );
      }
      return;
    }

    setState(() => _sending = true);
    final attachments =
        _pendingAttachments.map((item) => item.toApiPayload()).toList();
    final sent = await messaging.sendMessage(
          threadId: threadId,
          channelCategory: widget.category,
          content: content,
          tone: _analyzedTone,
          attachments: attachments,
          localOnly: appProvider.isDemoMode,
          demoSender: appProvider.currentUser,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _sending = false;
      if (sent != null) {
        _threadId = sent.id;
        _controller.clear();
        _analyzedTone = MessageTone.neutral;
        _pendingAttachments.clear();
      }
    });
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            messaging.error ?? 'Nie udało się wysłać wiadomości.',
          ),
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _sendQuickReply(String content) async {
    if (_sending) {
      return;
    }

    final messaging = context.read<MessagingProvider>();
    final appProvider = context.read<AppProvider>();
    final threadId = await _resolveActiveThreadId(messaging);
    if (threadId == null) {
      return;
    }

    setState(() => _sending = true);
    final sent = await messaging.sendMessage(
          threadId: threadId,
          channelCategory: widget.category,
          content: content,
          tone: MessageTone.neutral,
          localOnly: appProvider.isDemoMode,
          demoSender: appProvider.currentUser,
        );
    if (!mounted) {
      return;
    }

    setState(() => _sending = false);
    if (sent != null) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final isChild = user?.role == UserRole.child;
    final aiCoach =
        !isChild && context.watch<AppProvider>().aiCoachEnabled;
    final aiShield = context.watch<AppProvider>().aiShieldEnabled;
    final isReadOnly = user?.role == UserRole.observer;
    final thread = _threadId == null
        ? null
        : context.watch<MessagingProvider>().getThreadById(_threadId!);

    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (thread == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.threadId != null
                ? 'Nie znaleziono wątku.'
                : 'Nie udało się otworzyć rozmowy „${widget.category}”.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final panelCategory = widget.category ?? thread.category;
    final panelSubtitle = widget.threadId != null
        ? thread.subject
        : categoryChannelSubtitle(panelCategory);
    final messaging = context.watch<MessagingProvider>();
    final visibleMessages = widget.messageSearchQuery == null
        ? thread.messages
        : filterMessagesForSearch(
            messages: thread.messages,
            query: widget.messageSearchQuery!,
            tagsByMessageId: messaging.tagsByMessageId,
          );
    final hasSearchFilter =
        widget.messageSearchQuery != null && !widget.messageSearchQuery!.isEmpty;

    return Column(
      children: [
        if (widget.threadId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              panelSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: imessageChatBackground,
            child: thread.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            thread.categoryIcon,
                            size: 48,
                            color: thread.categoryColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            panelCategory == allTabLabel
                                ? 'Brak wiadomości'
                                : widget.threadId != null
                                    ? 'Brak wiadomości w tym wątku'
                                    : 'Brak wiadomości w „$panelCategory”',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Napisz pierwszą wiadomość poniżej',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : visibleMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: AppTheme.textHint.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Brak wyników',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasSearchFilter
                                    ? 'Spróbuj innej frazy lub tagu, np. tag:paragon'
                                    : 'Brak wiadomości do wyświetlenia',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ThreadMessagesList(
                    messages: visibleMessages,
                    threadId: thread.id,
                    threadCategory: panelCategory,
                    viewerUserId: user?.id,
                    aiShieldEnabled: aiShield,
                    allowPrivateTags: widget.allowPrivateTags,
                    scrollController: _scrollController,
                  ),
          ),
        ),
        if (widget.showChildQuickReplies && !isReadOnly) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                '🤝 Chcę zostać dłużej',
                '📞 Zadzwoń do mnie',
                '🏠 Zostań na noc',
                '🎮 Chcę zabrać konsolę',
              ]
                  .map(
                    (label) => ActionChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      onPressed: _sending ? null : () => _sendQuickReply(label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
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
            onChanged: (value) {
              setState(() {});
              if (aiCoach && value.length > 10) {
                _analyzedTone = AiGuidanceService.analyze(value).tone;
              }
            },
          ),
      ],
    );
  }
}
