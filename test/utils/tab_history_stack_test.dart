import 'package:coparentes/utils/tab_history_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tab history pops in reverse navigation order', () {
    final history = TabHistoryStack();
    expect(history.isEmpty, isTrue);

    history.push(0); // Start → Finanse
    history.push(3); // Finanse → Dokumenty

    expect(history.pop(), 3);
    expect(history.pop(), 0);
    expect(history.pop(), isNull);
    expect(history.isEmpty, isTrue);
  });

  test('clear empties the stack', () {
    final history = TabHistoryStack()
      ..push(1)
      ..push(2);
    history.clear();
    expect(history.isEmpty, isTrue);
  });
}
