import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../data/api/app_api_client.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/exports_provider.dart';
import '../../../providers/offline_sync_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/receipt_attachment_service.dart';
import '../../../utils/app_browser_back.dart';
import '../../../utils/calendar_date_utils.dart';
import '../../../utils/layout_utils.dart';
import '../../../utils/tab_history_stack.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/parent_tab_scaffold.dart';
import 'widgets/status_count_chip.dart';
import 'widgets/period_chip.dart';
import 'widgets/summary_card.dart';
import 'widgets/category_bar.dart';
import 'widgets/split_overview_card.dart';
import 'widgets/expense_card.dart';
import 'widgets/dispute_expense_sheet.dart';
import 'widgets/add_expense_sheet.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

enum _ReportPeriod { thisMonth, quarter, year, custom }

enum _FinanceReportType { chronological, statistical, balance }

class FinanceScreen extends StatefulWidget {
  final String? openExpenseId;
  final int openExpenseRequestId;

  const FinanceScreen({
    super.key,
    this.openExpenseId,
    this.openExpenseRequestId = 0,
  });

  @override
  FinanceScreenState createState() => FinanceScreenState();
}

class FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TabHistoryStack _financeTabHistory = TabHistoryStack();
  int _lastFinanceTab = 0;
  bool _suppressFinanceTabHistory = false;
  ExpenseStatus? _expenseFilter;
  bool _expenseThisMonthOnly = false;
  String? _highlightExpenseId;
  final Map<String, GlobalKey> _expenseItemKeys = {};
  _ReportPeriod _reportPeriod = _ReportPeriod.thisMonth;
  _FinanceReportType _reportType = _FinanceReportType.chronological;
  DateTime? _customReportFrom;
  DateTime? _customReportTo;
  /// `null` = wszystkie dzieci w rodzinie.
  String? _reportChildId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onFinanceTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      if (!app.isDemoMode) {
        unawaited(context.read<FinanceProvider>().load(silent: true));
        unawaited(context.read<OfflineSyncProvider>().pollFinanceNow());
        final exports = context.read<ExportsProvider>();
        if (exports.jobs.isEmpty && !exports.isLoading) {
          exports.loadExports();
        }
      }
    });

    if (widget.openExpenseId != null) {
      _scheduleOpenExpense(widget.openExpenseId!);
    }
  }

  @override
  void didUpdateWidget(FinanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openExpenseRequestId != oldWidget.openExpenseRequestId &&
        widget.openExpenseId != null) {
      _scheduleOpenExpense(widget.openExpenseId!);
    }
  }

  /// Opens the Wydatki tab and scrolls to [expenseId] (e.g. from Start dashboard).
  Future<void> openExpense(String expenseId) => _openExpenseById(expenseId);

  void _scheduleOpenExpense(String expenseId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openExpenseById(expenseId));
    });
  }

  Future<void> _openExpenseById(String expenseId) async {
    if (!mounted) return;

    final finance = context.read<FinanceProvider>();
    if (!finance.expenses.any((expense) => expense.id == expenseId)) {
      final app = context.read<AppProvider>();
      if (!app.isDemoMode) {
        await finance.load(silent: true);
      }
    }

    if (!mounted) return;

    setState(() {
      _expenseFilter = null;
      _expenseThisMonthOnly = false;
      _highlightExpenseId = expenseId;
    });

    if (_tabController.index != 1) {
      _tabController.animateTo(1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;
    await _scrollExpenseIntoView(expenseId);
  }

  Future<void> _scrollExpenseIntoView(
    String expenseId, {
    int attempt = 0,
  }) async {
    if (!mounted || attempt > 12) return;

    if (attempt > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }

    final targetContext = _expenseItemKeys[expenseId]?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollExpenseIntoView(expenseId, attempt: attempt + 1));
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onFinanceTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onFinanceTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final index = _tabController.index;
    if (index == _lastFinanceTab) {
      return;
    }
    if (!_suppressFinanceTabHistory) {
      _financeTabHistory.push(_lastFinanceTab);
      markBrowserHistoryForward();
    }
    _lastFinanceTab = index;
    _suppressFinanceTabHistory = false;
  }

  /// Handles in-tab back (filters / Saldo→Wydatki→Raporty). Returns true when consumed.
  bool handleBack() {
    if (_expenseThisMonthOnly || _expenseFilter != null) {
      setState(() {
        _expenseThisMonthOnly = false;
        _expenseFilter = null;
      });
      return true;
    }

    final previous = _financeTabHistory.pop();
    if (previous != null) {
      _suppressFinanceTabHistory = true;
      _lastFinanceTab = previous;
      _tabController.animateTo(previous);
      return true;
    }

    if (_tabController.index != 0) {
      _suppressFinanceTabHistory = true;
      _lastFinanceTab = 0;
      _tabController.animateTo(0);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final isReadOnly = user?.role == UserRole.observer;

    return ParentTabScaffold(
      title: context.tr('Finanse'),
      actions: [
        if (!isReadOnly) ...[
          ParentHeaderActionButton(
            label: context.tr('Nowy wydatek'),
            icon: Icons.add,
            backgroundColor: AppTheme.purpleColor,
            prominent: true,
            onPressed: () => _addExpense(context, ocrMode: false),
          ),
          ParentHeaderActionButton(
            label: context.tr('Z paragonu'),
            icon: Icons.camera_alt,
            backgroundColor: AppTheme.purpleColor,
            prominent: true,
            onPressed: () => _addExpense(
              context,
              ocrMode: true,
              autoLaunchSource: kIsWeb
                  ? ReceiptImageSource.gallery
                  : ReceiptImageSource.camera,
            ),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: context.tr('Eksport PDF'),
          onPressed: () => _exportFinances(context),
        ),
      ],
      tabBar: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: context.tr('Saldo')),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('Wydatki')),
                const SizedBox(width: 4),
                Consumer<FinanceProvider>(
                  builder: (_, fp, __) {
                    final pending = fp.pendingCount;
                    if (pending == 0) return const SizedBox.shrink();
                    return Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pending',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Tab(text: context.tr('Raporty')),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBalanceTab(context, finance),
          _buildExpensesTab(context, finance, isReadOnly),
          _buildReportsTab(context, finance),
        ],
      ),
    );
  }

  (AppUser?, AppUser?) _resolveParents(AppProvider app) {
    AppUser? parentA;
    AppUser? parentB;
    for (final member in app.currentWorkspace?.members ?? []) {
      if (member.role == UserRole.parentA) {
        parentA = member;
      } else if (member.role == UserRole.parentB) {
        parentB = member;
      }
    }
    return (parentA, parentB);
  }

  String _formatSyncTime(DateTime syncedAt) {
    final diff = DateTime.now().difference(syncedAt);
    if (diff.inSeconds < 15) return 'przed chwilą';
    if (diff.inMinutes < 1) return '${diff.inSeconds} s temu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    return formatClockTime(syncedAt);
  }

  String _formatReportDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
  }

  (DateTime, DateTime) _reportDateRange() {
    final now = DateTime.now();
    switch (_reportPeriod) {
      case _ReportPeriod.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case _ReportPeriod.quarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(now.year, quarterStartMonth, 1), now);
      case _ReportPeriod.year:
        return (DateTime(now.year, 1, 1), now);
      case _ReportPeriod.custom:
        final from = _customReportFrom ?? DateTime(now.year, now.month, 1);
        final to = _customReportTo ?? now;
        if (from.isAfter(to)) {
          return (to, from);
        }
        return (from, to);
    }
  }

  Future<void> _selectCustomReportRange() async {
    final now = DateTime.now();
    var from = _customReportFrom ?? DateTime(now.year, now.month, 1);
    var to = _customReportTo ?? now;

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final invalidRange = from.isAfter(to);
            return AlertDialog(
              title: Text(context.tr('Wybierz daty')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Od')),
                    subtitle: Text(_formatReportDate(from)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: from,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(now.year + 1, 12, 31),
                      );
                      if (picked != null) {
                        setDialogState(() => from = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Do')),
                    subtitle: Text(_formatReportDate(to)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: to,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(now.year + 1, 12, 31),
                      );
                      if (picked != null) {
                        setDialogState(() => to = picked);
                      }
                    },
                  ),
                  if (invalidRange)
                    Text(context.tr('Data „Od” nie może być późniejsza niż „Do”.'),
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Anuluj')),
                ),
                ElevatedButton(
                  onPressed: invalidRange
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr('Zastosuj')),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _reportPeriod = _ReportPeriod.custom;
        _customReportFrom = from;
        _customReportTo = to;
      });
    }
  }

  Widget _buildBalanceTab(BuildContext context, FinanceProvider finance) {
    final app = context.watch<AppProvider>();
    final (parentA, parentB) = _resolveParents(app);
    final user = app.currentUser;
    final currencyCode = app.currencyCode;
    final categoryTotals = finance.categoryTotals;

    // Headline from the same paid totals as „Kto zapłacił” (full amounts).
    final String balanceHeadline;
    final double signedBalance;
    if (parentA != null && parentB != null) {
      final totals = finance.paidTotalsForParents(
        parentAId: parentA.id,
        parentBId: parentB.id,
      );
      final net = totals.paidByA - totals.paidByB;
      if (net.abs() < 0.01) {
        balanceHeadline = 'Saldo';
      } else if (net > 0) {
        final debtor = parentB.name.split(' ').first;
        final creditor = parentA.name.split(' ').first;
        balanceHeadline =
            '$debtor winien $creditor: ${net.toStringAsFixed(0)} $currencyCode';
      } else {
        final debtor = parentA.name.split(' ').first;
        final creditor = parentB.name.split(' ').first;
        balanceHeadline =
            '$debtor winien $creditor: ${(-net).toStringAsFixed(0)} $currencyCode';
      }
      if (user == null) {
        signedBalance = 0.0;
      } else if (user.id == parentA.id) {
        signedBalance = net;
      } else if (user.id == parentB.id) {
        signedBalance = -net;
      } else {
        signedBalance = 0.0;
      }
    } else {
      balanceHeadline = context.tr('Saldo niedostępne');
      signedBalance = 0.0;
    }

    final pendingRefund = user != null
        ? finance.pendingRefundForUser(user.id)
        : finance.totalPending;

    final expanded = isExpandedBreakpoint(context);
    final balanceCard = Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LayoutTokens.financeBalanceCardMax,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr(balanceHeadline).replaceAll(
                              ' winien ',
                              ' ${context.tr('winien')} ',
                            ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        signedBalance.abs() < 0.01
                            ? context.tr('Po zaakceptowanych wydatkach oboje jesteście na zero.')
                            : signedBalance > 0
                            ? context.tr('Drugi rodzic winien Tobie po akceptacji wydatków.') : context.tr('Ty winien/winna drugiemu rodzicowi po akceptacji wydatków.'),
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      if (finance.lastSyncedAt != null && !app.isDemoMode) ...[
                        SizedBox(height: 6),
                        Text(
                          'Ostatnia synchronizacja: ${context.tr(_formatSyncTime(finance.lastSyncedAt!))}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );

    final statusRow = Row(
            children: [
              Expanded(
                child: StatusCountChip(
                  label: context.tr('Zaakceptowane'),
                  count: finance.acceptedCount,
                  color: AppTheme.successColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.accepted),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: StatusCountChip(
                  label: context.tr('Oczekujące'),
                  count: finance.pendingCount,
                  color: AppTheme.warningColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.pending),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: StatusCountChip(
                  label: context.tr('Sporne'),
                  count: finance.disputedCount,
                  color: AppTheme.errorColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.disputed),
                ),
              ),
            ],
          );

    final summaryRow = Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: context.tr('Ten miesiąc'),
                  amount: finance.totalThisMonth,
                  color: AppTheme.primaryTeal,
                  icon: Icons.calendar_month,
                  currencyCode: currencyCode,
                  onTap: _openThisMonthExpenses,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: context.tr('Do zwrotu (oczekujące)'),
                  amount: pendingRefund,
                  color: AppTheme.warningColor,
                  icon: Icons.account_balance_wallet,
                  currencyCode: currencyCode,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.pending),
                ),
              ),
            ],
          );

    final categorySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(context.tr('Podział po kategoriach'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (categoryTotals.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: categoryTotals.entries.map((entry) {
                  final max = categoryTotals.values.reduce(
                    (a, b) => a > b ? a : b,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CategoryBar(
                      category: entry.key,
                      amount: entry.value,
                      maxAmount: max,
                      currencyCode: currencyCode,
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text(context.tr('Brak wydatków do podsumowania.'),
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          SizedBox(height: 20),
          Text(context.tr('Kto zapłacił (zaakceptowane)'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SplitOverviewCard(finance: finance),
        ],
    );

    final summaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        balanceCard,
        const SizedBox(height: 16),
        statusRow,
        const SizedBox(height: 16),
        summaryRow,
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: expanded
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summaryColumn),
                const SizedBox(width: 20),
                Expanded(child: categorySection),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summaryColumn,
                const SizedBox(height: 20),
                categorySection,
              ],
            ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    FinanceProvider finance,
    bool isReadOnly,
  ) {
    final filtered = _visibleExpenses(finance);
    final app = context.watch<AppProvider>();
    final user = app.currentUser;
    final members = app.currentWorkspace?.members ?? [];
    final children = app.currentWorkspace?.children ?? [];

    final filters = <({ExpenseStatus? status, String label})>[
      (status: null, label: context.tr('Wszystkie')),
      (status: ExpenseStatus.pending, label: context.tr('Oczekujące')),
      (status: ExpenseStatus.accepted, label: context.tr('Zaakceptowane')),
      (status: ExpenseStatus.disputed, label: context.tr('Sporne')),
      (status: ExpenseStatus.settled, label: context.tr('Rozliczone')),
    ];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Filtruj:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      context.tr('Ten miesiąc'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _expenseThisMonthOnly,
                    onSelected: (selected) {
                      setState(() => _expenseThisMonthOnly = selected);
                    },
                    selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryTeal,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                ...filters.map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        filter.label,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _expenseFilter == filter.status,
                      onSelected: (_) {
                        setState(() => _expenseFilter = filter.status);
                      },
                      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryTeal,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long,
                  title: _expenseFilter == null && !_expenseThisMonthOnly
                      ? context.tr('Brak wydatków') : context.tr('Brak wydatków w tym filtrze'),
                  subtitle: _expenseFilter == null && !_expenseThisMonthOnly
                      ? context.tr('Dodaj pierwszy wydatek ręcznie lub z paragonu') : context.tr('Spróbuj innego filtra statusu'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final expense = filtered[i];
                    final itemKey =
                        _expenseItemKeys.putIfAbsent(expense.id, GlobalKey.new);
                    return KeyedSubtree(
                      key: itemKey,
                      child: ExpenseCard(
                      expense: expense,
                      isReadOnly: isReadOnly,
                      currentUserId: user?.id,
                      finance: finance,
                      members: members,
                      children: children,
                      highlightExpanded: expense.id == _highlightExpenseId,
                      onDispute: () => _showDisputeSheet(context, expense),
                      onAccept: () async {
                        try {
                          await context
                              .read<FinanceProvider>()
                              .updateExpenseStatus(
                            expense.id,
                            ExpenseStatus.accepted,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr('Wydatek zaakceptowany. Saldo zostało zaktualizowane.'),
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr(
                                  _financeStatusErrorMessage(
                                    error,
                                    fallback:
                                        'Nie udało się zaakceptować wydatku.',
                                  ),
                                )),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      },
                      onSettled: () async {
                        try {
                          await context.read<FinanceProvider>().updateExpenseStatus(
                            expense.id,
                            ExpenseStatus.settled,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr('Oznaczono jako rozliczone poza aplikacją.'),
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr(
                                  _financeStatusErrorMessage(
                                    error,
                                    fallback:
                                        'Nie udało się oznaczyć wydatku jako rozliczonego.',
                                  ),
                                )),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab(BuildContext context, FinanceProvider finance) {
    final app = context.watch<AppProvider>();
    final exports = context.watch<ExportsProvider>();
    final (parentA, parentB) = _resolveParents(app);
    final children = app.currentWorkspace?.children ?? const <ChildProfile>[];
    final currencyCode = app.currencyCode;
    final (from, to) = _reportDateRange();
    final rangeExpenses = finance.expensesInRange(
      from,
      to,
      childId: _reportChildId,
    );

    Widget reportContent;
    switch (_reportType) {
      case _FinanceReportType.chronological:
        reportContent = rangeExpenses.isEmpty
            ? Text(context.tr('Brak wydatków w wybranym okresie.'),
                style: TextStyle(color: AppTheme.textSecondary),
              )
            : Column(
                children: rangeExpenses
                    .map(
                      (e) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(e.categoryIcon, color: e.statusColor),
                        title: Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${e.date.day}.${e.date.month}.${e.date.year} · ${e.statusLabel}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${e.amount.toStringAsFixed(0)} $currencyCode',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
              );
        break;
      case _FinanceReportType.statistical:
        final totals = finance.categoryTotalsInRange(
          from,
          to,
          childId: _reportChildId,
        );
        reportContent = totals.isEmpty
            ? Text(context.tr('Brak danych statystycznych w tym okresie.'),
                style: TextStyle(color: AppTheme.textSecondary),
              )
            : Column(
                children: totals.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr(e.key)),
                            Text(
                              '${e.value.toStringAsFixed(0)} $currencyCode',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
        break;
      case _FinanceReportType.balance:
        final headline = parentA != null && parentB != null
            ? finance.balanceHeadline(
                parentAId: parentA.id,
                parentBId: parentB.id,
                parentAName: parentA.name,
                parentBName: parentB.name,
                currencyCode: currencyCode,
                from: from,
                to: to,
                childId: _reportChildId,
              )
            : 'Saldo niedostępne';
        reportContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(headline).replaceAll(
                    ' winien ',
                    ' ${context.tr('winien')} ',
                  ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(context.tr('Saldo liczone tylko z zaakceptowanych wydatków w wybranym okresie.'),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        );
        break;
    }

    final financeExports = exports.jobs
        .where((j) => j.type == ExportType.finances)
        .take(5)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Okres raportu'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              PeriodChip(
                label: context.tr('Ten miesiąc'),
                selected: _reportPeriod == _ReportPeriod.thisMonth,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.thisMonth),
              ),
              PeriodChip(
                label: context.tr('Kwartał'),
                selected: _reportPeriod == _ReportPeriod.quarter,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.quarter),
              ),
              PeriodChip(
                label: context.tr('Rok'),
                selected: _reportPeriod == _ReportPeriod.year,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.year),
              ),
              PeriodChip(
                label: _reportPeriod == _ReportPeriod.custom &&
                        _customReportFrom != null &&
                        _customReportTo != null
                    ? '${context.tr('Wybierz daty')} · ${_formatReportDate(_customReportFrom!)} – ${_formatReportDate(_customReportTo!)}'
                    : context.tr('Wybierz daty'),
                selected: _reportPeriod == _ReportPeriod.custom,
                onSelected: _selectCustomReportRange,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${context.tr('Zakres')}: ${_formatReportDate(from)} – ${_formatReportDate(to)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 20),
          Text(
            context.tr('Typ raportu'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              PeriodChip(
                label: context.tr('Chronologiczny'),
                selected: _reportType == _FinanceReportType.chronological,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.chronological,
                ),
              ),
              PeriodChip(
                label: context.tr('Statystyczny'),
                selected: _reportType == _FinanceReportType.statistical,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.statistical,
                ),
              ),
              PeriodChip(
                label: context.tr('Saldo'),
                selected: _reportType == _FinanceReportType.balance,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.balance,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            SizedBox(height: 20),
            Text(
              context.tr('Dzieci'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PeriodChip(
                  label: context.tr('Wszystkie dzieci'),
                  selected: _reportChildId == null,
                  onSelected: () => setState(() => _reportChildId = null),
                ),
                ...children.map(
                  (child) => PeriodChip(
                    label: child.name.split(' ').first,
                    selected: _reportChildId == child.id,
                    onSelected: () =>
                        setState(() => _reportChildId = child.id),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: reportContent,
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(context.tr('Generuj eksport PDF')),
              onPressed: exports.isLoading
                  ? null
                  : () => _createFinanceExport(context),
            ),
          ),
          if (exports.error != null) ...[
            SizedBox(height: 8),
            Text(
              exports.error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          ],
          if (financeExports.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(context.tr('Ostatnie eksporty finansów'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...financeExports.map(
              (job) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: AppTheme.successColor,
                  ),
                  title: Text(
                    '${job.fromDate.day}.${job.fromDate.month}.${job.fromDate.year}'
                    ' – ${job.toDate.day}.${job.toDate.month}.${job.toDate.year}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    job.status == 'completed' ? 'Gotowy' : 'W kolejce',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: job.status == 'completed'
                      ? IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          onPressed: () async {
                            final saved = await context
                                .read<ExportsProvider>()
                                .saveExportAsPdf(
                                  job,
                                  languageCode: Localizations.localeOf(context)
                                      .languageCode,
                                );
                            if (!context.mounted) {
                              return;
                            }
                            final provider = context.read<ExportsProvider>();
                            ScaffoldMessenger.of(context).showTopSnackBar(
                              SnackBar(
                                content: Text(
                                  saved
                                      ? context.tr('PDF zapisany na urządzeniu.')
                                      : provider.error ??
                                          context.tr('Nie udało się zapisać PDF.'),
                                ),
                                backgroundColor: saved
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createFinanceExport(BuildContext context) async {
    final (from, to) = _reportDateRange();
    final job = await context.read<ExportsProvider>().createExport(
      type: ExportType.finances,
      fromDate: from,
      toDate: to,
    );
    if (!context.mounted) return;
    if (job != null) {
      final saved = job.status == 'completed'
          ? await context.read<ExportsProvider>().saveExportAsPdf(
              job,
              languageCode: Localizations.localeOf(context).languageCode,
            )
          : false;
      if (!context.mounted) return;
      final provider = context.read<ExportsProvider>();
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            saved
                ? context.tr('Raport finansowy zapisany jako PDF.')
                : job.status == 'completed'
                    ? provider.error ?? context.tr('Nie udało się zapisać PDF.')
                    : context.tr('Eksport finansów dodany do kolejki.'),
          ),
          backgroundColor: saved || job.status != 'completed'
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    }
  }

  List<Expense> _visibleExpenses(FinanceProvider finance) {
    var list = finance.filteredExpenses(_expenseFilter);
    if (_expenseThisMonthOnly) {
      final now = DateTime.now();
      list = list
          .where(
            (e) => e.date.year == now.year && e.date.month == now.month,
          )
          .toList();
    }
    return list;
  }

  void _openExpensesFiltered(ExpenseStatus? status) {
    setState(() {
      _expenseFilter = status;
      _expenseThisMonthOnly = false;
      _tabController.index = 1;
    });
  }

  void _openThisMonthExpenses() {
    setState(() {
      _expenseFilter = null;
      _expenseThisMonthOnly = true;
      _tabController.index = 1;
    });
  }

  void _addExpense(
    BuildContext context, {
    required bool ocrMode,
    ReceiptImageSource? autoLaunchSource,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddExpenseSheet(
        initialOcrMode: ocrMode,
        autoLaunchSource: autoLaunchSource,
      ),
    );
  }

  void _showDisputeSheet(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DisputeExpenseSheet(expense: expense),
    );
  }

  Future<void> _exportFinances(BuildContext context) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final job = await context.read<ExportsProvider>().createExport(
      type: ExportType.finances,
      fromDate: from,
      toDate: now,
    );
    if (!context.mounted) return;
    if (job != null) {
      final saved = job.status == 'completed'
          ? await context.read<ExportsProvider>().saveExportAsPdf(
              job,
              languageCode: Localizations.localeOf(context).languageCode,
            )
          : false;
      if (!context.mounted) return;
      final provider = context.read<ExportsProvider>();
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Raport finansowy zapisany jako PDF.'
                : job.status == 'completed'
                    ? provider.error ?? context.tr('Nie udało się zapisać PDF.') : context.tr('Raport finansowy dodany do kolejki eksportów.'),
          ),
          backgroundColor: saved || job.status != 'completed'
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showTopSnackBar(
        SnackBar(
          content: Text(context.tr('Nie udało się wygenerować eksportu.')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

String _financeStatusErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is ApiException &&
      error.statusCode == 403 &&
      error.message == 'forbidden_status_transition') {
    return 'Ta zmiana statusu wydatku nie jest dozwolona.';
  }
  return fallback;
}
