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
import '../../widgets/parent_tab_scaffold.dart';
import 'messaging_navigation.dart';
import 'thread_screen.dart';
import 'widgets/e2e_message_text.dart';
import 'widgets/inline_chat_panel.dart';
import 'widgets/new_thread_sheet.dart';
import 'widgets/thread_tile.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

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
          notifyEnabled:
              appProvider.notifyMessages && !appProvider.highConflictMode,
        );
  }

  /// Handles in-tab back navigation. Returns true when consumed.
  bool handleBack() {
    if (_conversationThreadId != null || _conversationCategory != null) {
      _closeConversation();
      return true;
    }
    if (_isCategoryFilterTab) {
      setState(() => _listTab = _ChatListTab.all);
      return true;
    }
    return false;
  }

  bool get _isCategoryFilterTab =>
      _listTab == _ChatListTab.family || _listTab == _ChatListTab.schedule;

  bool get _hasInternalBackState =>
      _conversationThreadId != null ||
      _conversationCategory != null ||
      _isCategoryFilterTab;

  bool get hasInternalNavigation => _hasInternalBackState;

  Widget _buildConversationBackHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onBack,
  }) {
    return Padding(
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
                tooltip: context.tr('Wróć'),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          title: Text(context.tr(familyCategoryDisplayLabel)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.tr('Odśwież wiadomości'),
              onPressed: () => _loadThreads(context),
            ),
          ],
        ),
        body: InlineCategoryChatPanel(
          key: const ValueKey(familyCategoryChannel),
          category: familyCategoryChannel,
          allowPrivateTags: false,
        ),
      );
    }

    final twoPane = useTwoPaneLayout(context);
    // Category chats (Z dziećmi / Zmiana grafiku) stay full-width — the
    // master–detail split is only for Bez kategorii / Nieprzeczytane thread lists.
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
        body: Column(
          children: [
            _buildConversationBackHeader(
              context: context,
              title: context.tr(
                messagingCategoryLabel(_conversationCategory!),
              ),
              onBack: _closeConversation,
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
    return _buildChatListScaffold(
      context: context,
      messaging: messaging,
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
              child: _buildListBody(context, messaging, user),
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
          _buildConversationBackHeader(
            context: context,
            title: context.tr(
              messagingCategoryLabel(_conversationCategory!),
            ),
            onBack: _closeConversation,
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

    return Center(
      child: Text(context.tr('Wybierz wątek z listy'),
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    if (_isCategoryFilterTab) {
      return _buildMessagingChrome(
        context: context,
        body: _buildCategoryFilterChat(context, messaging, user),
      );
    }
    return _buildChatListScaffold(
      context: context,
      messaging: messaging,
      user: user,
      body: _buildListBody(context, messaging, user),
    );
  }

  /// Minimal chrome when showing a predefined category conversation.
  Widget _buildMessagingChrome({
    required BuildContext context,
    required Widget body,
  }) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: AppContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: top + 4),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// Navy header matching Finanse: title + compact search + add, categories below.
  Widget _buildChatListScaffold({
    required BuildContext context,
    required MessagingProvider messaging,
    required AppUser? user,
    required Widget body,
  }) {
    final isReadOnly = user?.role == UserRole.observer;
    final viewerId = user?.id;
    final unreadCount = viewerId == null
        ? 0
        : countUnreadMessagesForViewer(messaging.threads, viewerId);
    final titleRowHeight = parentTabResolvedHeaderHeight(
      context,
      ParentTabScaffold.toolbarHeight,
    );
    final tabRowHeight = parentTabResolvedTabBarHeight(context);

    return ParentTabScaffold(
      headerHeight: titleRowHeight + tabRowHeight,
      header: Column(
        children: [
          SizedBox(
            height: titleRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    context.tr('Czat'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        alignment: Alignment.centerLeft,
                        child: _buildHeaderSearchField(context),
                      ),
                    ),
                  ),
                  if (!isReadOnly) ...[
                    const SizedBox(width: 8),
                    _buildNewThreadButton(context),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            height: tabRowHeight,
            child: _ChatFilterTabs(
              selected: _listTab,
              unreadCount: unreadCount,
              onDark: true,
              onSelect: _onChatFilterSelected,
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  void _onChatFilterSelected(_ChatListTab tab) {
    if (tab == _ChatListTab.family || tab == _ChatListTab.schedule) {
      markBrowserHistoryForward();
    }
    setState(() {
      _listTab = tab;
      _conversationThreadId = null;
      _conversationCategory = null;
    });
  }

  Widget _buildHeaderSearchField(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: context.tr('Szukaj'),
          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textHint),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 34),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildNewThreadButton(BuildContext context) {
    return Tooltip(
      message: context.tr('Nowy wątek'),
      child: Material(
        color: AppTheme.purpleColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _newThread(context),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChat(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    final isReadOnly = user?.role == UserRole.observer;
    if (_listTab == _ChatListTab.family) {
      return Column(
        children: [
          _buildConversationBackHeader(
            context: context,
            title: context.tr(familyCategoryDisplayLabel),
            onBack: () => handleBack(),
          ),
          const Expanded(
            child: InlineCategoryChatPanel(
              key: ValueKey(familyCategoryChannel),
              category: familyCategoryChannel,
              allowPrivateTags: false,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildConversationBackHeader(
          context: context,
          title: context.tr(scheduleCategoryChannel),
          onBack: () => handleBack(),
        ),
        Expanded(
          child: InlineCategoryChatPanel(
            key: const ValueKey(scheduleCategoryChannel),
            category: scheduleCategoryChannel,
            allowPrivateTags: !isReadOnly,
          ),
        ),
      ],
    );
  }

  Widget _buildListBody(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
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

    if (_listTab == _ChatListTab.unread) {
      return _buildUnreadMessagesList(
        context,
        messaging,
        user,
        messaging.threads,
        searchQuery: searchQuery,
      );
    }

    return _buildThreadsScroll(
      context,
      messaging,
      user,
      allThreads,
      emptyLabel: context.tr('Brak wątków'),
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
          ? Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        context.tr('Brak nieprzeczytanych wiadomości'),
                        style: const TextStyle(color: AppTheme.textSecondary),
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

    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        content: Text(
          context
              .tr('Wątek „{subject}” został utworzony')
              .replaceAll('{subject}', thread.subject),
        ),
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
  final bool onDark;

  const _ChatFilterTabs({
    required this.selected,
    required this.unreadCount,
    required this.onSelect,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(_ChatListTab, String)>[
      (_ChatListTab.all, context.tr(allTabDisplayLabel)),
      (
        _ChatListTab.unread,
        unreadCount > 0
            ? '${context.tr('Nieprzeczytane')} ($unreadCount)'
            : context.tr('Nieprzeczytane'),
      ),
      (_ChatListTab.family, context.tr(familyCategoryDisplayLabel)),
      (_ChatListTab.schedule, context.tr(scheduleCategoryChannel)),
    ];

    // Match Finanse TabBar: white label + white underline on navy.
    final selectedColor = onDark ? Colors.white : AppTheme.brandHeaderBlue;
    final unselectedColor =
        onDark ? Colors.white70 : AppTheme.textSecondary;

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    color: isSelected ? selectedColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(threadListTitle(thread)),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${message.senderName}: ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: message.needsDecryption
                            ? E2eMessageText(
                                message: message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            : Text(
                                message.content.trim().isEmpty
                                    ? (message.attachments.isNotEmpty
                                        ? context.tr('Załącznik')
                                        : '…')
                                    : message.content,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
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
