import 'package:flutter/material.dart';

import '../data/repositories/finance_repository.dart';
import '../models/models.dart';
import '../services/receipt_attachment_service.dart';

/// Net debt between two parents after accepted (unpaid) expenses.
class ParentNetBalance {
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;

  const ParentNetBalance({
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
  });
}

class FinanceProvider extends ChangeNotifier {
  final FinanceRepository _repository;

  FinanceProvider({required FinanceRepository repository})
      : _repository = repository;

  final List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _error;
  bool _loadedFromApi = false;
  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loadedFromApi => _loadedFromApi;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool canRespondToExpense(Expense expense, String userId) {
    return expense.status == ExpenseStatus.pending && expense.paidBy != userId;
  }

  bool isAwaitingOtherParent(Expense expense, String userId) {
    return expense.status == ExpenseStatus.pending && expense.paidBy == userId;
  }

  Iterable<Expense> get _acceptedForBalance =>
      _expenses.where((e) => e.status == ExpenseStatus.accepted);

  int get acceptedCount =>
      _expenses.where((e) => e.status == ExpenseStatus.accepted).length;

  int get pendingCount =>
      _expenses.where((e) => e.status == ExpenseStatus.pending).length;

  int get disputedCount =>
      _expenses.where((e) => e.status == ExpenseStatus.disputed).length;

  int get settledCount =>
      _expenses.where((e) => e.status == ExpenseStatus.settled).length;

  double get totalPending {
    return _expenses
        .where((e) => e.status == ExpenseStatus.pending)
        .fold(0.0, (sum, e) => sum + e.amountDue);
  }

  /// Pending share awaiting reimbursement for expenses the user paid.
  double pendingRefundForUser(String userId) {
    return _expenses
        .where((e) => e.status == ExpenseStatus.pending && e.paidBy == userId)
        .fold(0.0, (sum, e) => sum + e.amountDue);
  }

