import 'package:coparentes/models/models.dart';
import 'package:coparentes/utils/custody_schedule_utils.dart';
import 'package:flutter_test/flutter_test.dart';

CustodySlot _slot(DateTime date, {String? time = '17:00'}) {
  return CustodySlot(
    id: 'slot_${date.toIso8601String()}',
    date: date,
    custodian: UserRole.parentA,
    handoverTime: time,
  );
}

void main() {
  final today = DateTime(2026, 8, 6); // Thursday

  test('formats tomorrow with relative label', () {
    final label = formatNextHandoverLabel(
      _slot(DateTime(2026, 8, 7)),
      now: today,
    );
    expect(label, 'piątek, 7 sierpnia (jutro) 17:00');
  });

  test('formats today and day-after-tomorrow', () {
    expect(
      formatNextHandoverLabel(_slot(DateTime(2026, 8, 6)), now: today),
      'czwartek, 6 sierpnia (dzisiaj) 17:00',
    );
    expect(
      formatNextHandoverLabel(_slot(DateTime(2026, 8, 8)), now: today),
      'sobota, 8 sierpnia (pojutrze) 17:00',
    );
  });

  test('omits relative label beyond pojutrze', () {
    final label = formatNextHandoverLabel(
      _slot(DateTime(2026, 8, 10)),
      now: today,
    );
    expect(label, 'poniedziałek, 10 sierpnia 17:00');
    expect(label.contains('('), isFalse);
  });

  test('works without handover time', () {
    final label = formatNextHandoverLabel(
      _slot(DateTime(2026, 8, 7), time: null),
      now: today,
    );
    expect(label, 'piątek, 7 sierpnia (jutro)');
  });
}
