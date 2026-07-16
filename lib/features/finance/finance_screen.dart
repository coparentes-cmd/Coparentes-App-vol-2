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
  ExpenseStatus? _expenseFilter;
  String? _highlightExpenseId;
  final Map<String, GlobalKey> _expenseItemKeys = {};
  _ReportPeriod _reportPeriod = _ReportPeriod.thisMonth;
  _FinanceReportType _reportType = _FinanceReportType.chronological;
  DateTime? _customReportFrom;
  DateTime? _customReportTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final user = context.watch<AppProvider>().currentUser;
    final isReadOnly = user?.role == UserRole.observer;

    return ParentTabScaffold(
      title: 'Finanse',
      actions: [
        if (!isReadOnly) ...[
          ParentHeaderActionButton(
            label: 'Nowy wydatek',
            icon: Icons.add,
            backgroundColor: AppTheme.purpleColor,
            prominent: true,
            onPressed: () => _addExpense(context, ocrMode: false),
          ),
          ParentHeaderActionButton(
            label: 'Z paragonu',
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
          tooltip: 'Eksport PDF',
          onPressed: () => _exportFinances(context),
        ),
      ],
      tabBar: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          const Tab(text: 'Saldo'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Wydatki'),
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
          const Tab(text: 'Raporty'),
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
    return '${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')}';
  }

  String _formatReportDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
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
              title: const Text('Wybierz daty'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Od'),
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
                    title: const Text('Do'),
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
                    const Text(
                      'Data „Od” nie może być późniejsza niż „Do”.',
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
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  onPressed: invalidRange
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Zastosuj'),
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

    final balanceHeadline = parentA != null && parentB != null
        ? finance.balanceHeadline(
            parentAId: parentA.id,
            parentBId: parentB.id,
            parentAName: parentA.name,
            parentBName: parentB.name,
          )
        : 'Saldo niedostępne';

    final signedBalance = user != null && parentA != null && parentB != null
        ? finance.signedBalanceForUser(
            userId: user.id,
            parentAId: parentA.id,
            parentBId: parentB.id,
          )
        : 0.0;

    final pendingRefund = user != null
        ? finance.pendingRefundForUser(user.id)
        : finance.totalPending;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main balance card — kompaktowa, zielony brand (jak dawne paski)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    balanceHeadline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signedBalance.abs() < 0.01
                        ? 'Po zaakceptowanych wydatkach oboje jesteście na zero.'
                        : signedBalance > 0
                        ? 'Drugi rodzic winien Tobie po akceptacji wydatków.'
                        : 'Ty winien/winna drugiemu rodzicowi po akceptacji wydatków.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (finance.lastSyncedAt != null && !app.isDemoMode) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ostatnia synchronizacja: ${_formatSyncTime(finance.lastSyncedAt!)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status breakdown
          Row(
            children: [
              Expanded(
                child: StatusCountChip(
                  label: 'Zaakceptowane',
                  count: finance.acceptedCount,
                  color: AppTheme.successColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.accepted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatusCountChip(
                  label: 'Oczekujące',
                  count: finance.pendingCount,
                  color: AppTheme.warningColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.pending),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatusCountChip(
                  label: 'Sporne',
                  count: finance.disputedCount,
                  color: AppTheme.errorColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.disputed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Ten miesiąc',
                  amount: finance.totalThisMonth,
                  color: AppTheme.primaryTeal,
                  icon: Icons.calendar_month,
                  currencyCode: currencyCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Do zwrotu (oczekujące)',
                  amount: pendingRefund,
                  color: AppTheme.warningColor,
                  icon: Icons.account_balance_wallet,
                  currencyCode: currencyCode,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.pending),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Podział po kategoriach',
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
            const Text(
              'Brak wydatków do podsumowania.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),

          const SizedBox(height: 20),
          const Text(
            'Kto zapłacił (wszystkie wydatki)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SplitOverviewCard(finance: finance),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    FinanceProvider finance,
    bool isReadOnly,
  ) {
    final filtered = finance.filteredExpenses(_expenseFilter);
    final app = context.watch<AppProvider>();
    final user = app.currentUser;
    final members = app.currentWorkspace?.members ?? [];
    final children = app.currentWorkspace?.children ?? [];

    const filters = <({ExpenseStatus? status, String label})>[
      (status: null, label: 'Wszystkie'),
      (status: ExpenseStatus.pending, label: 'Oczekujące'),
      (status: ExpenseStatus.accepted, label: 'Zaakceptowane'),
      (status: ExpenseStatus.disputed, label: 'Sporne'),
      (status: ExpenseStatus.settled, label: 'Rozliczone'),
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
                  title: _expenseFilter == null
                      ? 'Brak wydatków'
                      : 'Brak wydatków w tym filtrze',
                  subtitle: _expenseFilter == null
                      ? 'Dodaj pierwszy wydatek ręcznie lub z paragonu'
                      : 'Spróbuj innego filtra statusu',
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Wydatek zaakceptowany. Saldo zostało zaktualizowane.',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nie udało się zaakceptować wydatku.'),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Oznaczono jako rozliczone poza aplikacją.',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (_) {}
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
    final currencyCode = app.currencyCode;
    final (from, to) = _reportDateRange();
    final rangeExpenses = finance.expensesInRange(from, to);

    Widget reportContent;
    switch (_reportType) {
      case _FinanceReportType.chronological:
        reportContent = rangeExpenses.isEmpty
            ? const Text(
                'Brak wydatków w wybranym okresie.',
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
        final totals = finance.categoryTotalsInRange(from, to);
        reportContent = totals.isEmpty
            ? const Text(
                'Brak danych statystycznych w tym okresie.',
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
                            Text(e.key),
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
                from: from,
                to: to,
              )
            : 'Saldo niedostępne';
        reportContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Saldo liczone tylko z zaakceptowanych wydatków w wybranym okresie.',
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
          const Text(
            'Okres raportu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              PeriodChip(
                label: 'Ten miesiąc',
                selected: _reportPeriod == _ReportPeriod.thisMonth,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.thisMonth),
              ),
              PeriodChip(
                label: 'Kwartał',
                selected: _reportPeriod == _ReportPeriod.quarter,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.quarter),
              ),
              PeriodChip(
                label: 'Rok',
                selected: _reportPeriod == _ReportPeriod.year,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.year),
              ),
              PeriodChip(
                label: _reportPeriod == _ReportPeriod.custom &&
                        _customReportFrom != null &&
                        _customReportTo != null
                    ? 'Wybierz daty · ${_formatReportDate(_customReportFrom!)} – ${_formatReportDate(_customReportTo!)}'
                    : 'Wybierz daty',
                selected: _reportPeriod == _ReportPeriod.custom,
                onSelected: _selectCustomReportRange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Zakres: ${_formatReportDate(from)} – ${_formatReportDate(to)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Typ raportu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              PeriodChip(
                label: 'Chronologiczny',
                selected: _reportType == _FinanceReportType.chronological,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.chronological,
                ),
              ),
              PeriodChip(
                label: 'Statystyczny',
                selected: _reportType == _FinanceReportType.statistical,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.statistical,
                ),
              ),
              PeriodChip(
                label: 'Saldo',
                selected: _reportType == _FinanceReportType.balance,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: reportContent,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generuj eksport PDF'),
              onPressed: exports.isLoading
                  ? null
                  : () => _createFinanceExport(context),
            ),
          ),
          if (exports.error != null) ...[
            const SizedBox(height: 8),
            Text(
              exports.error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          ],
          if (financeExports.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Ostatnie eksporty finansów',
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
                                .saveExportAsPdf(job);
                            if (!context.mounted) {
                              return;
                            }
                            final provider = context.read<ExportsProvider>();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  saved
                                      ? 'PDF zapisany na urządzeniu.'
                                      : provider.error ??
                                          'Nie udało się zapisać PDF.',
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
          ? await context.read<ExportsProvider>().saveExportAsPdf(job)
          : false;
      if (!context.mounted) return;
      final provider = context.read<ExportsProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Raport finansowy zapisany jako PDF.'
                : job.status == 'completed'
                    ? provider.error ?? 'Nie udało się zapisać PDF.'
                    : 'Eksport finansów dodany do kolejki.',
          ),
          backgroundColor: saved || job.status != 'completed'
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    }
  }

  void _openExpensesFiltered(ExpenseStatus? status) {
    setState(() {
      _expenseFilter = status;
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
          ? await context.read<ExportsProvider>().saveExportAsPdf(job)
          : false;
      if (!context.mounted) return;
      final provider = context.read<ExportsProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Raport finansowy zapisany jako PDF.'
                : job.status == 'completed'
                    ? provider.error ?? 'Nie udało się zapisać PDF.'
                    : 'Raport finansowy dodany do kolejki eksportów.',
          ),
          backgroundColor: saved || job.status != 'completed'
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się wygenerować eksportu.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
