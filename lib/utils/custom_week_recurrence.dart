import '../models/models.dart';

const customWeekIntervalMetaKey = '_weekInterval';

const customWeekDayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const customWeekDayLabels = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

/// Builds on-week / off-week maps for a custom weekly custody pattern.
({Map<String, UserRole> weekA, Map<String, UserRole> weekB})
    buildCustomWeekPatterns({
  required UserRole creatorRole,
  required Set<int> weekdays,
  required int intervalWeeks,
}) {
  final other = creatorRole == UserRole.parentA
      ? UserRole.parentB
      : UserRole.parentA;
  final onWeek = {for (final key in customWeekDayKeys) key: other};
  for (final weekday in weekdays) {
    if (weekday < 1 || weekday > 7) {
      continue;
    }
    onWeek[customWeekDayKeys[weekday - 1]] = creatorRole;
  }
  final offWeek = {for (final key in customWeekDayKeys) key: other};
  if (intervalWeeks <= 1) {
    return (weekA: onWeek, weekB: Map<String, UserRole>.from(onWeek));
  }
  return (weekA: onWeek, weekB: offWeek);
}

/// Date of the [occurrenceCount]-th creator care day for the pattern.
DateTime endDateFromCustomOccurrences({
  required DateTime startDate,
  required Set<int> weekdays,
  required int intervalWeeks,
  required int occurrenceCount,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final interval = intervalWeeks < 1 ? 1 : intervalWeeks;
  var matched = 0;
  var cursor = start;
  for (var i = 0; i < 3700 && matched < occurrenceCount; i++) {
    final weekIndex = cursor.difference(start).inDays ~/ 7;
    final onCycle = weekIndex % interval == 0;
    if (onCycle && weekdays.contains(cursor.weekday)) {
      matched++;
      if (matched == occurrenceCount) {
        return cursor;
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return cursor;
}

int? weekIntervalFromPatternMap(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final raw = json[customWeekIntervalMetaKey];
  if (raw is int) {
    return raw < 1 ? 1 : raw;
  }
  if (raw is num) {
    final value = raw.toInt();
    return value < 1 ? 1 : value;
  }
  if (raw is String) {
    final value = int.tryParse(raw);
    if (value == null) {
      return null;
    }
    return value < 1 ? 1 : value;
  }
  return null;
}

Map<String, dynamic> dayRolesOnly(Map<String, dynamic> json) {
  return Map<String, dynamic>.fromEntries(
    json.entries.where((entry) => entry.key != customWeekIntervalMetaKey),
  );
}

String customWeekSummary({
  required int intervalWeeks,
  required Set<int> weekdays,
  required String creatorLabel,
}) {
  final sorted = weekdays.toList()..sort();
  final dayNames = sorted.map((day) {
    const names = [
      'poniedziałki',
      'wtorki',
      'środy',
      'czwartki',
      'piątki',
      'soboty',
      'niedziele',
    ];
    return names[day - 1];
  }).toList();

  final daysPart = switch (dayNames.length) {
    0 => 'wybrane dni',
    1 => dayNames.first,
    2 => '${dayNames[0]} i ${dayNames[1]}',
    _ => '${dayNames.sublist(0, dayNames.length - 1).join(', ')} i ${dayNames.last}',
  };

  final intervalPart = intervalWeeks <= 1
      ? 'co tydzień'
      : 'co $intervalWeeks tygodnie';

  return 'Opieka u $creatorLabel $intervalPart w $daysPart';
}
