import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config/messaging_categories.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../utils/messaging_helpers.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../screens/settings/settings_screen.dart';

import 'day_agenda_list.dart';
import 'message_thread_preview.dart';
import 'next_handover_bar.dart';
import 'today_card.dart';

enum _DashboardFeedTab { messages, finance, calendar, family }

class DashboardHome extends StatefulWidget {
  final ValueChanged<DateTime> onOpenCalendarDay;
  final ValueChanged<String> onOpenChatThread;
  final ValueChanged<String> onOpenFinanceExpense;
  final ValueChanged<String> onOpenChatCategory;

  const DashboardHome({
    super.key,
    required this.onOpenCalendarDay,
    required this.onOpenChatThread,
    required this.onOpenFinanceExpense,
    required this.onOpenChatCategory,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  _DashboardFeedTab _feedTab = _DashboardFeedTab.messages;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final highConflict = context.watch<AppProvider>().highConflictMode;
    final messaging = context.watch<MessagingProvider>();
    final finance = context.watch<FinanceProvider>();
    final calendar = context.watch<CalendarProvider>();

    final now = DateTime.now();
    final today = calendarDayFrom(now);
    final todaySlots = calendar.getSlotsForDay(today);
    final todayEvents = calendar.getEventsForDay(today);
    final pendingSwaps = calendar.swapRequests
        .where((s) => s.status == SwapStatus.pending)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final nextHandover = calendar.getNextHandover();

    final recentThreads = [...messaging.threads]
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    final familyThreads = recentThreads.where(isFamilyChannel).toList();
    final parentThreads =
        recentThreads.where((t) => !isFamilyChannel(t)).toList();

    final pendingExpenses = finance.expenses
        .where((e) => e.status == ExpenseStatus.pending)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentExpenses = () {
      if (pendingExpenses.isNotEmpty) {
        return pendingExpenses;
      }
      final all = [...finance.expenses]
        ..sort((a, b) => b.date.compareTo(a.date));
      return all;
    }();

    final upcomingEvents = calendar.events
        .where(
          (e) => !calendarDayFrom(e.startDate).isBefore(today),
        )
        .toList()
      ..sort((a, b) => compareEventTimes(a.startDate, b.startDate));

    final viewerId = user?.id;
    final messagesCount = viewerId == null
        ? 0
        : countUnreadMessagesForViewer(parentThreads, viewerId);
    final financeCount = pendingExpenses.isNotEmpty
        ? pendingExpenses.length
        : recentExpenses.length;
    final calendarCount = calendar.pendingRequestCount;
    final familyCount = viewerId == null
        ? 0
        : countUnreadMessagesForViewer(familyThreads, viewerId);

    final isParentA = user?.role == UserRole.parentA;
    final roleColor = isParentA ? AppTheme.parentAColor : AppTheme.parentBColor;

    final custodyText = todaySlots.isNotEmpty
        ? (todaySlots.first.custodian == UserRole.parentA
              ? 'U Mamy'
              : 'U Taty')
        : 'Brak danych';

    final firstName = user?.name.split(' ').first ?? '';
    final compact = isCompactPhoneLayout(context);
    final headerHeight = highConflict
        ? (compact ? 88.0 : 96.0)
        : (compact ? 72.0 : 80.0);

    return ParentTabScaffold(
      headerColor: AppTheme.brandHeaderBlue,
      headerHeight: headerHeight,
      header: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          compact ? 10 : 12,
          compact ? 16 : 20,
          compact ? 10 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Dzień dobry, $firstName',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 18 : 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 10),
                      Image.asset(
                        'assets/branding/coparentes-logo.png',
                        width: compact ? 28 : 32,
                        height: compact ? 28 : 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.family_restroom,
                          size: compact ? 24 : 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 2 : 3),
                  Text(
                    workspace?.name ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  if (highConflict) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.highConflictColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Tryb HC aktywny',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _openSettings(context),
              child: SizedBox(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: compact ? 16 : 18,
                      backgroundColor: AppTheme.coralColor,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0] : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 14 : 16,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings,
                          size: 12,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TodayCard(
                    date: today,
                    pendingSwaps: pendingSwaps.length,
                    roleColor: roleColor,
                    custodyLabel:
                        todaySlots.isNotEmpty ? custodyText : null,
                    onTap: () => widget.onOpenCalendarDay(today),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NextHandoverBar(
                    handover: nextHandover,
                    accentColor: roleColor,
                    onTap: () => widget.onOpenCalendarDay(
                      nextHandover?.date ?? today,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: DayAgendaList(
                        events: todayEvents,
                        onEmptyTap: () => widget.onOpenCalendarDay(today),
                        onEventTap: (_) => widget.onOpenCalendarDay(today),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _FeedTabBar(
                  selected: _feedTab,
                  messagesCount: messagesCount,
                  financeCount: financeCount,
                  calendarCount: calendarCount,
                  familyCount: familyCount,
                  onSelect: (tab) => setState(() => _feedTab = tab),
                ),
                const SizedBox(height: 8),
                _buildFeedBody(
                  userId: user?.id,
                  parentThreads: parentThreads,
                  familyThreads: familyThreads,
                  expenses: recentExpenses.take(5).toList(),
                  upcomingEvents: upcomingEvents.take(5).toList(),
                  pendingSwaps: pendingSwaps.take(5).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBody({
    required String? userId,
    required List<MessageThread> parentThreads,
    required List<MessageThread> familyThreads,
    required List<Expense> expenses,
    required List<CalendarEvent> upcomingEvents,
    required List<SwapRequest> pendingSwaps,
  }) {
    switch (_feedTab) {
      case _DashboardFeedTab.messages:
        if (parentThreads.isEmpty) {
          return const _FeedEmpty(text: 'Brak wiadomości');
        }
        return Column(
          children: parentThreads
              .take(5)
              .map(
                (t) => MessageThreadPreview(
                  thread: t,
                  viewerUserId: userId,
                  onTap: () => widget.onOpenChatThread(t.id),
                ),
              )
              .toList(),
        );
      case _DashboardFeedTab.finance:
        if (expenses.isEmpty) {
          return const _FeedEmpty(text: 'Brak wydatków');
        }
        return Column(
          children: expenses
              .map(
                (e) => _FinanceFeedTile(
                  expense: e,
                  onTap: () => widget.onOpenFinanceExpense(e.id),
                ),
              )
              .toList(),
        );
      case _DashboardFeedTab.calendar:
        return _CalendarFeed(
          swaps: pendingSwaps,
          events: upcomingEvents,
          onOpenDay: widget.onOpenCalendarDay,
        );
      case _DashboardFeedTab.family:
        if (familyThreads.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _FeedEmpty(
              text: 'Brak wiadomości ${familyCategoryDisplayLabel}',
              actionLabel: 'Otwórz czat',
              onAction: () =>
                  widget.onOpenChatCategory(familyCategoryChannel),
            ),
          );
        }
        return Column(
          children: familyThreads
              .take(5)
              .map(
                (t) => MessageThreadPreview(
                  thread: t,
                  viewerUserId: userId,
                  onTap: () => widget.onOpenChatThread(t.id),
                ),
              )
              .toList(),
        );
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

class _FeedTabBar extends StatelessWidget {
  final _DashboardFeedTab selected;
  final int messagesCount;
  final int financeCount;
  final int calendarCount;
  final int familyCount;
  final ValueChanged<_DashboardFeedTab> onSelect;

  const _FeedTabBar({
    required this.selected,
    required this.messagesCount,
    required this.financeCount,
    required this.calendarCount,
    required this.familyCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(_DashboardFeedTab, String, int)>[
      (_DashboardFeedTab.messages, 'Wiadomości', messagesCount),
      (_DashboardFeedTab.finance, 'Finanse', financeCount),
      (_DashboardFeedTab.calendar, 'Kalendarz', calendarCount),
      (
        _DashboardFeedTab.family,
        familyCategoryDisplayLabel,
        familyCount,
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: items.map((item) {
          final tab = item.$1;
          final label = item.$2;
          final count = item.$3;
          final isSelected = selected == tab;
          final text = count > 0 ? '$label ($count)' : label;
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
                  text,
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

class _FeedEmpty extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FeedEmpty({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinanceFeedTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const _FinanceFeedTile({
    required this.expense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (expense.status) {
      ExpenseStatus.pending => AppTheme.warningColor,
      ExpenseStatus.accepted => AppTheme.successColor,
      ExpenseStatus.disputed => AppTheme.errorColor,
      ExpenseStatus.settled => AppTheme.textSecondary,
    };

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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${expense.date.day}.${expense.date.month}.${expense.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${expense.amount.toStringAsFixed(0)} PLN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarFeed extends StatelessWidget {
  final List<SwapRequest> swaps;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onOpenDay;

  const _CalendarFeed({
    required this.swaps,
    required this.events,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    if (swaps.isEmpty && events.isEmpty) {
      return const _FeedEmpty(text: 'Brak nadchodzących pozycji');
    }

    return Column(
      children: [
        ...swaps.map(
          (swap) => _SimpleFeedTile(
            icon: Icons.swap_horiz,
            color: AppTheme.warningColor,
            title:
                'Zamiana ${swap.originalDate.day}.${swap.originalDate.month}→${swap.proposedDate.day}.${swap.proposedDate.month}',
            subtitle: swap.requesterName,
            onTap: () => onOpenDay(swap.originalDate),
          ),
        ),
        ...events.map(
          (event) => _SimpleFeedTile(
            icon: event.typeIcon,
            color: event.typeColor,
            title: event.title,
            subtitle: formatAgendaTimeColumn(
              start: event.startDate,
              end: event.endDate,
            ),
            trailing:
                '${event.startDate.day}.${event.startDate.month}',
            onTap: () => onOpenDay(event.startDate),
          ),
        ),
      ],
    );
  }
}

class _SimpleFeedTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _SimpleFeedTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
