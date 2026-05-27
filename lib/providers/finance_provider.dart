import 'package:flutter/material.dart';

import '../data/repositories/finance_repository.dart';
import '../models/models.dart';

class FinanceProvider extends ChangeNotifier {
  final FinanceRepository _repository;

  FinanceProvider({required FinanceRepository repository})
      : _repository = repository;

  final List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _error;
  bool _loadedFromApi = false;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loadedFromApi => _loadedFromApi;

  double get totalPending {
    return _expenses
        .where((e) => e.status == ExpenseStatus.pending)
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

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _repository.getExpenses();
      _expenses
        ..clear()
        ..addAll(items);
      _loadedFromApi = true;
    } catch (error) {
      _error = error.toString();
      _loadedFromApi = false;
    } finally {
      _isLoading = false;
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

  Future<void> addExpense(Expense expense) async {
    try {
      final created = await _repository.createExpense(expense);
      _expenses.insert(0, created);
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpenseStatus(String expenseId, ExpenseStatus status) async {
    try {
      final updated = await _repository.updateExpenseStatus(
        expenseId: expenseId,
        status: status,
      );
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index >= 0) {
        _expenses[index] = updated;
      }
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }
}