  double get totalThisMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};
    for (final e in _expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }

  Map<String, double> categoryTotalsInRange(DateTime from, DateTime to) {
    final Map<String, double> totals = {};
    for (final e in expensesInRange(from, to)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }

  List<Expense> expensesInRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return _expenses
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> filteredExpenses(ExpenseStatus? status) {
    if (status == null) {
      return List<Expense>.from(_expenses);
    }
    return _expenses.where((e) => e.status == status).toList();
  }

  /// Positive = parent B owes parent A.
  double netBalanceParentBOwesParentA({
    required String parentAId,
    required String parentBId,
    DateTime? from,
    DateTime? to,
  }) {
    var balance = 0.0;
    final source = from != null && to != null
        ? expensesInRange(from, to)
            .where((e) => e.status == ExpenseStatus.accepted)
        : _acceptedForBalance;

    for (final expense in source) {
      final due = expense.amountDue;
      if (expense.paidBy == parentAId) {
        balance += due;
      } else if (expense.paidBy == parentBId) {
        balance -= due;
      }
    }
    return balance;
  }

  ParentNetBalance? netBalanceBetweenParents({
    required String parentAId,
    required String parentBId,
    required String parentAName,
    required String parentBName,
    DateTime? from,
    DateTime? to,
  }) {
    final net = netBalanceParentBOwesParentA(
      parentAId: parentAId,
      parentBId: parentBId,
      from: from,
      to: to,
    );
    if (net.abs() < 0.01) {
      return null;
    }
    if (net > 0) {
      return ParentNetBalance(
        debtorId: parentBId,
        debtorName: parentBName,
        creditorId: parentAId,
        creditorName: parentAName,
        amount: net,
      );
    }
    return ParentNetBalance(
      debtorId: parentAId,
      debtorName: parentAName,
      creditorId: parentBId,
      creditorName: parentBName,
      amount: -net,
    );
  }

  String balanceHeadline({
    required String parentAId,
    required String parentBId,
    required String parentAName,
    required String parentBName,
    DateTime? from,
    DateTime? to,
  }) {
    final balance = netBalanceBetweenParents(
      parentAId: parentAId,
      parentBId: parentBId,
      parentAName: parentAName,
      parentBName: parentBName,
      from: from,
      to: to,
    );
    if (balance == null) {
      return 'Saldo wyrównane';
    }
    final debtorFirst = balance.debtorName.split(' ').first;
    final creditorFirst = balance.creditorName.split(' ').first;
    return '$debtorFirst winien $creditorFirst: ${balance.amount.toStringAsFixed(0)} PLN';
  }

  /// Signed amount from the viewer's perspective (positive = others owe the viewer).
  double signedBalanceForUser({
    required String userId,
    required String parentAId,
    required String parentBId,
  }) {
    final net = netBalanceParentBOwesParentA(
      parentAId: parentAId,
      parentBId: parentBId,
    );
    if (userId == parentAId) {
      return net;
    }
    if (userId == parentBId) {
      return -net;
    }
    return 0;
  }

  Future<void> load({bool silent = false}) async {
    final generation = ++_loadGeneration;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final items = await _repository.getExpenses();
      if (generation != _loadGeneration) {
        return;
      }
      _expenses
        ..clear()
        ..addAll(items);
      _loadedFromApi = true;
      _lastSyncedAt = DateTime.now();
      _error = null;
    } catch (error) {
      if (generation != _loadGeneration) {
        return;
      }
      if (!silent) {
        _error = error.toString();
      }
      if (_expenses.isEmpty) {
        _loadedFromApi = false;
      }
    } finally {
      if (generation != _loadGeneration) {
        return;
      }
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void initializeSampleData() {
    _expenses.clear();
    _loadedFromApi = false;
    _error = null;
    final now = DateTime.now();
    _expenses.addAll([
      Expense(
        id: 'exp_001',
        title: 'Wizyta u dentysty – Zosia',
        amount: 280.0,
        category: 'Zdrowie',
        childId: 'child_001',
        paidBy: 'user_demo_parent_a',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 1)),
        status: ExpenseStatus.pending,
        note: 'Plombowanie 2 zębów',
        hash: 'sha256_exp001',
      ),
      Expense(
        id: 'exp_002',
        title: 'Podręczniki szkolne',
        amount: 340.0,
        category: 'Szkoła',
        childId: 'child_001',
        paidBy: 'user_demo_parent_a',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 8)),
        status: ExpenseStatus.accepted,
        hash: 'sha256_exp002',
      ),
      Expense(
        id: 'exp_003',
        title: 'Treningi pływania – Tomek (marzec)',
        amount: 180.0,
        category: 'Zajęcia',
        childId: 'child_002',
        paidBy: 'user_demo_parent_b',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 12)),
        status: ExpenseStatus.settled,
        hash: 'sha256_exp003',
      ),
      Expense(
        id: 'exp_004',
        title: 'Zimowe buty – Zosia',
        amount: 199.0,
        category: 'Ubrania',
        childId: 'child_001',
        paidBy: 'user_demo_parent_a',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 15)),
        status: ExpenseStatus.disputed,
        note: 'Spór: kwota powyżej limitu uzgodnionego',
        hash: 'sha256_exp004',
      ),
      Expense(
        id: 'exp_005',
        title: 'Wycieczka szkolna',
        amount: 120.0,
        category: 'Szkoła',
        childId: 'child_002',
        paidBy: 'user_demo_parent_a',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 20)),
        status: ExpenseStatus.accepted,
        hash: 'sha256_exp005',
      ),
      Expense(
        id: 'exp_006',
        title: 'Leki – Tomek (infekcja)',
        amount: 67.50,
        category: 'Zdrowie',
        childId: 'child_002',
        paidBy: 'user_demo_parent_b',
        splitRatio: 0.5,
        date: now.subtract(const Duration(days: 5)),
        status: ExpenseStatus.pending,
        hash: 'sha256_exp006',
      ),
    ]);
    notifyListeners();
  }

  void clear() {
    _expenses.clear();
    _error = null;
    _isLoading = false;
    _loadedFromApi = false;
    notifyListeners();
  }

  Future<ReceiptParseResult> parseReceipt({
    required String contentBase64,
    required String mimeType,
  }) {
    return _repository.parseReceipt(
      contentBase64: contentBase64,
      mimeType: mimeType,
    );
  }

  Future<Map<String, dynamic>?> getReceipt(String expenseId) async {
    try {
      return await _repository.getReceipt(expenseId);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> addExpense(
    Expense expense, {
    String? receiptContentBase64,
    String? receiptMimeType,
  }) async {
    try {
      final created = await _repository.createExpense(
        expense,
        receiptContentBase64: receiptContentBase64,
        receiptMimeType: receiptMimeType,
      );
      _expenses.insert(0, created);
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpenseStatus(
    String expenseId,
    ExpenseStatus status, {
    String? note,
  }) async {
    try {
      final updated = await _repository.updateExpenseStatus(
        expenseId: expenseId,
        status: status,
        note: note,
      );
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index >= 0) {
        _expenses[index] = updated;
      }
      notifyListeners();
      await load(silent: true);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }
}
