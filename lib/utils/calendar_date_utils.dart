/// Backend (Zod `.datetime()`) requires ISO-8601 with timezone, e.g. `…Z`.
String calendarDateToApiIso(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(local.year, local.month, local.day, 12).toIso8601String();
}

/// Event start/end with a specific local time.
String calendarDateTimeToApiIso(DateTime date) {
  return date.toLocal().toUtc().toIso8601String();
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

String? formatEventTimeLabel(DateTime date) {
  final local = date.toLocal();
  if (local.hour == 0 && local.minute == 0) {
    return null;
  }
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
