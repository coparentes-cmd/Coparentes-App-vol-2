/// Backend (Zod `.datetime()`) requires ISO-8601 with timezone, e.g. `…Z`.
String calendarDateToApiIso(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(local.year, local.month, local.day, 12).toIso8601String();
}

/// Parse an API ISO timestamp into the device-local wall clock.
DateTime parseApiDateTime(String value) => DateTime.parse(value).toLocal();

/// Event start/end with a specific local time.
String calendarDateTimeToApiIso(DateTime date) {
  final local = date.toLocal();
  // Explicit wall-clock → UTC (avoids Flutter-web edge cases with toUtc()).
  final offset = local.timeZoneOffset;
  final utc = DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  ).subtract(offset);
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  ).toIso8601String();
}

/// All-day events use noon UTC; timed events keep the local clock time.
String calendarStartDateToApiIso(DateTime date) {
  final local = date.toLocal();
  if (local.hour == 0 && local.minute == 0) {
    return calendarDateToApiIso(date);
  }
  return calendarDateTimeToApiIso(date);
}

/// Calendar day selected in UI (no time-of-day semantics).
DateTime calendarDayFrom(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Local date + time for a calendar event.
DateTime calendarDateTimeFrom({
  required DateTime day,
  required int hour,
  required int minute,
}) {
  final local = day.toLocal();
  return DateTime(local.year, local.month, local.day, hour, minute);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

int compareEventTimes(DateTime a, DateTime b) {
  return a.toLocal().compareTo(b.toLocal());
}

/// Clock time in the device timezone (HH:mm). Always converts UTC API values.
String formatClockTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String? formatEventTimeLabel(DateTime date) {
  final local = date.toLocal();
  if (local.hour == 0 && local.minute == 0) {
    return null;
  }
  return formatClockTime(local);
}

/// Google Calendar–style time column: "Cały dzień" or "09:30–10:00".
String formatAgendaTimeColumn({
  required DateTime start,
  DateTime? end,
}) {
  final startLabel = formatEventTimeLabel(start);
  if (startLabel == null) {
    return 'Cały dzień';
  }
  final endLabel = end == null ? null : formatEventTimeLabel(end);
  if (endLabel == null || endLabel == startLabel) {
    return startLabel;
  }
  return '$startLabel–$endLabel';
}
