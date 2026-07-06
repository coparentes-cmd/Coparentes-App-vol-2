import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/exports_provider.dart';
import '../../providers/offline_sync_provider.dart';
import '../../services/ai_guidance_service.dart';
import '../../services/message_attachment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_tab_scaffold.dart';
import '../../utils/file_download.dart';
import '../../utils/messaging_helpers.dart';
import '../../utils/app_browser_back.dart';
import '../../utils/message_tag_search.dart';
import '../../utils/swap_message_utils.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/message_compose_bar.dart';
import '../../widgets/message_status_indicator.dart';

class MessagingScreen extends StatefulWidget {
  final String? openThreadId;
  final int openThreadRequestId;
  final String? openCategory;
  final int openCategoryRequestId;
  final VoidCallback? onReturnTab;
  final bool familyOnly;
  final bool isTabActive;

  const MessagingScreen({
    super.key,
    this.openThreadId,
    this.openThreadRequestId = 0,
    this.openCategory,
    this.openCategoryRequestId = 0,
    this.onReturnTab,
    this.familyOnly = false,
    this.isTabActive = true,
  });

  @override
  State<MessagingScreen> createState() => MessagingScreenState();
}

class MessagingScreenState extends State<MessagingScreen> {
  String _selectedCategory = allTabLabel;
  final TextEditingController _searchController = TextEditingController();
  String? _activeThreadId;
  bool _returnToPreviousTab = false;
  bool _activeThreadAllowsPrivateTags = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadThreads(context);
    });

    if (widget.openThreadId != null) {
      _scheduleOpenThread(widget.openThreadId!, returnToPreviousTab: true);
    } else if (widget.openCategory != null) {
      _scheduleOpenCategory(widget.openCategory!, returnToPreviousTab: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessagingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openThreadRequestId != oldWidget.openThreadRequestId &&
        widget.openThreadId != null) {
      _scheduleOpenThread(widget.openThreadId!, returnToPreviousTab: true);
    } else if (widget.openCategoryRequestId !=
            oldWidget.openCategoryRequestId &&
        widget.openCategory != null) {
      _scheduleOpenCategory(widget.openCategory!, returnToPreviousTab: true);
    }
  }

  void _scheduleOpenCategory(
    String category, {
    bool returnToPreviousTab = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      markBrowserHistoryForward();
      setState(() {
        _selectedCategory = category;
        _activeThreadId = null;
        _returnToPreviousTab = returnToPreviousTab;
      });
    });
  }

  void _scheduleOpenThread(
    String threadId, {
    bool returnToPreviousTab = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openThreadById(threadId, returnToPreviousTab: returnToPreviousTab));
    });
  }

  void _showThread(
    String threadId, {
    bool returnToPreviousTab = false,
    bool allowPrivateTags = false,
  }) {
    markBrowserHistoryForward();
    setState(() {
      _activeThreadId = threadId;
      _returnToPreviousTab = returnToPreviousTab;
      _activeThreadAllowsPrivateTags = allowPrivateTags;
    });
  }

  void _closeThread() {
    final shouldReturn = _returnToPreviousTab;
    setState(() {
      _activeThreadId = null;
      _returnToPreviousTab = false;
      _activeThreadAllowsPrivateTags = false;
    });
    if (shouldReturn) {
      widget.onReturnTab?.call();
    }
  }

  Future<void> _openThreadById(
    String threadId, {
    bool returnToPreviousTab = false,
  }) async {
    if (!mounted) {
      return;
    }

    final messaging = context.read<MessagingProvider>();
    var thread = messaging.getThreadById(threadId);

    if (thread == null) {
      final appProvider = context.read<AppProvider>();
      await messaging.loadThreads(
        viewerUserId: appProvider.currentUser?.id,
        notifyEnabled: false,
      );
      if (!mounted) {
        return;
      }
      thread = messaging.getThreadById(threadId);
    }

    if (thread == null || !mounted) {
      return;
    }

    _showThread(
      thread.id,
      returnToPreviousTab: returnToPreviousTab,
      allowPrivateTags: isAllTabThread(thread),
    );
  }

  void _loadThreads(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: appProvider.notifyMessages,
        );
  }

  /// Handles in-tab back navigation. Returns true when consumed.
  bool handleBack() {
    if (_activeThreadId != null) {
      _closeThread();
      return true;
    }
    if (_selectedCategory != allTabLabel) {
      final shouldReturn = _returnToPreviousTab;
      setState(() {
        _selectedCategory = allTabLabel;
        _returnToPreviousTab = false;
      });
      if (shouldReturn) {
        widget.onReturnTab?.call();
      }
      return true;
    }
    return false;
  }

  bool get _hasInternalBackState =>
      _activeThreadId != null || _selectedCategory != allTabLabel;

  bool get hasInternalNavigation => _hasInternalBackState;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    return PopScope(
      canPop: !widget.isTabActive || !_hasInternalBackState,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isTabActive) {
          handleBack();
        }
      },
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_activeThreadId != null) {
      return ThreadScreen(
        threadId: _activeThreadId!,
        allowPrivateTags: _activeThreadAllowsPrivateTags,
        onBack: _closeThread,
      );
    }

    final messaging = context.watch<MessagingProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final childFamilyOnly = widget.familyOnly || user?.role == UserRole.child;

    if (childFamilyOnly) {
      return ParentTabScaffold(
        title: 'Rodzina',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież wiadomości',
            onPressed: () => _loadThreads(context),
          ),
        ],
        body: _InlineCategoryChatPanel(
          key: const ValueKey(familyCategoryChannel),
          category: familyCategoryChannel,
          showChildQuickReplies: user?.role == UserRole.child,
        ),
      );
    }

    final isReadOnly = user?.role == UserRole.observer;
    final searchQuery = parseMessageSearchQuery(_searchController.text);
    final allTabThreads = messaging.allTabThreads
        .where(
          (thread) => threadMatchesAllTabSearch(
            thread: thread,
            query: searchQuery,
            tagsByMessageId: messaging.tagsByMessageId,
          ),
        )
        .toList();
    final showInlineChat = _selectedCategory != allTabLabel;

    return ParentTabScaffold(
      title: showInlineChat ? _selectedCategory : 'Wiadomości',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Odśwież wiadomości',
          onPressed: () => _loadThreads(context),
        ),
        if (!isReadOnly)
          ParentHeaderActionButton(
            label: 'Nowy wątek',
            icon: Icons.edit_note,
            backgroundColor: AppTheme.purpleColor,
            prominent: true,
            onPressed: () => _newThread(context),
          ),
      ],
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: messagingNavChips
                  .map(
                    (cat) => _CategoryChip(
                      category: cat,
                      selected: _selectedCategory == cat,
                      onTap: () {
                        if (cat != _selectedCategory && cat != allTabLabel) {
                          markBrowserHistoryForward();
                        }
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          if (!showInlineChat) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Szukaj lub tag:paragon',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.dividerColor),
                  ),
                ),
              ),
            ),
          ],
          if (showInlineChat)
            Expanded(
              child: _InlineCategoryChatPanel(
                key: ValueKey(_selectedCategory),
                category: _selectedCategory,
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _loadThreads(context),
                child: messaging.isLoading && messaging.threads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : allTabThreads.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.25,
                              ),
                              EmptyState(
                                icon: searchQuery.isEmpty
                                    ? Icons.inbox_outlined
                                    : Icons.search_off,
                                title: searchQuery.isEmpty
                                    ? 'Brak wiadomości'
                                    : 'Brak wyników',
                                subtitle: searchQuery.isEmpty
                                    ? 'Wszystkie rozmowy rodziców pojawią się tutaj.'
                                    : 'Spróbuj innej frazy lub tagu, np. tag:szkoła',
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: allTabThreads.length,
                            itemBuilder: (context, index) {
                              final thread = allTabThreads[index];
                              return _ThreadTile(
                                thread: thread,
                                viewerUserId: user?.id,
                                userTags: collectThreadUserTags(
                                  thread,
                                  messaging.tagsByMessageId,
                                ),
                                onTap: () => _showThread(
                                  thread.id,
                                  allowPrivateTags: true,
                                ),
                              );
                            },
                          ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _newThread(BuildContext context) async {
    final thread = await showModalBottomSheet<MessageThread>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewThreadSheet(),
    );

    if (!context.mounted || thread == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wątek „${thread.subject}” został utworzony'),
        backgroundColor: AppTheme.successColor,
      ),
    );

    _showThread(thread.id);
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.primaryTeal,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? AppTheme.primaryTeal : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppTheme.primaryTeal : AppTheme.dividerColor,
          ),
        ),
      ),
    );
  }
}

