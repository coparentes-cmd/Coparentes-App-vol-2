import 'package:coparentes/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topSnackBarMargin pins bar near the top', () {
    final margin = topSnackBarMargin(
      const Size(400, 800),
      const EdgeInsets.only(top: 47),
      barHeight: 64,
    );

    expect(margin.left, 12);
    expect(margin.right, 12);
    // 800 - (47+12) - 64 = 677 → large bottom margin = visually at top
    expect(margin.bottom, closeTo(677, 0.1));
    expect(margin.top, 0);
  });

  testWidgets('showTopSnackBar renders floating snack near top', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showTopSnackBar(
                    const SnackBar(
                      content: Text('Uzupełnij poprawnie opis i kwotę wydatku.'),
                      backgroundColor: Color(0xFFF59E0B),
                    ),
                  );
                },
                child: const Text('Go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Uzupełnij poprawnie opis i kwotę wydatku.'), findsOneWidget);

    final snackFinder = find.byType(SnackBar);
    expect(snackFinder, findsOneWidget);
    final snackBar = tester.widget<SnackBar>(snackFinder);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    final margin = snackBar.margin;
    expect(margin, isA<EdgeInsets>());
    expect((margin! as EdgeInsets).bottom, greaterThan(400));
  });
}
