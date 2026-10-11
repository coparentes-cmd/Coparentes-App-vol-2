import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/finance_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/finance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Expense _expense({
  required String id,
  required double amount,
  required String paidBy,
  required ExpenseStatus status,
  double splitRatio = 0.5,
}) {
  return Expense(
    id: id,
    title: id,
    amount: amount,
    category: 'Szkoła',
    paidBy: paidBy,
    splitRatio: splitRatio,
    date: DateTime(2026, 10, 11),
    status: status,
    hash: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FinanceProvider finance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    finance = FinanceProvider(
      repository: FinanceRepository(
        apiClient: AppApiClient(baseUrl: 'http://127.0.0.1:0/api'),
        offlineStore: OfflineStore(preferences: preferences),
      ),
    );
  });

  test('Kinga 500 / Lukasz 1100 → Kinga winna 600 (not 1100)', () {
    finance.debugReplaceExpenses([
      _expense(
        id: 'ubrania',
        amount: 500,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'szkola',
        amount: 1100,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
    ]);

    final totals = finance.paidTotalsForParents(
      parentAId: 'kinga',
      parentBId: 'lukasz',
    );
    expect(totals.paidByA, 500);
    expect(totals.paidByB, 1100);

    final balance = finance.netBalanceBetweenParents(
      parentAId: 'kinga',
      parentBId: 'lukasz',
      parentAName: 'Kinga Staszewska',
      parentBName: 'Lukasz Nowak',
    );
    expect(balance, isNotNull);
    expect(balance!.debtorId, 'kinga');
    expect(balance.creditorId, 'lukasz');
    expect(balance.amount, 600);
    expect(
      finance.balanceHeadline(
        parentAId: 'kinga',
        parentBId: 'lukasz',
        parentAName: 'Kinga Staszewska',
        parentBName: 'Lukasz Nowak',
      ),
      'Kinga winien Lukasz: 600 PLN',
    );
  });

  test('settled payments still count toward paid difference', () {
    finance.debugReplaceExpenses([
      _expense(
        id: 'a',
        amount: 500,
        paidBy: 'kinga',
        status: ExpenseStatus.settled,
      ),
      _expense(
        id: 'b',
        amount: 1100,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
    ]);

    expect(
      finance
          .netBalanceBetweenParents(
            parentAId: 'kinga',
            parentBId: 'lukasz',
            parentAName: 'Kinga',
            parentBName: 'Lukasz',
          )
          ?.amount,
      600,
    );
  });

  test('balance is difference of accepted paid totals (1000 - 300 = 700)', () {
    finance.debugReplaceExpenses([
      _expense(
        id: 'k',
        amount: 300,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'l',
        amount: 1000,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
    ]);

    final balance = finance.netBalanceBetweenParents(
      parentAId: 'kinga',
      parentBId: 'lukasz',
      parentAName: 'Kinga',
      parentBName: 'Lukasz',
    );

    expect(balance, isNotNull);
    expect(balance!.debtorId, 'kinga');
    expect(balance.creditorId, 'lukasz');
    expect(balance.amount, 700);
    expect(
      finance.balanceHeadline(
        parentAId: 'kinga',
        parentBId: 'lukasz',
        parentAName: 'Kinga Staszewska',
        parentBName: 'Lukasz Nowak',
      ),
      'Kinga winien Lukasz: 700 PLN',
    );
  });

  test('balance ignores pending; updates when accepted change', () {
    finance.debugReplaceExpenses([
      _expense(
        id: 'a',
        amount: 500,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'b',
        amount: 1100,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'pending',
        amount: 999,
        paidBy: 'lukasz',
        status: ExpenseStatus.pending,
      ),
    ]);

    expect(
      finance
          .netBalanceBetweenParents(
            parentAId: 'kinga',
            parentBId: 'lukasz',
            parentAName: 'Kinga',
            parentBName: 'Lukasz',
          )
          ?.amount,
      600,
    );

    finance.debugReplaceExpenses([
      _expense(
        id: 'a',
        amount: 500,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'b',
        amount: 1100,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'c',
        amount: 200,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
    ]);

    // Lukasz 1100 − Kinga 700 = 400
    expect(
      finance
          .netBalanceBetweenParents(
            parentAId: 'kinga',
            parentBId: 'lukasz',
            parentAName: 'Kinga',
            parentBName: 'Lukasz',
          )
          ?.amount,
      400,
    );
  });

  test('equal paid totals yield zero balance', () {
    finance.debugReplaceExpenses([
      _expense(
        id: 'a',
        amount: 400,
        paidBy: 'kinga',
        status: ExpenseStatus.accepted,
      ),
      _expense(
        id: 'b',
        amount: 400,
        paidBy: 'lukasz',
        status: ExpenseStatus.accepted,
      ),
    ]);

    expect(
      finance.netBalanceBetweenParents(
        parentAId: 'kinga',
        parentBId: 'lukasz',
        parentAName: 'Kinga',
        parentBName: 'Lukasz',
      ),
      isNull,
    );
  });

  test('report child filter keeps only matching and shared expenses', () {
    finance.debugReplaceExpenses([
      Expense(
        id: 'janek',
        title: 'Janek',
        amount: 100,
        category: 'Szkoła',
        childIds: const ['child_janek'],
        paidBy: 'kinga',
        splitRatio: 0.5,
        date: DateTime(2026, 10, 5),
        status: ExpenseStatus.accepted,
        hash: 'j',
      ),
      Expense(
        id: 'zosia',
        title: 'Zosia',
        amount: 200,
        category: 'Ubrania',
        childIds: const ['child_zosia'],
        paidBy: 'lukasz',
        splitRatio: 0.5,
        date: DateTime(2026, 10, 6),
        status: ExpenseStatus.accepted,
        hash: 'z',
      ),
      Expense(
        id: 'shared',
        title: 'Shared',
        amount: 50,
        category: 'Jedzenie',
        childIds: const [],
        paidBy: 'kinga',
        splitRatio: 0.5,
        date: DateTime(2026, 10, 7),
        status: ExpenseStatus.accepted,
        hash: 's',
      ),
    ]);

    final from = DateTime(2026, 10, 1);
    final to = DateTime(2026, 10, 31);
    final forJanek = finance.expensesInRange(from, to, childId: 'child_janek');
    expect(forJanek.map((e) => e.id), containsAll(['janek', 'shared']));
    expect(forJanek.any((e) => e.id == 'zosia'), isFalse);

    final totals = finance.categoryTotalsInRange(
      from,
      to,
      childId: 'child_janek',
    );
    expect(totals['Szkoła'], 100);
    expect(totals['Jedzenie'], 50);
    expect(totals.containsKey('Ubrania'), isFalse);
  });
}
