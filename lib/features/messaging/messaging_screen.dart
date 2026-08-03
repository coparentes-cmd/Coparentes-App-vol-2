import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_browser_back.dart';
import '../../utils/message_tag_search.dart';
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

class MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _conversationThreadId;
  String? _conversationCategory;
  bool _conversationAllowsPrivateTags = false;
  bool _returnToPreviousTab = false;

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

  Widget _buildThreadList(
    BuildContext context,
    MessagingProvider messaging,
    AppUser? user,
  ) {
    final isReadOnly = user?.role == UserRole.observer;
    final searchQuery = parseMessageSearchQuery(_searchController.text);
    final threads = messaging.threads
        .where(
          (thread) => threadMatchesAllTabSearch(
            thread: thread,
            query: searchQuery,
            tagsByMessageId: messaging.tagsByMessageId,
          ),
        )
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
        title: const Text(
          'Czat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: () => _loadThreads(context),
          ),
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nowy wątek',
              onPressed: () => _newThread(context),
            ),
        ],
      ),
      body: Column(
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadThreads(context),
              child: messaging.isLoading && messaging.threads.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : threads.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Brak wątków',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
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
                              selected: false,
                              onTap: () => _openThreadById(thread.id),
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
