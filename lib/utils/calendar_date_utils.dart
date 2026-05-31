/// Backend (Zod `.datetime()`) requires ISO-8601 with timezone, e.g. `…Z`.
String calendarDateToApiIso(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(local.year, local.month, local.day, 12).toIso8601String();
}

/// Calendar day selected in UI (no time-of-day semantics).
DateTime calendarDayFrom(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}
