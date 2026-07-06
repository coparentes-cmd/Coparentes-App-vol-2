import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../data/api/app_api_client.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/exports_provider.dart';
import '../../providers/offline_sync_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/receipt_attachment_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/parent_tab_scaffold.dart';

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
      }
      final exports = context.read<ExportsProvider>();
      if (exports.jobs.isEmpty && !exports.isLoading) {
        exports.loadExports();
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
                child: _StatusCountChip(
                  label: 'Zaakceptowane',
                  count: finance.acceptedCount,
                  color: AppTheme.successColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.accepted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCountChip(
                  label: 'Oczekujące',
                  count: finance.pendingCount,
                  color: AppTheme.warningColor,
                  onTap: () => _openExpensesFiltered(ExpenseStatus.pending),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCountChip(
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
                child: _SummaryCard(
                  title: 'Ten miesiąc',
                  amount: finance.totalThisMonth,
                  color: AppTheme.primaryTeal,
                  icon: Icons.calendar_month,
                  currencyCode: currencyCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
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
                    child: _CategoryBar(
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
          _SplitOverviewCard(finance: finance),
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
                      child: _ExpenseCard(
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
              _PeriodChip(
                label: 'Ten miesiąc',
                selected: _reportPeriod == _ReportPeriod.thisMonth,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.thisMonth),
              ),
              _PeriodChip(
                label: 'Kwartał',
                selected: _reportPeriod == _ReportPeriod.quarter,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.quarter),
              ),
              _PeriodChip(
                label: 'Rok',
                selected: _reportPeriod == _ReportPeriod.year,
                onSelected: () =>
                    setState(() => _reportPeriod = _ReportPeriod.year),
              ),
              _PeriodChip(
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
              _PeriodChip(
                label: 'Chronologiczny',
                selected: _reportType == _FinanceReportType.chronological,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.chronological,
                ),
              ),
              _PeriodChip(
                label: 'Statystyczny',
                selected: _reportType == _FinanceReportType.statistical,
                onSelected: () => setState(
                  () => _reportType = _FinanceReportType.statistical,
                ),
              ),
              _PeriodChip(
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
      builder: (_) => _AddExpenseSheet(
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
      builder: (_) => _DisputeExpenseSheet(expense: expense),
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

class _StatusCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _StatusCountChip({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryTeal,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final String currencyCode;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.currencyCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          '${amount.toStringAsFixed(0)} $currencyCode',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final double amount;
  final double maxAmount;
  final String currencyCode;

  const _CategoryBar({
    required this.category,
    required this.amount,
    required this.maxAmount,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount > 0 ? amount / maxAmount : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
            Text(
              '${amount.toStringAsFixed(0)} $currencyCode',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: AppTheme.dividerColor,
          color: AppTheme.primaryTeal,
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}

class _SplitOverviewCard extends StatelessWidget {
  final FinanceProvider finance;

  const _SplitOverviewCard({required this.finance});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final currencyCode = appProvider.currencyCode;
    final members = appProvider.currentWorkspace?.members ?? [];

    AppUser? parentA;
    AppUser? parentB;
    for (final member in members) {
      if (member.role == UserRole.parentA) {
        parentA = member;
      } else if (member.role == UserRole.parentB) {
        parentB = member;
      }
    }

    final totalA = parentA == null
        ? 0.0
        : finance.expenses
            .where((e) => e.paidBy == parentA!.id)
            .fold(0.0, (sum, e) => sum + e.amount);
    final totalB = parentB == null
        ? 0.0
        : finance.expenses
            .where((e) => e.paidBy == parentB!.id)
            .fold(0.0, (sum, e) => sum + e.amount);
    final total = totalA + totalB;
    final ratioA = total > 0 ? totalA / total : 0.5;
    final nameA = parentA?.name.split(' ').first ?? 'Rodzic A';
    final nameB = parentB?.name.split(' ').first ?? 'Rodzic B';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameA,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${totalA.toStringAsFixed(0)} $currencyCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.parentAColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nameB,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${totalB.toStringAsFixed(0)} $currencyCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.parentBColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratioA,
              backgroundColor: AppTheme.parentBColor.withValues(alpha: 0.3),
              color: AppTheme.parentAColor,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatefulWidget {
  final Expense expense;
  final bool isReadOnly;
  final String? currentUserId;
  final FinanceProvider finance;
  final List<AppUser> members;
  final List<ChildProfile> children;
  final bool highlightExpanded;
  final VoidCallback onDispute;
  final Future<void> Function() onAccept;
  final VoidCallback onSettled;

  const _ExpenseCard({
    required this.expense,
    required this.isReadOnly,
    required this.currentUserId,
    required this.finance,
    required this.members,
    required this.children,
    this.highlightExpanded = false,
    required this.onDispute,
    required this.onAccept,
    required this.onSettled,
  });

  @override
  State<_ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<_ExpenseCard> {
  late bool _showDetails;

  @override
  void initState() {
    super.initState();
    _showDetails = widget.highlightExpanded;
  }

  @override
  void didUpdateWidget(_ExpenseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightExpanded && !oldWidget.highlightExpanded) {
      _showDetails = true;
    }
  }

  String _memberName(String userId) {
    for (final m in widget.members) {
      if (m.id == userId) return m.name.split(' ').first;
    }
    return 'Rodzic';
  }

  String? _childName(String? childId) {
    if (childId == null) return null;
    for (final c in widget.children) {
      if (c.id == childId) return c.name.split(' ').first;
    }
    return null;
  }

  String _splitLabel(double ratio) {
    final pct = (ratio * 100).round();
    return '$pct/${100 - pct}';
  }

  Future<void> _showReceipt(BuildContext context, String expenseId) async {
    final data = await context.read<FinanceProvider>().getReceipt(expenseId);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się pobrać paragonu.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final contentBase64 = data['contentBase64'] as String?;
    if (contentBase64 == null || contentBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak zapisanego paragonu.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final bytes = decodeReceiptBase64(contentBase64);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Paragon'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _otherParentName(String payerId) {
    for (final m in widget.members) {
      if (m.id != payerId &&
          (m.role == UserRole.parentA || m.role == UserRole.parentB)) {
        return m.name.split(' ').first;
      }
    }
    return 'drugiego rodzica';
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final currencyCode = context.watch<AppProvider>().currencyCode;
    final payerName = _memberName(expense.paidBy);
    final childName = _childName(expense.childId);
    final otherShare = expense.amountDue;
    final userId = widget.currentUserId;
    final canRespond = !widget.isReadOnly &&
        userId != null &&
        widget.finance.canRespondToExpense(expense, userId);
    final awaitingOther = !widget.isReadOnly &&
        userId != null &&
        widget.finance.isAwaitingOtherParent(expense, userId);
    final otherParentName = _otherParentName(expense.paidBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: expense.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    expense.categoryIcon,
                    color: expense.statusColor,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${expense.date.day}.${expense.date.month}.${expense.date.year}'
                        ' · ${expense.category}'
                        '${childName != null ? ' · $childName' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${expense.amount.toStringAsFixed(0)} $currencyCode',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Udział: ${otherShare.toStringAsFixed(0)} $currencyCode',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatusChip(
                  label: expense.status == ExpenseStatus.settled
                      ? 'Rozliczone'
                      : expense.statusLabel,
                  color: expense.statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Zapłacił: $payerName · ${_splitLabel(expense.splitRatio)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showDetails ? Icons.expand_less : Icons.info_outline,
                    size: 18,
                    color: AppTheme.textHint,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                ),
              ],
            ),
            if (expense.status == ExpenseStatus.settled) ...[
              const SizedBox(height: 6),
              const Text(
                'Uregulowane poza aplikacją',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (expense.note != null) ...[
              const SizedBox(height: 8),
              Text(
                expense.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_showDetails) ...[
              const SizedBox(height: 8),
              Text(
                'Hash integralności: ${expense.hash}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textHint,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (expense.hasReceipt) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReceipt(context, expense.id),
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text(
                    'Zobacz paragon',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (awaitingOther) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 16,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Oczekuje na akceptację od $otherParentName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canRespond) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Spór', style: TextStyle(fontSize: 12)),
                      onPressed: widget.onDispute,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text(
                        'Akceptuj',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => widget.onAccept(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!widget.isReadOnly &&
                expense.status == ExpenseStatus.accepted) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text(
                    'Oznacz jako rozliczone',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: widget.onSettled,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisputeExpenseSheet extends StatefulWidget {
  final Expense expense;

  const _DisputeExpenseSheet({required this.expense});

  @override
  State<_DisputeExpenseSheet> createState() => _DisputeExpenseSheetState();
}

class _DisputeExpenseSheetState extends State<_DisputeExpenseSheet> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _noteController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj powód sporu.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<FinanceProvider>().updateExpenseStatus(
        widget.expense.id,
        ExpenseStatus.disputed,
        note: reason,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wydatek oznaczony jako sporny. Drugi rodzic zobaczy zmianę automatycznie.',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się zgłosić sporu.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zgłoś spór',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.expense.title,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Powód sporu',
              hintText: 'Np. kwota przekracza uzgodniony limit',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Zgłoś spór'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final bool initialOcrMode;
  final ReceiptImageSource? autoLaunchSource;

  const _AddExpenseSheet({
    this.initialOcrMode = false,
    this.autoLaunchSource,
  });

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Szkoła';
  String? _selectedChildId;
  DateTime _selectedDate = DateTime.now();
  double _splitRatio = 0.5;
  late bool _ocrMode;
  PendingReceiptImage? _pendingReceipt;
  bool _isParsingReceipt = false;

  static const _categories = [
    'Szkoła',
    'Zdrowie',
    'Zajęcia',
    'Ubrania',
    'Jedzenie',
    'Transport',
    'Inne',
  ];

  static const _splitPresets = [
    (label: '50/50', ratio: 0.5),
    (label: '70/30', ratio: 0.7),
    (label: '80/20', ratio: 0.8),
    (label: '100/0', ratio: 1.0),
  ];

  @override
  void initState() {
    super.initState();
    _ocrMode = widget.initialOcrMode;
    if (widget.autoLaunchSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickAndParseReceipt(widget.autoLaunchSource!);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return 'Inne';
    if (_categories.contains(category)) return category;
    return 'Inne';
  }

  Future<void> _pickAndParseReceipt(ReceiptImageSource source) async {
    if (_isParsingReceipt) return;

    final app = context.read<AppProvider>();
    if (app.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR paragonu wymaga konta produkcyjnego (nie trybu demo).',
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      final picked = await ReceiptAttachmentPicker.pickReceiptImage(
        source: source,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _isParsingReceipt = true;
        _pendingReceipt = picked;
      });

      final parsed = await context.read<FinanceProvider>().parseReceipt(
        contentBase64: picked.contentBase64,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;

      setState(() {
        _ocrMode = false;
        _isParsingReceipt = false;
        if (parsed.title != null && parsed.title!.trim().isNotEmpty) {
          _titleController.text = parsed.title!.trim();
        }
        if (parsed.amount != null && parsed.amount! > 0) {
          _amountController.text = parsed.amount!.toStringAsFixed(2);
        }
        _selectedCategory = _normalizeCategory(parsed.category);
        if (parsed.date != null) {
          _selectedDate = parsed.date!;
        }
      });

      final confidenceLabel = parsed.confidence == 'medium'
          ? 'Rozpoznano dane z paragonu. Sprawdź przed zapisem.'
          : 'Rozpoznanie niepewne — uzupełnij brakujące pola ręcznie.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confidenceLabel),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isParsingReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_receiptParseErrorMessage(error)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _receiptParseErrorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is ApiException) {
      switch (error.message) {
        case 'receipt_invalid':
          return 'Nieobsługiwany format zdjęcia. Wybierz JPG lub PNG.';
        case 'receipt_unreadable':
          return 'Nie udało się odczytać tekstu z paragonu. Spróbuj jaśniejszego zdjęcia.';
        case 'receipt_too_large':
          return 'Zdjęcie jest za duże (max 512 KB). Zbliż paragon i spróbuj ponownie.';
        default:
          if (error.statusCode >= 500) {
            return 'Serwer OCR chwilowo niedostępny. Spróbuj za chwilę.';
          }
          return 'Nie udało się odczytać paragonu (${error.message}).';
      }
    }
    if (error is TimeoutException) {
      return 'OCR trwa zbyt długo. Spróbuj mniejszego zdjęcia lub poczekaj chwilę.';
    }
    return 'Nie udało się odczytać paragonu. Spróbuj jaśniejszego zdjęcia JPG.';
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? [];

    if (_selectedChildId == null && children.isNotEmpty) {
      _selectedChildId = children.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ocrMode ? 'Wydatek z paragonu' : 'Nowy wydatek',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            if (_ocrMode) ...[
              if (_pendingReceipt != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pendingReceipt!.bytes,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isParsingReceipt)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Odczytuję paragon…',
                        style: TextStyle(
                          color: AppTheme.primaryTeal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _pickAndParseReceipt(ReceiptImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Zrób zdjęcie aparatem'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _pickAndParseReceipt(ReceiptImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Dodaj załącznik'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Po zrobieniu zdjęcia odczytamy kwotę, sklep i datę z paragonu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ] else ...[
              if (_pendingReceipt != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pendingReceipt!.bytes,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paragon: ${_pendingReceipt!.fileName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Opis wydatku',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Kwota (PLN)',
                  suffixText: 'PLN',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data wydatku',
                  ),
                  child: Text(
                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                  ),
                ),
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Dziecko',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: children
                      .map(
                        (child) => ChoiceChip(
                          label: Text(
                            child.name.split(' ').first,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _selectedChildId == child.id,
                          onSelected: (_) =>
                              setState(() => _selectedChildId = child.id),
                          selectedColor:
                              AppTheme.primaryTeal.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryTeal,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Kategoria',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _categories
                    .map(
                      (cat) => ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryTeal,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Podział kosztów (udział drugiego rodzica)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _splitPresets
                    .map(
                      (preset) => ChoiceChip(
                        label: Text(
                          preset.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _splitRatio == preset.ratio,
                        onSelected: (_) =>
                            setState(() => _splitRatio = preset.ratio),
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryTeal,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notatka (opcjonalnie)',
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (!_ocrMode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text('Zapisz wydatek'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (title.isEmpty || amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Uzupełnij poprawnie opis i kwotę wydatku.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final app = context.read<AppProvider>();
    final user = app.currentUser;
    final note = _noteController.text.trim();

    try {
      await context.read<FinanceProvider>().addExpense(
        Expense(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          amount: amount,
          category: _selectedCategory,
          childId: _selectedChildId,
          paidBy: user?.id ?? 'unknown',
          splitRatio: _splitRatio,
          date: _selectedDate,
          status: ExpenseStatus.pending,
          note: note.isEmpty ? null : note,
          hash: 'sha256_exp_${DateTime.now().millisecondsSinceEpoch}',
        ),
        receiptContentBase64: _pendingReceipt?.contentBase64,
        receiptMimeType: _pendingReceipt?.mimeType,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać wydatku.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _pendingReceipt != null
              ? 'Wydatek z paragonem zapisany. Oczekuje na akceptację drugiego rodzica.'
              : 'Wydatek zapisany. Oczekuje na akceptację drugiego rodzica.',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
