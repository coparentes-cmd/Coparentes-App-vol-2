import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/models/models.dart';
import 'package:coparentes/utils/custody_schedule_utils.dart';

void main() {
  test('generated slots match table_calendar UTC day cells', () {
    final schedule = CustodySchedule(
      id: 't',
      patternType: CustodySchedulePattern.weekAlternating,
      startDate: DateTime.parse('2026-08-09T12:00:00.000Z'),
      endDate: DateTime.parse('2026-08-20T12:00:00.000Z'),
      weekA: const CustodyWeekPattern({}),
      weekB: const CustodyWeekPattern({}),
      status: CustodyScheduleStatus.active,
      proposedById: 'a',
      createdAt: DateTime.now(),
    );

    final slots = generateSlotsFromSchedule(schedule);
    expect(slots, isNotEmpty);

    final cell = DateTime.utc(2026, 8, 9);
    final matched =
        slots.where((s) => isSameCustodyDay(s.date, cell)).toList();
    expect(matched, isNotEmpty, reason: 'Aug 9 cell must find a custody slot');
    expect(matched.first.custodian, UserRole.parentA);
  });

  test('week alternating paints both parents', () {
    final schedule = CustodySchedule(
      id: 't',
      patternType: CustodySchedulePattern.weekAlternating,
      startDate: DateTime.utc(2026, 8, 10), // Monday
      endDate: DateTime.utc(2026, 8, 23),
      weekA: const CustodyWeekPattern({}),
      weekB: const CustodyWeekPattern({}),
      status: CustodyScheduleStatus.active,
      proposedById: 'a',
      createdAt: DateTime.now(),
    );

    expect(
      custodianForScheduleDate(schedule, DateTime.utc(2026, 8, 10)),
      UserRole.parentA,
    );
    expect(
      custodianForScheduleDate(schedule, DateTime.utc(2026, 8, 17)),
      UserRole.parentB,
    );
  });
}
