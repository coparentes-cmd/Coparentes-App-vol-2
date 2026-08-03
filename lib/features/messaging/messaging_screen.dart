import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_browser_back.dart';
import '../../utils/layout_utils.dart';
import '../../utils/message_tag_search.dart';
import '../../utils/messaging_helpers.dart';
import '../../widgets/app_content_shell.dart';
import 'messaging_navigation.dart';
import 'thread_screen.dart';
import 'widgets/inline_chat_panel.dart';
import 'widgets/new_thread_sheet.dart';
import 'widgets/thread_tile.dart';

export 'thread_screen.dart';

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

enum _ChatListTab { all, unread, family, schedule }

class MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _conversationThreadId;
  String? _conversationCategory;
  bool _conversationAllowsPrivateTags = false;
  bool _returnToPreviousTab = false;
  _ChatListTab _listTab = _ChatListTab.all;

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
      _openCategoryConversation(
        category,
        returnToPreviousTab: returnToPreviousTab,
      );
    });
  }

  void _scheduleOpenThread(
    String threadId, {
    bool returnToPreviousTab = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _openThreadById(threadId, returnToPreviousTab: returnToPreviousTab),
      );
    });
  }

  void _openCategoryConversation(
    String category, {
    bool returnToPreviousTab = false,
  }) {
    markBrowserHistoryForward();
    setState(() {
      _conversationCategory = category;
      _conversationThreadId = null;
      _conversationAllowsPrivateTags = category != familyCategoryChannel;
      _returnToPreviousTab = returnToPreviousTab;
    });
  }

  void _openThreadConversation(
    String threadId, {
    bool returnToPreviousTab = false,
    bool allowPrivateTags = true,
  }) {
    markBrowserHistoryForward();
    setState(() {
      _conversationThreadId = threadId;
      _conversationCategory = null;
      _conversationAllowsPrivateTags = allowPrivateTags;
      _returnToPreviousTab = returnToPreviousTab;
    });
  }

  void _closeConversation() {
    final shouldReturn = _returnToPreviousTab;
    setState(() {
      _conversationThreadId = null;
      _conversationCategory = null;
      _conversationAllowsPrivateTags = false;
      _returnToPreviousTab = false;
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

    final category = categoryChannelForThread(thread);
    if (category != null) {
      _openCategoryConversation(
        category,
        returnToPreviousTab: returnToPreviousTab,
      );
      return;
    }

    _openThreadConversation(
      thread.id,
      returnToPreviousTab: returnToPreviousTab,
      allowPrivateTags: true,
    );
  }

  void _loadThreads(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    if (appProvider.isDemoMode) {
      return;
    }
    context.read<MessagingProvider>().loadThreads(
          viewerUserId: appProvider.currentUser?.id,
          notifyEnabled: appProvider.notifyMessages,
        );
  }

  /// Handles in-tab back navigation. Returns true when consumed.
  bool handleBack() {
    if (_hasInternalBackState) {
      _closeConversation();
      return true;
    }
    return false;
  }

  bool get _hasInternalBackState =>
      _conversationThreadId != null || _conversationCategory != null;

  bool get hasInternalNavigation => _hasInternalBackState;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isTabActive || !_hasInternalBackState,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isTabActive) {
          handleBack();
        }
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final messaging = context.watch<MessagingProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final childFamilyOnly = widget.familyOnly || user?.role == UserRole.child;

    if (childFamilyOnly) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0.5,
          title: Text(familyCategoryDisplayLabel),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież wiadomości',
              onPressed: () => _loadThreads(context),
            ),
          ],
        ),
        body: InlineCategoryChatPanel(
          key: const ValueKey(familyCategoryChannel),
          category: familyCategoryChannel,
          showChildQuickReplies: user?.role == UserRole.child,
          allowPrivateTags: false,
        ),
      );
    }

    final twoPane = useTwoPaneLayout(context);
    // Category chats (Z dziećmi / Zmiana grafiku) stay full-width — the
    // master–detail split is only for Wszystkie / Nieprzeczytane thread lists.
    final categoryTabFullWidth = _listTab == _ChatListTab.family ||
        _listTab == _ChatListTab.schedule;
    if (twoPane && !categoryTabFullWidth) {
      return _buildTwoPane(context, messaging, user);
    }

    if (_conversationThreadId != null) {
      return ThreadScreen(
        key: ValueKey(_conversationThreadId),
        threadId: _conversationThreadId!,
        onBack: _closeConversation,
        allowPrivateTags: _conversationAllowsPrivateTags &&
            user?.role != UserRole.observer,
      );
    }

    if (_conversationCategory != null) {
      final isReadOnly = user?.role == UserRole.observer;
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeConversation,
          ),
          title: Text(messagingCategoryLabel(_conversationCategory!)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież wiadomości',
              onPressed: () => _loadThreads(context),
            ),
          ],
        ),
        body: InlineCategoryChatPanel(
          key: ValueKey(_conversationCategory),
          category: _conversationCategory,
          allowPrivateTags:
              _conversationAllowsPrivateTags && !isReadOnly,
        ),
      );
    }

    return _buildThreadList(context, messaging, user);
  }

  Widget _buildTwoPane(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    return _buildMessagingChrome(
      context: context,
      user: user,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 360,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppTheme.dividerColor),
                ),
              ),
              child: _buildListColumn(context, messaging, user),
            ),
          ),
          Expanded(child: _buildDetailPane(context, user)),
        ],
      ),
    );
  }

  Widget _buildDetailPane(BuildContext context, AppUser? user) {
    final isReadOnly = user?.role == UserRole.observer;

    if (_conversationThreadId != null) {
      return ThreadScreen(
        key: ValueKey(_conversationThreadId),
        threadId: _conversationThreadId!,
        onBack: _closeConversation,
        allowPrivateTags: _conversationAllowsPrivateTags && !isReadOnly,
      );
    }

    if (_conversationCategory != null) {
      return Column(
        children: [
          Material(
            color: Colors.white,
            elevation: 0.5,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Zamknij',
                    onPressed: _closeConversation,
                  ),
                  Expanded(
                    child: Text(
                      messagingCategoryLabel(_conversationCategory!),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Odśwież',
                    onPressed: () => _loadThreads(context),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: InlineCategoryChatPanel(
              key: ValueKey(_conversationCategory),
              category: _conversationCategory,
              allowPrivateTags:
                  _conversationAllowsPrivateTags && !isReadOnly,
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text(
        'Wybierz wątek z listy',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    return _buildMessagingChrome(
      context: context,
      user: user,
      body: _buildListColumn(context, messaging, user),
    );
  }

  /// Chat chrome without the navy "Czat" bar — only a circular + for new thread.
  Widget _buildMessagingChrome({
    required BuildContext context,
    required AppUser? user,
    required Widget body,
  }) {
    final isReadOnly = user?.role == UserRole.observer;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: AppContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: top + (isReadOnly ? 8 : 4)),
            if (!isReadOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: 'Nowy wątek',
                    child: Material(
                      color: AppTheme.brandHeaderBlue,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _newThread(context),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildListColumn(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    final isReadOnly = user?.role == UserRole.observer;
    final viewerId = user?.id;
    final searchQuery = parseMessageSearchQuery(_searchController.text);
    final searchedThreads = messaging.threads
        .where(
          (thread) => threadMatchesAllTabSearch(
            thread: thread,
            query: searchQuery,
            tagsByMessageId: messaging.tagsByMessageId,
          ),
        )
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    final allThreads = searchedThreads.where(isAllTabThread).toList();
    final unreadCount = viewerId == null
        ? 0
        : countUnreadMessagesForViewer(messaging.threads, viewerId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Szukaj',
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
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
            ),
          ),
        ),
        _ChatFilterTabs(
          selected: _listTab,
          unreadCount: unreadCount,
          onSelect: (tab) {
            setState(() {
              _listTab = tab;
              // Always show the selected filter list (close open chat).
              _conversationThreadId = null;
              _conversationCategory = null;
            });
          },
        ),
        Expanded(
          child: switch (_listTab) {
            _ChatListTab.family => InlineCategoryChatPanel(
                key: const ValueKey(familyCategoryChannel),
                category: familyCategoryChannel,
                allowPrivateTags: false,
              ),
            _ChatListTab.schedule => InlineCategoryChatPanel(
                key: const ValueKey(scheduleCategoryChannel),
                category: scheduleCategoryChannel,
                allowPrivateTags: !isReadOnly,
              ),
            _ChatListTab.unread => _buildUnreadMessagesList(
                context,
                messaging,
                user,
                messaging.threads,
                searchQuery: searchQuery,
              ),
            _ChatListTab.all => _buildThreadsScroll(
                context,
                messaging,
                user,
                allThreads,
                emptyLabel: 'Brak wątków',
              ),
          },
        ),
      ],
    );
  }

  Widget _buildUnreadMessagesList(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
    List<MessageThread> threads, {
    MessageSearchQuery searchQuery = const MessageSearchQuery(text: '', tags: []),
  }) {
    final viewerId = user?.id;
    final items = <({MessageThread thread, Message message})>[];
    if (viewerId != null) {
      for (final item in collectUnreadMessagesForViewer(threads, viewerId)) {
        if (searchQuery.isEmpty ||
            messageMatchesAllTabSearch(
              message: item.message,
              query: searchQuery,
              tagsByMessageId: messaging.tagsByMessageId,
            ) ||
            threadMatchesAllTabSearch(
              thread: item.thread,
              query: searchQuery,
              tagsByMessageId: messaging.tagsByMessageId,
            )) {
          items.add(item);
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _loadThreads(context),
      child: messaging.isLoading && messaging.threads.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Text(
                        'Brak nieprzeczytanych wiadomości',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _UnreadMessageTile(
                      thread: item.thread,
                      message: item.message,
                      onTap: () => _openThreadById(item.thread.id),
                    );
                  },
                ),
    );
  }

  Widget _buildThreadsScroll(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
    List<MessageThread> threads, {
    required String emptyLabel,
  }) {
    return RefreshIndicator(
      onRefresh: () async => _loadThreads(context),
      child: messaging.isLoading && messaging.threads.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : threads.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        emptyLabel,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return ThreadTile(
                      thread: thread,
                      viewerUserId: user?.id,
                      selected: thread.id == _conversationThreadId,
                      onTap: () => _openThreadById(thread.id),
                    );
                  },
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
      builder: (_) => const NewThreadSheet(),
    );

    if (!context.mounted || thread == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wątek „${thread.subject}” został utworzony'),
        backgroundColor: AppTheme.successColor,
      ),
    );

    _openThreadConversation(thread.id, allowPrivateTags: true);
  }
}

class _ChatFilterTabs extends StatelessWidget {
  final _ChatListTab selected;
  final int unreadCount;
  final ValueChanged<_ChatListTab> onSelect;

  const _ChatFilterTabs({
    required this.selected,
    required this.unreadCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(_ChatListTab, String)>[
      (_ChatListTab.all, 'Wszystkie'),
      (
        _ChatListTab.unread,
        unreadCount > 0 ? 'Nieprzeczytane ($unreadCount)' : 'Nieprzeczytane',
      ),
      (_ChatListTab.family, familyCategoryDisplayLabel),
      (_ChatListTab.schedule, scheduleCategoryChannel),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: items.map((item) {
          final tab = item.$1;
          final label = item.$2;
          final isSelected = selected == tab;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelect(tab),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppTheme.brandHeaderBlue
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.brandHeaderBlue
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UnreadMessageTile extends StatelessWidget {
  final MessageThread thread;
  final Message message;
  final VoidCallback onTap;

  const _UnreadMessageTile({
    required this.thread,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = message.content.trim().isEmpty
        ? (message.attachments.isNotEmpty ? 'Załącznik' : '…')
        : message.content;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: thread.categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                thread.categoryIcon,
                color: thread.categoryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    threadListTitle(thread),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${message.senderName}: $preview',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatUnreadTime(message.sentAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatUnreadTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  return '${diff.inDays}d';
}
