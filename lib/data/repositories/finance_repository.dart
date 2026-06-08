import '../../models/models.dart';
import '../../services/receipt_attachment_service.dart';
import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../serializers/finance_serializers.dart';

class FinanceRepository {
  final AppApiClient _apiClient;
  final OfflineStore _offlineStore;

  FinanceRepository({
    required AppApiClient apiClient,
    required OfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<Expense>> getExpenses() async {
    await syncPendingActions();

    try {
      final payload = await _apiClient.getJson('/finances/expenses');
      final expenses = (payload['expenses'] as List<dynamic>)
          .map(
            (item) => expenseFromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      await _saveExpenses(expenses);
      return expenses;
    } catch (error) {
      final cached = _getCachedExpenses();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<ReceiptParseResult> parseReceipt({
    required String contentBase64,
    required String mimeType,
  }) async {
    final payload = await _apiClient.postJson('/finances/receipts/parse', {
      'contentBase64': contentBase64,
      'mimeType': mimeType,
    });
    return ReceiptParseResult.fromJson(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<Map<String, dynamic>> getReceipt(String expenseId) async {
    final payload = await _apiClient.getJson('/finances/expenses/$expenseId/receipt');
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Expense> createExpense(
    Expense expense, {
    String? receiptContentBase64,
    String? receiptMimeType,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': expense.title,
        'amount': expense.amount,
        'currency': expense.currency,
        'category': expense.category,
        'childId': expense.childId,
        'paidBy': expense.paidBy,
        'splitRatio': expense.splitRatio,
        'date': expense.date.toIso8601String(),
        'receiptUrl': expense.receiptUrl,
        'status': expenseStatusToApi(expense.status),
        'note': expense.note,
      };
      if (receiptContentBase64 != null) {
        body['receiptContentBase64'] = receiptContentBase64;
        body['receiptMimeType'] = receiptMimeType ?? 'image/jpeg';
      }
      final payload = await _apiClient.postJson('/finances/expenses', body);
      final created = expenseFromJson(payload);
      await _upsertExpense(created);
      return created;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final local = Expense(
        id: 'local_exp_${now.microsecondsSinceEpoch}',
        title: expense.title,
        amount: expense.amount,
        currency: expense.currency,
        category: expense.category,
        childId: expense.childId,
        paidBy: expense.paidBy,
        splitRatio: expense.splitRatio,
        date: expense.date,
        receiptUrl: expense.receiptUrl,
        hasReceipt: expense.hasReceipt || receiptContentBase64 != null,
        status: expense.status,
        note: expense.note,
        hash: 'pending_${now.microsecondsSinceEpoch}',
      );
      await _upsertExpense(local);
      await _offlineStore.appendPendingAction({
        'type': 'finances.createExpense',
        'createdAt': now.toIso8601String(),
        'payload': {
          'clientExpenseId': local.id,
          'title': local.title,
          'amount': local.amount,
          'currency': local.currency,
          'category': local.category,
          'childId': local.childId,
          'paidBy': local.paidBy,
          'splitRatio': local.splitRatio,
          'date': local.date.toIso8601String(),
          'receiptUrl': local.receiptUrl,
          if (receiptContentBase64 != null)
            'receiptContentBase64': receiptContentBase64,
          if (receiptMimeType != null) 'receiptMimeType': receiptMimeType,
          'status': expenseStatusToApi(local.status),
          'note': local.note,
        },
      });
      return local;
    }
  }

  Future<Expense> updateExpenseStatus({
    required String expenseId,
    required ExpenseStatus status,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'status': expenseStatusToApi(status),
      };
      if (note != null) {
        body['note'] = note;
      }
      final payload = await _apiClient.postJson(
        '/finances/expenses/$expenseId/status',
        body,
      );
      final updated = expenseFromJson(payload);
      await _upsertExpense(updated);
      return updated;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final cached = _getCachedExpenses();
      final index = cached.indexWhere((e) => e.id == expenseId);
      if (index < 0) {
        rethrow;
      }

      final existing = cached[index];
      final optimistic = Expense(
        id: existing.id,
        title: existing.title,
        amount: existing.amount,
        currency: existing.currency,
        category: existing.category,
        childId: existing.childId,
        paidBy: existing.paidBy,
        splitRatio: existing.splitRatio,
        date: existing.date,
        receiptUrl: existing.receiptUrl,
        hasReceipt: existing.hasReceipt,
        status: status,
        note: note ?? existing.note,
        hash: existing.hash,
      );
      cached[index] = optimistic;
      await _saveExpenses(cached);

      await _offlineStore.appendPendingAction({
        'type': 'finances.updateExpenseStatus',
        'createdAt': DateTime.now().toIso8601String(),
        'payload': {
          'expenseId': expenseId,
          'status': expenseStatusToApi(status),
          if (note != null) 'note': note,
        },
      });
      return optimistic;
    }
  }

  Future<void> syncPendingActions() async {
    final actions = _offlineStore.getPendingActions();
    if (actions.isEmpty) {
      return;
    }

    final cached = _getCachedExpenses();
    final rewrittenQueue = <Map<String, dynamic>>[];
    final localExpenseIdMap = Map<String, String>.from(
      _offlineStore.getFinanceExpenseIdMap(),
    );
    var networkFailed = false;

    for (final action in actions) {
      final type = action['type'] as String? ?? '';
      if (!type.startsWith('finances.')) {
        rewrittenQueue.add(action);
        continue;
      }

      if (networkFailed) {
        rewrittenQueue.add(action);
        continue;
      }

      try {
        switch (type) {
          case 'finances.createExpense':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _apiClient.postJson('/finances/expenses', {
              'title': payload['title'],
              'amount': payload['amount'],
              'currency': payload['currency'],
              'category': payload['category'],
              'childId': payload['childId'],
              'paidBy': payload['paidBy'],
              'splitRatio': payload['splitRatio'],
              'date': payload['date'],
              'receiptUrl': payload['receiptUrl'],
              'receiptContentBase64': payload['receiptContentBase64'],
              'receiptMimeType': payload['receiptMimeType'],
              'status': payload['status'],
              'note': payload['note'],
            });
            final created = expenseFromJson(response);
            final clientId = payload['clientExpenseId'] as String;
            localExpenseIdMap[clientId] = created.id;
            _replaceExpenseId(cached, clientId, created);
            break;
          case 'finances.updateExpenseStatus':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            var expenseId = payload['expenseId'] as String;
            expenseId = localExpenseIdMap[expenseId] ?? expenseId;
            final statusBody = <String, dynamic>{
              'status': payload['status'],
            };
            if (payload['note'] != null) {
              statusBody['note'] = payload['note'];
            }
            final response = await _apiClient.postJson(
              '/finances/expenses/$expenseId/status',
              statusBody,
            );
            final updated = expenseFromJson(response);
            _replaceExpenseId(cached, expenseId, updated);
            break;
          default:
            rewrittenQueue.add(action);
        }
      } on ApiException catch (error) {
        if (error.statusCode >= 500) {
          rethrow;
        }
      } catch (_) {
        networkFailed = true;
        rewrittenQueue.add(action);
      }
    }

    await _saveExpenses(cached);
    await _offlineStore.saveFinanceExpenseIdMap(localExpenseIdMap);
    await _offlineStore.savePendingActions(rewrittenQueue);
  }

  List<Expense> _getCachedExpenses() {
    return _offlineStore
        .getFinancesExpenses()
        .map(expenseFromJson)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveExpenses(List<Expense> expenses) {
    return _offlineStore.saveFinancesExpenses(
      expenses.map(expenseToJson).toList(),
    );
  }

  Future<void> _upsertExpense(Expense expense) async {
    final cached = _getCachedExpenses();
    final index = cached.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      cached[index] = expense;
    } else {
      cached.insert(0, expense);
    }
    cached.sort((a, b) => b.date.compareTo(a.date));
    await _saveExpenses(cached);
  }

  void _replaceExpenseId(List<Expense> expenses, String oldId, Expense replacement) {
    final index = expenses.indexWhere((e) => e.id == oldId);
    if (index >= 0) {
      expenses[index] = replacement;
    } else {
      expenses.insert(0, replacement);
    }
  }
}
