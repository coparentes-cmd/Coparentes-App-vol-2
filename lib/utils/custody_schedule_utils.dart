import '../models/models.dart';
import 'demo_time.dart';

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
    DateTime.utc(date.year, date.month, date.day);

bool isSameCustodyDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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

int resolveCustomWeekInterval(CustodySchedule schedule) {
  final explicit = schedule.weekInterval;
  if (explicit != null && explicit > 0) {
    return explicit;
  }
  // Legacy custom schedules without interval: weekly if A==B, else biweekly.
  if (schedule.patternType == CustodySchedulePattern.customWeek) {
    final same = schedule.weekA.days.length == schedule.weekB.days.length &&
        schedule.weekA.days.entries.every(
          (entry) => schedule.weekB.days[entry.key] == entry.value,
        );
    return same ? 1 : 2;
  }
  return 2;
}

UserRole custodianForScheduleDate(CustodySchedule schedule, DateTime date) {
  final patterns = resolveWeekPatterns(schedule);
  final start = normalizeScheduleDate(schedule.startDate);
  final current = normalizeScheduleDate(date);
  final weekIndex = current.difference(start).inDays ~/ 7;
  if (schedule.patternType == CustodySchedulePattern.customWeek) {
    final interval = resolveCustomWeekInterval(schedule);
    final pattern =
        weekIndex % interval == 0 ? patterns.weekA : patterns.weekB;
    return pattern.forWeekday(current.weekday);
  }
  final pattern = weekIndex.isEven ? patterns.weekA : patterns.weekB;
  return pattern.forWeekday(current.weekday);
}

List<CustodySlot> generateSlotsFromSchedule(
  CustodySchedule schedule, {
  int monthsAhead = 12,
}) {
  final start = normalizeScheduleDate(schedule.startDate);
  final endExclusive = schedule.endDate == null
      ? DateTime.utc(start.year, start.month + monthsAhead, start.day)
      : normalizeScheduleDate(schedule.endDate!).add(const Duration(days: 1));

  final slots = <CustodySlot>[];
  for (var cursor = start;
      cursor.isBefore(endExclusive);
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day + 1)) {
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
      overrideByDay[key] = slot.copyWith(
        date: normalizeScheduleDate(slot.date),
      );
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

String _dayKey(DateTime date) =>
    '${date.year}-${date.month}-${date.day}';

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

CustodySlot _enrichHandoverDetails(
  CustodySlot slot,
  CustodySchedule? schedule,
) {
  final time = slot.handoverTime?.trim();
  final place = slot.handoverLocation?.trim();
  return slot.copyWith(
    handoverTime: (time != null && time.isNotEmpty)
        ? slot.handoverTime
        : schedule?.handoverTime,
    handoverLocation: (place != null && place.isNotEmpty)
        ? slot.handoverLocation
        : schedule?.handoverLocation,
  );
}

bool handoverMomentAlreadyPassed(CustodySlot slot, DateTime now) {
  final day = _dateOnly(slot.date);
  final today = _dateOnly(now);
  if (day.isAfter(today)) {
    return false;
  }
  if (day.isBefore(today)) {
    return true;
  }
  final raw = slot.handoverTime?.trim();
  if (raw == null || raw.isEmpty) {
    return false;
  }
  final parts = raw.split(':');
  if (parts.length < 2) {
    return false;
  }
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) {
    return false;
  }
  final at = DateTime(now.year, now.month, now.day, hour, minute);
  return !now.isBefore(at);
}

/// Next custody handoff: first upcoming day where the custodian changes.
CustodySlot? findNextCustodyHandover({
  required List<CustodySlot> slots,
  CustodySchedule? schedule,
  DateTime? after,
}) {
  if (slots.isEmpty) {
    return null;
  }

  final base = after ?? DemoTime.now();
  final today = _dateOnly(base);
  final sorted = [...slots]..sort((a, b) => a.date.compareTo(b.date));

  CustodySlot? previous;
  for (final slot in sorted) {
    final day = _dateOnly(slot.date);
    final isHandoverDay =
        previous != null && previous.custodian != slot.custodian;
    previous = slot;

    if (!isHandoverDay || day.isBefore(today)) {
      continue;
    }

    final enriched = _enrichHandoverDetails(slot, schedule);
    if (handoverMomentAlreadyPassed(enriched, base)) {
      continue;
    }
    return enriched;
  }

  return null;
}

const _polishWeekdays = [
  'poniedziałek',
  'wtorek',
  'środa',
  'czwartek',
  'piątek',
  'sobota',
  'niedziela',
];

const _polishMonthsGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// Label for Start handover strip, e.g. `piątek, 7 sierpnia (jutro) 17:00`.
/// Relative day only for dzisiaj / jutro / pojutrze.
String formatNextHandoverLabel(CustodySlot slot, {DateTime? now}) {
  final base = now ?? DemoTime.now();
  final day = _dateOnly(slot.date);
  final today = _dateOnly(base);
  final weekday = _polishWeekdays[day.weekday - 1];
  final month = _polishMonthsGenitive[day.month - 1];
  final datePart = '$weekday, ${day.day} $month';

  final dayDiff = day.difference(today).inDays;
  final relative = switch (dayDiff) {
    0 => 'dzisiaj',
    1 => 'jutro',
    2 => 'pojutrze',
    _ => null,
  };

  final withRelative =
      relative == null ? datePart : '$datePart ($relative)';
  final time = slot.handoverTime?.trim();
  if (time == null || time.isEmpty) {
    return withRelative;
  }
  return '$withRelative $time';
}
