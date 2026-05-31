/// Backend (Zod `.datetime()`) requires ISO-8601 with timezone, e.g. `…Z`.
String calendarDateToApiIso(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day, 12).toIso8601String();
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}
