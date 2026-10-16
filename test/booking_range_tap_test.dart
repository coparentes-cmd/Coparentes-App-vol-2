import 'package:coparentes/widgets/mini_calendar_date_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  group('bookingApplyRangeTap', () {
    test('first tap sets start only when range was complete', () {
      final next = bookingApplyRangeTap(
        rangeStart: d(2026, 10, 1),
        rangeEnd: d(2026, 10, 30),
        day: d(2026, 10, 16),
      );
      expect(next.start, d(2026, 10, 16));
      expect(next.end, isNull);
    });

    test('second tap sets end without changing start', () {
      final next = bookingApplyRangeTap(
        rangeStart: d(2026, 10, 16),
        rangeEnd: null,
        day: d(2026, 10, 30),
      );
      expect(next.start, d(2026, 10, 16));
      expect(next.end, d(2026, 10, 30));
    });

    test('second tap before start swaps endpoints', () {
      final next = bookingApplyRangeTap(
        rangeStart: d(2026, 10, 20),
        rangeEnd: null,
        day: d(2026, 10, 10),
      );
      expect(next.start, d(2026, 10, 10));
      expect(next.end, d(2026, 10, 20));
    });

    test('same-day second tap allows start == end', () {
      final next = bookingApplyRangeTap(
        rangeStart: d(2026, 10, 30),
        rangeEnd: null,
        day: d(2026, 10, 30),
      );
      expect(next.start, d(2026, 10, 30));
      expect(next.end, d(2026, 10, 30));
    });

    test('tap when both were same day starts a new range', () {
      final next = bookingApplyRangeTap(
        rangeStart: d(2026, 10, 30),
        rangeEnd: d(2026, 10, 30),
        day: d(2026, 11, 5),
      );
      expect(next.start, d(2026, 11, 5));
      expect(next.end, isNull);
    });
  });
}