class _InlineCategoryChatPanel extends StatefulWidget {
  final String category;
  final bool showChildQuickReplies;

  const _InlineCategoryChatPanel({
    super.key,
    required this.category,
    this.showChildQuickReplies = false,
  });

  @override
  State<_InlineCategoryChatPanel> createState() =>
      _InlineCategoryChatPanelState();
}

class _InlineCategoryChatPanelState extends State<_InlineCategoryChatPanel> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureThread());
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

    if (messaging.threads.isEmpty) {
      await messaging.loadThreads(
        viewerUserId: appProvider.currentUser?.id,
        notifyEnabled: false,
      );
    }

    var thread = messaging.getCategoryChannel(widget.category);
    thread ??= await messaging.openCategoryChannel(widget.category);

    if (!mounted) {
      return;
    }

    if (thread == null) {
      setState(() => _initializing = false);
      return;
    }

    final userId = context.read<AppProvider>().currentUser?.id;
    _threadId = thread.id;
    if (userId != null) {
      await messaging.markThreadRead(thread.id, viewerUserId: userId);
    }

    if (isSwapScheduleThread(widget.category)) {
      unawaited(context.read<CalendarProvider>().load(silent: true));
    }

    setState(() => _initializing = false);
    _scrollToBottom();
    context.read<OfflineSyncProvider>().pollMessagingNow();
  }

  void _pollMessages() {
    if (!mounted) {
      return;
    }
    final appProvider = context.read<AppProvider>();
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: false,
          silent: true,
        );
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
    if ((content.isEmpty && _pendingAttachments.isEmpty) ||
        _threadId == null ||
        _sending) {
      return;
    }

    setState(() => _sending = true);
    final attachments =
        _pendingAttachments.map((item) => item.toApiPayload()).toList();
    final sent = await context.read<MessagingProvider>().sendMessage(
          threadId: _threadId!,
          content: content,
          tone: _analyzedTone,
          attachments: attachments,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _sending = false;
      if (sent != null) {
        _controller.clear();
        _analyzedTone = MessageTone.neutral;
        _pendingAttachments.clear();
      }
    });
    _scrollToBottom();
  }

  Future<void> _sendQuickReply(String content) async {
    if (_threadId == null || _sending) {
      return;
    }

    setState(() => _sending = true);
    final sent = await context.read<MessagingProvider>().sendMessage(
          threadId: _threadId!,
          content: content,
          tone: MessageTone.neutral,
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
    final aiCoach = context.watch<AppProvider>().aiCoachEnabled;
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
            'Nie udało się otworzyć rozmowy „${widget.category}”.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            categoryChannelSubtitle(widget.category),
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
                            'Brak wiadomości w „${widget.category}”',
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
                : _ThreadMessagesList(
                    messages: thread.messages,
                    threadId: thread.id,
                    threadCategory: widget.category,
                    viewerUserId: user?.id,
                    aiShieldEnabled: aiShield,
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

class _CategoryChannelTile extends StatelessWidget {
  final String category;
  final MessageThread? thread;
  final String? viewerUserId;
  final VoidCallback onTap;

  const _CategoryChannelTile({
    required this.category,
    required this.thread,
    required this.viewerUserId,
    required this.onTap,
  });

  bool get _hasUnread {
    if (thread == null || viewerUserId == null) {
      return thread?.hasUnread ?? false;
    }
    return threadHasUnreadForViewer(thread!, viewerUserId!);
  }

  @override
  Widget build(BuildContext context) {
    final previewThread = thread ??
        MessageThread(
          id: 'preview_$category',
          subject: category,
          category: category,
          messages: const [],
          lastActivity: DateTime.now(),
        );
    final lastMsg = thread?.messages.isNotEmpty == true
        ? thread!.messages.last
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: previewThread.categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    previewThread.categoryIcon,
                    color: previewThread.categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (thread != null)
                            Text(
                              _formatTime(thread!.lastActivity),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lastMsg != null
                            ? '${lastMsg.senderName}: ${lastMsg.content}'
                            : categoryChannelSubtitle(category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: lastMsg != null
                              ? AppTheme.textSecondary
                              : AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textHint.withValues(alpha: 0.8),
                ),
                if (_hasUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _ThreadTile extends StatelessWidget {
  final MessageThread thread;
  final String? viewerUserId;
  final Set<String> userTags;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.thread,
    required this.viewerUserId,
    this.userTags = const {},
    required this.onTap,
  });

  bool get _hasUnread {
    if (viewerUserId == null) {
      return thread.hasUnread;
    }
    return threadHasUnreadForViewer(thread, viewerUserId!);
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: thread.categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    thread.categoryIcon,
                    color: thread.categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              threadListTitle(thread),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(thread.lastActivity),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: thread.categoryColor.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              thread.category,
                              style: TextStyle(
                                fontSize: 10,
                                color: thread.categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (lastMsg != null)
                            Expanded(
                              child: Text(
                                '${lastMsg.senderName}: ${lastMsg.content}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (userTags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: userTags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.purpleColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.purpleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (_hasUnread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${thread.messages.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── Thread Screen ─────────────────────────────────────────────────────────────

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
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
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
    final aiCoach = context.watch<AppProvider>().aiCoachEnabled;
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(thread.subject, style: const TextStyle(fontSize: 16)),
              Text(
                thread.category,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _exportThread(context),
              tooltip: 'Eksportuj wątek',
            ),
          ],
        ),
        body: Column(
          children: [
            if (aiShield)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.aiCoachColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield,
                        size: 10,
                        color: AppTheme.aiCoachColor,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'AI Shield',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.aiCoachColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Messages list
            Expanded(
              child: ColoredBox(
                color: imessageChatBackground,
                child: _ThreadMessagesList(
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
              child: _ToneIndicator(tone: _analyzedTone),
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

class _ThreadMessagesList extends StatelessWidget {
  final List<Message> messages;
  final String threadId;
  final String? threadCategory;
  final String? viewerUserId;
  final bool aiShieldEnabled;
  final bool allowPrivateTags;
  final ScrollController? scrollController;

  const _ThreadMessagesList({
    required this.messages,
    required this.threadId,
    this.threadCategory,
    required this.viewerUserId,
    required this.aiShieldEnabled,
    this.allowPrivateTags = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final lastActionableIndex = lastActionableMessageIndex(
      messages: messages,
      threadCategory: threadCategory,
      viewerUserId: viewerUserId,
      swaps: calendar.swapRequests,
      schedule: calendar.custodySchedule,
      exceptions: calendar.custodyExceptions,
    );

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == viewerUserId;
        final group = messageGroupInfo(messages, index);

        return _MessageBubble(
          message: message,
          threadId: threadId,
          threadCategory: threadCategory,
          isMe: isMe,
          aiShieldEnabled: aiShieldEnabled,
          group: group,
          allowPrivateTags: allowPrivateTags,
          keyboardAcceptAutofocus: index == lastActionableIndex,
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final String threadId;
  final String? threadCategory;
  final bool isMe;
  final bool aiShieldEnabled;
  final bool allowPrivateTags;
  final MessageGroupInfo group;
  final bool keyboardAcceptAutofocus;

  const _MessageBubble({
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
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
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
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.purpleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.purpleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (showSwapActions) ...[
            const SizedBox(height: 6),
            _SwapMessageActions(
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
            _ScheduleMessageActions(
              alignEnd: widget.isMe,
              isLoading: _respondingToSchedule,
              autofocus: widget.keyboardAcceptAutofocus,
              onAccept: () => _respondToSchedule(schedule, approve: true),
              onReject: () => _respondToSchedule(schedule, approve: false),
            ),
          ],
          if (showExceptionActions) ...[
            const SizedBox(height: 6),
            _ScheduleMessageActions(
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
      builder: (_) => _MessageTagEditorSheet(
        initialTags: currentTags.toList(),
        suggestions: context.read<MessagingProvider>().allUserTags.toList()
          ..sort(),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    try {
      await context.read<MessagingProvider>().setMessageTags(
            messageId: widget.message.id,
            tags: updated,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać tagów.'),
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

class _ToneIndicator extends StatelessWidget {
  final MessageTone tone;
  const _ToneIndicator({required this.tone});

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

class _NewThreadSheet extends StatefulWidget {
  const _NewThreadSheet();

  @override
  State<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends State<_NewThreadSheet> {
  final _subjectController = TextEditingController();
  String? _selectedChildId;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nowy wątek',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wątek pojawi się w zakładce Wszystkie. Możesz oznaczać wiadomości '
            'prywatnymi tagami tylko dla siebie.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Temat wątku',
              hintText: 'np. Angielski – zmiana terminu',
            ),
          ),
          if (children.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedChildId ?? children.first.id,
              decoration: const InputDecoration(labelText: 'Dotyczy dziecka'),
              items: children
                  .map(
                    (child) => DropdownMenuItem(
                      value: child.id,
                      child: Text(child.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedChildId = value),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createThread,
              child: const Text('Utwórz wątek'),
            ),
          ),
        ],
      ),
    );
  }

  void _createThread() {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      return;
    }
    if (messagingNavChips.contains(subject)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ten temat jest zarezerwowany dla osobnej zakładki czatu.',
          ),
        ),
      );
      return;
    }

    final workspace = context.read<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? const [];
    final childId = children.isEmpty
        ? null
        : (_selectedChildId ?? children.first.id);

    context.read<MessagingProvider>()
        .createThread(
          subject: subject,
          category: 'Ogólne',
          childId: childId,
        )
        .then((thread) {
      if (!mounted || thread == null) {
        return;
      }
      Navigator.pop(context, thread);
    });
  }
}

class _MessageTagEditorSheet extends StatefulWidget {
  final List<String> initialTags;
  final List<String> suggestions;

  const _MessageTagEditorSheet({
    required this.initialTags,
    required this.suggestions,
  });

  @override
  State<_MessageTagEditorSheet> createState() => _MessageTagEditorSheetState();
}

class _MessageTagEditorSheetState extends State<_MessageTagEditorSheet> {
  late final TextEditingController _controller;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = [...widget.initialTags];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) {
      return;
    }
    setState(() => _tags = [..._tags, tag]);
    _controller.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((item) => item != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions
        .where((tag) => !_tags.contains(tag))
        .take(8)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Prywatne tagi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Widoczne tylko dla Ciebie. Użyj ich w wyszukiwarce, np. tag:paragon.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map(
                  (tag) => InputChip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nowy tag',
              hintText: 'np. paragon',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _addTag(_controller.text),
              ),
            ),
            onSubmitted: _addTag,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (tag) => ActionChip(
                      label: Text(tag),
                      onPressed: () => _addTag(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _tags),
            child: const Text('Zapisz tagi'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleMessageActions extends StatelessWidget {
  final bool alignEnd;
  final bool isLoading;
  final bool autofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ScheduleMessageActions({
    required this.alignEnd,
    required this.isLoading,
    this.autofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return EnterAcceptScope(
      onAccept: onAccept,
      enabled: !isLoading,
      autofocus: autofocus,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: isLoading ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Odrzuć'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isLoading ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Akceptuj'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapMessageActions extends StatelessWidget {
  final SwapRequest swap;
  final bool alignEnd;
  final bool isLoading;
  final bool autofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SwapMessageActions({
    required this.swap,
    required this.alignEnd,
    required this.isLoading,
    this.autofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return EnterAcceptScope(
      onAccept: onAccept,
      enabled: !isLoading,
      autofocus: autofocus,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: isLoading ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Odrzuć'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isLoading ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Akceptuj'),
            ),
          ],
        ),
      ),
    );
  }
}
