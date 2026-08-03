import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/offline_sync_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/calendar_date_utils.dart';
import '../../../config/messaging_categories.dart';
import '../../../utils/messaging_helpers.dart';
import '../../../utils/layout_utils.dart';
import '../../../utils/app_browser_back.dart';
import '../../../widgets/brand_widgets.dart';
import '../../../widgets/parent_tab_scaffold.dart';
import '../../screens/messaging/messaging_screen.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/finance/finance_screen.dart';
import '../../screens/exports/exports_screen.dart';
import '../../screens/documents/documents_screen.dart';
import '../../screens/ai_coach/ai_coach_screen.dart';
import '../../screens/settings/settings_screen.dart';
import 'widgets/dashboard_home.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  int _previousTabIndex = 0;
  DateTime _calendarFocusDay = DateTime.now();
  int _calendarFocusRequestId = 0;
  String? _pendingOpenThreadId;
  int _openThreadRequestId = 0;
  String? _pendingOpenCategory;
  int _openCategoryRequestId = 0;
  String? _pendingOpenExpenseId;
  int _openExpenseRequestId = 0;
  final GlobalKey<MessagingScreenState> _messagingKey = GlobalKey();
  final GlobalKey<FinanceScreenState> _financeScreenKey = GlobalKey();

  void _navigateToTab(int index) {
    if (index != _selectedIndex) {
      _previousTabIndex = _selectedIndex;
      if (index != 0) {
        markBrowserHistoryForward();
      }
    }
    setState(() => _selectedIndex = index);
    if (index == 1) {
      context.read<OfflineSyncProvider>().pollMessagingNow();
    }
    if (index == 0 || index == 3) {
      _refreshFinanceNow();
    }
  }

  void _openCalendarOnDay(DateTime day) {
    markBrowserHistoryForward();
    setState(() {
      _calendarFocusDay = DateTime(day.year, day.month, day.day);
      _calendarFocusRequestId += 1;
      _selectedIndex = 2;
    });
  }

  void _openChatThread(String threadId) {
    _previousTabIndex = _selectedIndex;
    markBrowserHistoryForward();
    setState(() {
      _pendingOpenThreadId = threadId;
      _openThreadRequestId += 1;
      _pendingOpenCategory = null;
      _selectedIndex = 1;
    });
    context.read<OfflineSyncProvider>().pollMessagingNow();
  }

  void _openChatCategory(String category) {
    _previousTabIndex = _selectedIndex;
    markBrowserHistoryForward();
    setState(() {
      _pendingOpenCategory = category;
      _openCategoryRequestId += 1;
      _pendingOpenThreadId = null;
      _selectedIndex = 1;
    });
    context.read<OfflineSyncProvider>().pollMessagingNow();
  }

  void _openFinanceExpense(String expenseId) {
    _previousTabIndex = _selectedIndex;
    markBrowserHistoryForward();
    setState(() {
      _pendingOpenExpenseId = expenseId;
      _openExpenseRequestId += 1;
      _selectedIndex = 3;
    });
    _refreshFinanceNow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _financeScreenKey.currentState?.openExpense(expenseId);
      });
    });
  }

  void _returnFromChatThread() {
    setState(() {
      _selectedIndex = _previousTabIndex;
      _pendingOpenThreadId = null;
      _pendingOpenCategory = null;
    });
  }

  bool _handleDashboardBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return true;
    }

    if (_selectedIndex == 1) {
      if (_messagingKey.currentState?.handleBack() ?? false) {
        return true;
      }
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = _previousTabIndex);
      return true;
    }

    return false;
  }

  bool _onBrowserBack() => _handleDashboardBack();

  bool get _canExitApp => _selectedIndex == 0;

  @override
  void initState() {
    super.initState();
    registerBrowserBackHandler(_onBrowserBack);
  }

  @override
  void dispose() {
    unregisterBrowserBackHandler(_onBrowserBack);
    super.dispose();
  }

  void _refreshFinanceNow() {
    final app = context.read<AppProvider>();
    if (app.isDemoMode) {
      return;
    }
    unawaited(context.read<FinanceProvider>().load(silent: true));
    unawaited(context.read<OfflineSyncProvider>().pollFinanceNow());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    final isParentA = user?.role == UserRole.parentA;

    return PopScope(
      canPop: _canExitApp,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDashboardBack();
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardHome(
            onNavigateToTab: _navigateToTab,
            onOpenCalendarDay: _openCalendarOnDay,
            onOpenChatThread: _openChatThread,
            onOpenFinanceExpense: _openFinanceExpense,
            onOpenChatCategory: _openChatCategory,
          ),
          MessagingScreen(
            key: _messagingKey,
            isTabActive: _selectedIndex == 1,
            openThreadId: _pendingOpenThreadId,
            openThreadRequestId: _openThreadRequestId,
            openCategory: _pendingOpenCategory,
            openCategoryRequestId: _openCategoryRequestId,
            onReturnTab: _returnFromChatThread,
          ),
          CalendarScreen(
            focusDay: _calendarFocusDay,
            focusRequestId: _calendarFocusRequestId,
            onScheduleRejected: () =>
                _openChatCategory(scheduleCategoryChannel),
          ),
          FinanceScreen(
            key: _financeScreenKey,
            openExpenseId: _pendingOpenExpenseId,
            openExpenseRequestId: _openExpenseRequestId,
          ),
          const DocumentsScreen(),
          const ExportsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) {
            _navigateToTab(i);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: isParentA
              ? AppTheme.parentAColor
              : AppTheme.parentBColor,
          unselectedItemColor: AppTheme.textHint,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Start',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Consumer2<MessagingProvider, AppProvider>(
                      builder: (_, mp, ap, __) {
                        final userId = ap.currentUser?.id;
                        if (userId == null) {
                          return const SizedBox.shrink();
                        }
                        final unread =
                            countUnreadThreadsForViewer(mp.threads, userId);
                        if (unread == 0) return const SizedBox.shrink();
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              activeIcon: const Icon(Icons.chat_bubble),
              label: 'Czat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Kalendarz',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Finanse',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.folder_open_outlined),
              activeIcon: Icon(Icons.folder_open),
              label: 'Dokumenty',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.folder_special_outlined),
              activeIcon: Icon(Icons.folder_special),
              label: 'Eksporty',
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─── Dashboard Home ────────────────────────────────────────────────────────────


// ─── Subwidgets ────────────────────────────────────────────────────────────────
