import '../models/models.dart';

const _dayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

DateTime normalizeScheduleDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

({CustodyWeekPattern weekA, CustodyWeekPattern weekB}) resolveWeekPatterns(
  CustodySchedule schedule,
) {
  switch (schedule.patternType) {
    case CustodySchedulePattern.weekAlternating:
      return (
        weekA: CustodyWeekPattern({
          for (final key in _dayKeys) key: UserRole.parentA,
        }),
        weekB: CustodyWeekPattern({
          for (final key in _dayKeys) key: UserRole.parentB,
        }),
      );
    case CustodySchedulePattern.everyOtherWeekend:
      return (
        weekA: const CustodyWeekPattern({
          'monday': UserRole.parentA,
          'tuesday': UserRole.parentA,
          'wednesday': UserRole.parentA,
          'thursday': UserRole.parentA,
          'friday': UserRole.parentA,
          'saturday': UserRole.parentB,
          'sunday': UserRole.parentB,
        }),
        weekB: const CustodyWeekPattern({
          'monday': UserRole.parentB,
          'tuesday': UserRole.parentB,
          'wednesday': UserRole.parentB,
          'thursday': UserRole.parentB,
          'friday': UserRole.parentB,
          'saturday': UserRole.parentA,
          'sunday': UserRole.parentA,
        }),
      );
    case CustodySchedulePattern.customWeek:
      return (weekA: schedule.weekA, weekB: schedule.weekB);
  }
}

UserRole custodianForScheduleDate(CustodySchedule schedule, DateTime date) {
  final patterns = resolveWeekPatterns(schedule);
  final start = normalizeScheduleDate(schedule.startDate);
  final current = normalizeScheduleDate(date);
  final weekIndex = current.difference(start).inDays ~/ 7;
  final pattern = weekIndex.isEven ? patterns.weekA : patterns.weekB;
  return pattern.forWeekday(current.weekday);
}

List<CustodySlot> generateSlotsFromSchedule(
  CustodySchedule schedule, {
  int monthsAhead = 12,
}) {
  final start = normalizeScheduleDate(schedule.startDate);
  final end = schedule.endDate == null
      ? DateTime(start.year, start.month + monthsAhead, start.day)
      : normalizeScheduleDate(schedule.endDate!).add(const Duration(days: 1));

  final slots = <CustodySlot>[];
  for (var cursor = start;
      cursor.isBefore(end);
      cursor = cursor.add(const Duration(days: 1))) {
    slots.add(
      CustodySlot(
        id: 'sched_${schedule.id}_${cursor.year}${cursor.month}${cursor.day}',
        date: cursor,
        custodian: custodianForScheduleDate(schedule, cursor),
        handoverLocation: schedule.handoverLocation,
        handoverTime: schedule.handoverTime,
        source: CustodySlotSource.schedule,
      ),
    );
  }
  return slots;
}

List<CustodySlot> mergeScheduleSlotsWithOverrides({
  required List<CustodySlot> generated,
  required List<CustodySlot> overrides,
}) {
  if (overrides.isEmpty) {
    return generated;
  }

  final overrideByDay = <String, CustodySlot>{};
  for (final slot in overrides) {
    if (slot.source == CustodySlotSource.exception ||
        slot.source == CustodySlotSource.swap) {
      final key =
          '${slot.date.year}-${slot.date.month}-${slot.date.day}';
      overrideByDay[key] = slot;
    }
  }

  if (overrideByDay.isEmpty) {
    return generated;
  }

  return generated
      .map((slot) {
        final key = '${slot.date.year}-${slot.date.month}-${slot.date.day}';
        return overrideByDay[key] ?? slot;
      })
      .toList();
}
