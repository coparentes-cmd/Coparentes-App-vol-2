import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/offline_sync_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../config/messaging_categories.dart';
import '../../../../utils/messaging_helpers.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../utils/app_browser_back.dart';
import '../../../../widgets/brand_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../screens/messaging/messaging_screen.dart';
import '../../../screens/calendar/calendar_screen.dart';
import '../../../screens/finance/finance_screen.dart';
import '../../../screens/exports/exports_screen.dart';
import '../../../screens/documents/documents_screen.dart';
import '../../../screens/ai_coach/ai_coach_screen.dart';
import '../../../screens/settings/settings_screen.dart';

import 'today_card.dart';
import 'stat_card.dart';
import 'message_thread_preview.dart';
import 'finance_snapshot_card.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class DashboardHome extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;
  final ValueChanged<DateTime> onOpenCalendarDay;
  final ValueChanged<String> onOpenChatThread;
  final ValueChanged<String> onOpenFinanceExpense;

  const DashboardHome({
    required this.onNavigateToTab,
    required this.onOpenCalendarDay,
    required this.onOpenChatThread,
    required this.onOpenFinanceExpense,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final highConflict = context.watch<AppProvider>().highConflictMode;
    final messaging = context.watch<MessagingProvider>();
    final finance = context.watch<FinanceProvider>();
    final calendar = context.watch<CalendarProvider>();

    final now = DateTime.now();
    final todaySlots = calendar.getSlotsForDay(now);
    final todayEvents = calendar.getEventsForDay(now);
    final pendingSwaps = calendar.swapRequests
        .where((s) => s.status == SwapStatus.pending)
        .length;
    final pendingRequests = calendar.pendingRequestCount;
    final nextHandover = calendar.getNextHandover();
    final unreadMessages = user?.id == null
        ? 0
        : countUnreadThreadsForViewer(messaging.threads, user!.id);

    AppUser? parentA;
    AppUser? parentB;
    for (final member in workspace?.members ?? []) {
      if (member.role == UserRole.parentA) parentA = member;
      if (member.role == UserRole.parentB) parentB = member;
    }

    final netBalanceLabel = user != null && parentA != null && parentB != null
        ? _formatNetBalanceLabel(
            finance: finance,
            userId: user.id,
            parentA: parentA,
            parentB: parentB,
          )
        : '${finance.totalPending.toStringAsFixed(0)} PLN';

    final chatActivity = _latestChatActivity(messaging);
    final chatDetail = unreadMessages == 0
        ? 'Czat'
        : 'Czat · $unreadMessages nowe';

    final financeActivity = _latestFinanceActivity(finance);
    final latestExpenseId = _latestFinanceExpenseId(finance);
    final financeDetail = finance.pendingCount == 0
        ? 'Finanse · $netBalanceLabel'
        : 'Finanse · ${finance.pendingCount} oczekuje';

    final calendarActivity = _latestCalendarActivity(calendar);
    final calendarDetail = pendingRequests == 0
        ? 'Kalendarz'
        : 'Kalendarz · $pendingRequests prośby';

    final isParentA = user?.role == UserRole.parentA;
    final roleColor = isParentA ? AppTheme.parentAColor : AppTheme.parentBColor;

    final custodyText = todaySlots.isNotEmpty
        ? (todaySlots.first.custodian == UserRole.parentA
              ? 'U Mamy'
              : 'U Taty')
        : 'Brak danych';

    final firstName = user?.name.split(' ').first ?? '';
    final compact = isCompactPhoneLayout(context);

    return ParentTabScaffold(
      headerColor: AppTheme.brandHeaderBlue,
      headerHeight: compact ? 108 : 130,
      header: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          compact ? 8 : 14,
          compact ? 16 : 20,
          compact ? 8 : 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandLogo(
                    height: compact ? 28 : 34,
                    onDarkBackground: true,
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    'Dzień dobry, $firstName',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 18 : 22,
                      fontWeight: FontWeight.w700,
                    ),
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
                    const SizedBox(height: 6),
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
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: compact ? 18 : 22,
                      backgroundColor: AppTheme.coralColor,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0] : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 16 : 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings,
                          size: 13,
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

                // Today custody status card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TodayCard(
                    date: now,
                    todayEvents: todayEvents,
                    pendingSwaps: pendingSwaps,
                    roleColor: roleColor,
                    custodyLabel: todaySlots.isNotEmpty ? custodyText : null,
                    nextHandover: nextHandover,
                    onTap: () => onOpenCalendarDay(now),
                  ),
                ),

                const SizedBox(height: 16),

                // Ostatnie aktywności z zakładek
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: chatDetail,
                          value: chatActivity,
                          icon: Icons.chat_bubble,
                          color: AppTheme.primaryTeal,
                          onTap: () => onNavigateToTab(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: financeDetail,
                          value: financeActivity,
                          icon: Icons.account_balance_wallet,
                          color: AppTheme.warningColor,
                          onTap: () {
                            if (latestExpenseId != null) {
                              onOpenFinanceExpense(latestExpenseId);
                            } else {
                              onNavigateToTab(3);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: calendarDetail,
                          value: calendarActivity,
                          icon: Icons.calendar_month,
                          color: AppTheme.parentBColor,
                          onTap: () => onNavigateToTab(2),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Recent messages section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Ostatnie wiadomości',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...messaging.threads
                    .take(3)
                    .map(
                      (t) => MessageThreadPreview(
                        thread: t,
                        viewerUserId: user?.id,
                        onTap: () => onOpenChatThread(t.id),
                      ),
                    ),

                const SizedBox(height: 20),

                // Finance snapshot
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Finanse – ten miesiąc',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FinanceSnapshotCard(
                  finance: finance,
                  user: user,
                  parentA: parentA,
                  parentB: parentB,
                ),

                const SizedBox(height: 20),

                // Children section
                if (workspace != null && workspace.children.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Dzieci',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: workspace.children.length,
                      itemBuilder: (ctx, i) {
                        final child = workspace.children[i];
                        return ChildChip(child: child);
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // AI Coach CTA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AiCoachCta(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

String _formatNetBalanceLabel({
  required FinanceProvider finance,
  required String userId,
  required AppUser parentA,
  required AppUser parentB,
}) {
  final signed = finance.signedBalanceForUser(
    userId: userId,
    parentAId: parentA.id,
    parentBId: parentB.id,
  );
  if (signed.abs() < 0.01) {
    return '0 PLN';
  }
  if (signed > 0) {
    return '+${signed.toStringAsFixed(0)} PLN';
  }
  return '-${signed.abs().toStringAsFixed(0)} PLN';
}

String _latestChatActivity(MessagingProvider messaging) {
  if (messaging.threads.isEmpty) {
    return 'Brak wiadomości';
  }

  final threads = [...messaging.threads]
    ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  final thread = threads.first;
  final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;

  if (lastMsg != null) {
    final preview = lastMsg.content.trim();
    if (preview.isEmpty && lastMsg.attachments.isNotEmpty) {
      return '📎 ${thread.subject}';
    }
    if (preview.isNotEmpty) {
      return preview.length > 32 ? '${preview.substring(0, 32)}…' : preview;
    }
  }

  return thread.subject;
}

String _latestFinanceActivity(FinanceProvider finance) {
  final expense = _resolveLatestFinanceExpense(finance);
  if (expense == null) {
    return 'Brak wydatków';
  }
  return '${expense.title} · ${expense.amount.toStringAsFixed(0)} PLN';
}

Expense? _resolveLatestFinanceExpense(FinanceProvider finance) {
  final pending = finance.expenses
      .where((expense) => expense.status == ExpenseStatus.pending)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (pending.isNotEmpty) {
    return pending.first;
  }

  if (finance.expenses.isEmpty) {
    return null;
  }

  final latest = [...finance.expenses]
    ..sort((a, b) => b.date.compareTo(a.date));
  return latest.first;
}

String? _latestFinanceExpenseId(FinanceProvider finance) {
  return _resolveLatestFinanceExpense(finance)?.id;
}

String _latestCalendarActivity(CalendarProvider calendar) {
  final pendingSwaps = calendar.swapRequests
      .where((swap) => swap.status == SwapStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  if (pendingSwaps.isNotEmpty) {
    final swap = pendingSwaps.first;
    return 'Zamiana ${_formatShortDate(swap.originalDate)}→${_formatShortDate(swap.proposedDate)}';
  }

  final now = DateTime.now();
  final upcoming = calendar.events
      .where(
        (event) => !event.startDate.isBefore(
          DateTime(now.year, now.month, now.day),
        ),
      )
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  if (upcoming.isNotEmpty) {
    final event = upcoming.first;
    return '${event.title} · ${_formatShortDate(event.startDate)}';
  }

  return 'Brak nadchodzących';
}

String _formatShortDate(DateTime date) {
  return '${date.day}.${date.month}';
}
