import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/exports_provider.dart';
import '../../providers/offline_sync_provider.dart';
import '../../services/ai_guidance_service.dart';
import '../../services/message_attachment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_tab_scaffold.dart';
import '../../utils/file_download.dart';
import '../../utils/messaging_helpers.dart';
import '../../utils/swap_message_utils.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/message_compose_bar.dart';
import '../../widgets/message_status_indicator.dart';

class MessagingScreen extends StatefulWidget {
  final String? openThreadId;
  const MessagingScreen({super.key, this.openThreadId});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  String _selectedCategory = 'Szkoła';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final messaging = context.read<MessagingProvider>();
      _loadThreads(context);
    });

    if (widget.openThreadId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messaging = context.read<MessagingProvider>();
        final thread = messaging.getThreadById(widget.openThreadId!);
        if (thread == null) {
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThreadScreen(threadId: thread.id),
          ),
        );
      });
    }
  }

  void _loadThreads(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: appProvider.notifyMessages,
        );
  }

  @override
  Widget build(BuildContext context) {
    final messaging = context.watch<MessagingProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final isReadOnly = user?.role == UserRole.observer;
    final customThreads = messaging.threads.where((thread) {
      if (isCategoryChannel(thread)) {
        return false;
      }
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return thread.subject.toLowerCase().contains(query) ||
          thread.messages.any(
            (message) => message.content.toLowerCase().contains(query),
          );
    }).toList();
    final showInlineChat = _selectedCategory != 'Wszystkie';

    return ParentTabScaffold(
      title: showInlineChat ? _selectedCategory : 'Wiadomości',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Odśwież wiadomości',
          onPressed: () => _loadThreads(context),
        ),
        if (!showInlineChat)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
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
              children: [
                'Wszystkie',
                ...messagingCategoryChannels,
              ]
                  .map(
                    (cat) => _CategoryChip(
                      category: cat,
                      selected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                    ),
                  )
                  .toList(),
            ),
          ),
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
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Text(
                              'Rozmowy tematyczne',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ),
                          ...messagingCategoryChannels.map(
                            (category) => _CategoryChannelTile(
                              category: category,
                              thread: messaging.getCategoryChannel(category),
                              viewerUserId: user?.id,
                              onTap: () => setState(
                                () => _selectedCategory = category,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.immutableBadge.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: AppTheme.immutableBadge,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Wiadomości po wysłaniu są niezmienialnie archiwizowane (hash SHA-256)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.immutableBadge,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isReadOnly)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: AiContextualTip(
                                tips: AiTips.messaging,
                                intervalSeconds: 7,
                              ),
                            ),
                          if (customThreads.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Wątki z własnym tematem',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                            ...customThreads.map(
                              (thread) => _ThreadTile(
                                thread: thread,
                                viewerUserId: user?.id,
                              ),
                            ),
                          ] else if (_searchQuery.trim().isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const EmptyState(
                              icon: Icons.search_off,
                              title: 'Brak wyników',
                              subtitle: 'Spróbuj innej frazy wyszukiwania',
                            ),
                          ],
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search threads'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by subject or message content',
          ),
          onChanged: (value) => _searchQuery = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Apply'),
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadScreen(threadId: thread.id),
      ),
    );
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

  const _InlineCategoryChatPanel({super.key, required this.category});

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
        if (!isReadOnly)
          MessageComposeBar(
            controller: _controller,
            pendingAttachments: _pendingAttachments,
            onPickAttachment: _pickAttachment,
            onRemoveAttachment: _removeAttachment,
            onSend: _sendMessage,
            sending: _sending,
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

  const _ThreadTile({
    required this.thread,
    this.viewerUserId,
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ThreadScreen(threadId: thread.id),
              ),
            );
          },
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
                              thread.subject,
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
  const ThreadScreen({super.key, required this.threadId});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  MessageTone _analyzedTone = MessageTone.neutral;
  bool _showAiSuggestion = false;
  String _aiSuggestion = '';
  Timer? _livePollTimer;
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

  void _pollThreadMessages() {
    final appProvider = context.read<AppProvider>();
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: false,
          silent: true,
        );
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

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
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
          // Immutable + shield notice
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: [
                const ImmutableBadge(),
                const SizedBox(width: 8),
                if (aiShield) ...[
                  Container(
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
                ],
              ],
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

          // AI tip shown when input is empty and coach is on
          if (_controller.text.isEmpty && aiCoach && !_showAiSuggestion)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: AiContextualTip(
                tips: AiTips.messaging,
                intervalSeconds: 8,
                dismissible: true,
              ),
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
              onChanged: (value) {
                setState(() {});
                if (aiCoach && value.length > 10) {
                  _analyzeTone(value);
                }
              },
            ),
        ],
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
  final ScrollController? scrollController;

  const _ThreadMessagesList({
    required this.messages,
    required this.threadId,
    this.threadCategory,
    required this.viewerUserId,
    required this.aiShieldEnabled,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
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
  final MessageGroupInfo group;

  const _MessageBubble({
    required this.message,
    required this.threadId,
    this.threadCategory,
    required this.isMe,
    required this.aiShieldEnabled,
    required this.group,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showOriginal = false;
  bool _downloadingAttachment = false;
  bool _respondingToSwap = false;

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
    final swap = isSwapScheduleThread(widget.threadCategory)
        ? findPendingSwapForMessage(
            messageContent: widget.message.content,
            messageSenderId: widget.message.senderId,
            swaps: calendar.swapRequests,
          )
        : null;
    final showSwapActions = swap != null &&
        canRespondToSwapMessage(
          swap: swap,
          viewerUserId: context.read<AppProvider>().currentUser?.id,
        );

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
          if (showSwapActions) ...[
            const SizedBox(height: 6),
            _SwapMessageActions(
              swap: swap,
              alignEnd: widget.isMe,
              isLoading: _respondingToSwap,
              onAccept: () => _respondToSwap(swap, SwapStatus.accepted),
              onReject: () => _respondToSwap(swap, SwapStatus.rejected),
            ),
          ],
        ],
      ),
    );
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
  String _selectedCategory = 'Szkoła';

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'Własny temat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dla konkretnych spraw (np. „Angielski – zmiana terminu”). '
            'Ogólne rozmowy o szkole czy zdrowiu prowadź w kanałach tematycznych.',
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
          const SizedBox(height: 12),
          const Text(
            'Kategoria',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Szkoła', 'Zdrowie', 'Finansowe', 'Zmiana grafiku', 'Inne']
                .map(
                  (cat) => ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryTeal,
                  ),
                )
                .toList(),
          ),
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
    if (subject.isEmpty) return;
    if (messagingCategoryChannels.contains(subject)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ten temat jest już kanałem tematycznym — użyj go na liście powyżej.',
          ),
        ),
      );
      return;
    }

    final workspace = context.read<AppProvider>().currentWorkspace;
    context.read<MessagingProvider>()
        .createThread(
          subject: subject,
          category: _selectedCategory,
          childId: workspace?.children.isNotEmpty == true
              ? workspace!.children.first.id
              : null,
        )
        .then((thread) {
      if (!mounted || thread == null) {
        return;
      }
      Navigator.pop(context, thread);
    });
  }
}

class _SwapMessageActions extends StatelessWidget {
  final SwapRequest swap;
  final bool alignEnd;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SwapMessageActions({
    required this.swap,
    required this.alignEnd,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
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
    );
  }
}
