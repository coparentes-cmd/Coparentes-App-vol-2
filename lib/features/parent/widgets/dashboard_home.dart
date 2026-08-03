import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/messaging_categories.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/layout_utils.dart';
import '../../../../widgets/parent_tab_scaffold.dart';
import '../../../screens/settings/settings_screen.dart';

import 'today_card.dart';
import 'message_thread_preview.dart';
import 'finance_snapshot_card.dart';
import 'child_chip.dart';
import 'ai_coach_cta.dart';

class DashboardHome extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;
  final ValueChanged<DateTime> onOpenCalendarDay;
  final ValueChanged<String> onOpenChatThread;
  final ValueChanged<String> onOpenFinanceExpense;
  final ValueChanged<String> onOpenChatCategory;

  const DashboardHome({
    required this.onNavigateToTab,
    required this.onOpenCalendarDay,
    required this.onOpenChatThread,
    required this.onOpenFinanceExpense,
    required this.onOpenChatCategory,
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
    final nextHandover = calendar.getNextHandover();
    final latestExpenseId = _latestFinanceExpenseId(finance);

    AppUser? parentA;
    AppUser? parentB;
    for (final member in workspace?.members ?? []) {
      if (member.role == UserRole.parentA) parentA = member;
      if (member.role == UserRole.parentB) parentB = member;
    }

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
                  Text(
                    'Dzień dobry, $firstName',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 18 : 20,
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardQuickTab(
                              label: 'Czat',
                              icon: Icons.chat_bubble,
                              color: AppTheme.primaryTeal,
                              onTap: () => onNavigateToTab(1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DashboardQuickTab(
                              label: 'Kalendarz',
                              icon: Icons.calendar_month,
                              color: AppTheme.parentBColor,
                              onTap: () => onNavigateToTab(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardQuickTab(
                              label: 'Finanse',
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
                            child: _DashboardQuickTab(
                              label: 'Rodzina',
                              icon: Icons.family_restroom,
                              color: AppTheme.childColor,
                              onTap: () =>
                                  onOpenChatCategory(familyCategoryChannel),
                            ),
                          ),
                        ],
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

class _DashboardQuickTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardQuickTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
