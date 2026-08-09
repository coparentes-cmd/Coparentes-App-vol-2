import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/utils/calendar_date_utils.dart';

void main() {
  test('parseApiDateTime converts UTC to local wall clock', () {
    final parsed = parseApiDateTime('2026-08-09T15:00:00.000Z');
    expect(parsed.isUtc, isFalse);
    final local = DateTime.utc(2026, 8, 9, 15).toLocal();
    expect(parsed.hour, local.hour);
    expect(parsed.minute, local.minute);
  });

  test('calendarDateTimeToApiIso round-trips local evening time', () {
    final local = DateTime(2026, 8, 9, 17, 30);
    final iso = calendarDateTimeToApiIso(local);
    final back = parseApiDateTime(iso);
    expect(back.hour, 17);
    expect(back.minute, 30);
  });

  test('formatClockTime shows local hour for UTC instant', () {
    final utc = DateTime.utc(2026, 8, 9, 15, 0);
    final local = utc.toLocal();
    expect(formatClockTime(utc), formatClockTime(local));
  });
}
