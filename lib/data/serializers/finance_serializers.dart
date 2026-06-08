import '../../models/models.dart';

ExpenseStatus expenseStatusFromApi(String value) {
  switch (value) {
    case 'pending':
      return ExpenseStatus.pending;
    case 'accepted':
      return ExpenseStatus.accepted;
    case 'disputed':
      return ExpenseStatus.disputed;
    case 'settled':
      return ExpenseStatus.settled;
    default:
      return ExpenseStatus.pending;
  }
}

/// Backend (Zod) wymaga ISO 8601 ze strefą czasową — np. końcówka `Z`.
String expenseDateToApi(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day).toIso8601String();
}

String expenseStatusToApi(ExpenseStatus status) {
  switch (status) {
    case ExpenseStatus.pending:
      return 'pending';
    case ExpenseStatus.accepted:
      return 'accepted';
    case ExpenseStatus.disputed:
      return 'disputed';
    case ExpenseStatus.settled:
      return 'settled';
  }
}

Expense expenseFromJson(Map<String, dynamic> json) {
  return Expense(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'PLN',
    category: json['category'] as String,
    childId: json['childId'] as String?,
    paidBy: json['paidBy'] as String,
    splitRatio: (json['splitRatio'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    receiptUrl: json['receiptUrl'] as String?,
    hasReceipt: json['hasReceipt'] as bool? ?? false,
    status: expenseStatusFromApi(json['status'] as String),
    note: json['note'] as String?,
    hash: json['hash'] as String,
  );
}

Map<String, dynamic> expenseToJson(Expense expense) {
  return {
    'id': expense.id,
    'title': expense.title,
    'amount': expense.amount,
    'currency': expense.currency,
    'category': expense.category,
    'childId': expense.childId,
    'paidBy': expense.paidBy,
    'splitRatio': expense.splitRatio,
    'date': expenseDateToApi(expense.date),
    'receiptUrl': expense.receiptUrl,
    'hasReceipt': expense.hasReceipt,
    'status': expenseStatusToApi(expense.status),
    'note': expense.note,
    'hash': expense.hash,
  };
}
