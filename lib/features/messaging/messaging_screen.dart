import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/message_tags.dart';
import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_browser_back.dart';
import '../../utils/message_tag_search.dart';
import '../../utils/messaging_helpers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/parent_tab_scaffold.dart';
import 'messaging_navigation.dart';
import 'thread_screen.dart';
import 'widgets/category_chip.dart';
import 'widgets/general_inbox_tile.dart';
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
  String _selectedCategory = allTabLabel;
  final TextEditingController _searchController = TextEditingController();
  String? _inlineThreadId;
  String? _allTabActiveThreadId;
  bool _inlineThreadAllowsPrivateTags = false;
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
      markBrowserHistoryForward();
      setState(() {
        _selectedCategory = category;
        _inlineThreadId = null;
        _returnToPreviousTab = returnToPreviousTab;
      });
    });
  }

  void _openInlineThread(
    String threadId, {
    bool returnToPreviousTab = false,
    bool allowPrivateTags = false,
  }) {
    markBrowserHistoryForward();
    setState(() {
      _selectedCategory = allTabLabel;
      _inlineThreadId = threadId;
      _allTabActiveThreadId = threadId;
      _inlineThreadAllowsPrivateTags = allowPrivateTags;
      _returnToPreviousTab = returnToPreviousTab;
    });
  }

  void _selectAllTabThread(String threadId) {
    setState(() {
      _allTabActiveThreadId = threadId;
      _inlineThreadId = null;
      _inlineThreadAllowsPrivateTags = false;
    });
  }

  void _selectGeneralInbox() {
    setState(() {
      _allTabActiveThreadId = null;
      _inlineThreadId = null;
      _inlineThreadAllowsPrivateTags = false;
    });
  }

  void _ensureAllTabActiveThread(List<MessageThread> threads) {
    if (_allTabActiveThreadId == null) {
      return;
    }

    final activeStillVisible =
        threads.any((thread) => thread.id == _allTabActiveThreadId);
    if (!activeStillVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _allTabActiveThreadId = null);
      });
    }
  }

  void _closeInlineThread() {
    final shouldReturn = _returnToPreviousTab;
    setState(() {
      _inlineThreadId = null;
      _inlineThreadAllowsPrivateTags = false;
      _returnToPreviousTab = false;
    });
    if (shouldReturn) {
      widget.onReturnTab?.call();
    }
  }

  void _scheduleOpenThread(
    String threadId, {
    bool returnToPreviousTab = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openThreadById(threadId, returnToPreviousTab: returnToPreviousTab));
    });
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
      _scheduleOpenCategory(
        category,
        returnToPreviousTab: returnToPreviousTab,
      );
      return;
    }

    _openInlineThread(
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
    if (_inlineThreadId != null) {
      _closeInlineThread();
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
      _inlineThreadId != null || _selectedCategory != allTabLabel;

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
        body: InlineCategoryChatPanel(
          key: const ValueKey(familyCategoryChannel),
          category: familyCategoryChannel,
          showChildQuickReplies: user?.role == UserRole.child,
          allowPrivateTags: false,
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
    final customAllTabThreads = messaging.customUserThreads
        .where(
          (thread) => threadMatchesAllTabSearch(
            thread: thread,
            query: searchQuery,
            tagsByMessageId: messaging.tagsByMessageId,
          ),
        )
        .toList();
    final showInlineChat = _selectedCategory != allTabLabel;
    final inlineThread = _inlineThreadId == null
        ? null
        : messaging.getThreadById(_inlineThreadId!);
    final showAllTabInlineThread =
        !showInlineChat && _inlineThreadId != null && inlineThread != null;
    if (!showInlineChat && !showAllTabInlineThread) {
      _ensureAllTabActiveThread(allTabThreads);
    }
    final activeAllTabThreadId = _allTabActiveThreadId;
    final activeAllTabThread = activeAllTabThreadId == null
        ? null
        : messaging.getThreadById(activeAllTabThreadId);

    return ParentTabScaffold(
      title: showInlineChat
          ? _selectedCategory
          : showAllTabInlineThread
              ? threadListTitle(inlineThread!)
              : activeAllTabThread != null
                  ? threadListTitle(activeAllTabThread)
                  : allTabLabel,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Odśwież wiadomości',
          onPressed: () => _loadThreads(context),
        ),
        if (!isReadOnly && !showInlineChat)
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
                    (cat) => CategoryChip(
                      category: cat,
                      selected: _selectedCategory == cat,
                      onTap: () {
                        if (cat == allTabLabel && _inlineThreadId != null) {
                          _closeInlineThread();
                          return;
                        }
                        if (cat != _selectedCategory && cat != allTabLabel) {
                          markBrowserHistoryForward();
                        }
                        setState(() {
                          _selectedCategory = cat;
                          if (cat != allTabLabel) {
                            _inlineThreadId = null;
                            _allTabActiveThreadId = null;
                          } else {
                            _inlineThreadId = null;
                            _allTabActiveThreadId = null;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          if (!showInlineChat && !showAllTabInlineThread) ...[
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
              child: InlineCategoryChatPanel(
                key: ValueKey(_selectedCategory),
                category: _selectedCategory,
                allowPrivateTags: !isReadOnly,
              ),
            )
          else if (showAllTabInlineThread)
            Expanded(
              child: InlineCategoryChatPanel(
                key: ValueKey(_inlineThreadId),
                threadId: _inlineThreadId,
                allowPrivateTags: _inlineThreadAllowsPrivateTags && !isReadOnly,
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: RefreshIndicator(
                      onRefresh: () async => _loadThreads(context),
                      child: messaging.isLoading && messaging.threads.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: customAllTabThreads.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return GeneralInboxTile(
                                    selected: activeAllTabThreadId == null,
                                    onTap: _selectGeneralInbox,
                                  );
                                }

                                final thread = customAllTabThreads[index - 1];
                                final selected =
                                    thread.id == activeAllTabThreadId;
                                return ThreadTile(
                                  thread: thread,
                                  viewerUserId: user?.id,
                                  selected: selected,
                                  userTags: sortedMessageTags(
                                    collectThreadUserTags(
                                      thread,
                                      messaging.tagsByMessageId,
                                    ),
                                  ).toSet(),
                                  onTap: () =>
                                      _selectAllTabThread(thread.id),
                                );
                              },
                            ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: activeAllTabThreadId == null
                        ? InlineCategoryChatPanel(
                            key: const ValueKey('all_tab_general_inbox'),
                            category: allTabLabel,
                            allowPrivateTags: !isReadOnly,
                            messageSearchQuery: searchQuery,
                          )
                        : InlineCategoryChatPanel(
                            key: ValueKey(activeAllTabThreadId),
                            threadId: activeAllTabThreadId,
                            allowPrivateTags: !isReadOnly,
                          ),
                  ),
                ],
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

    _selectAllTabThread(thread.id);
  }
}
