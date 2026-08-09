import '../../models/models.dart';
import '../../utils/calendar_date_utils.dart';
import '../../utils/custody_schedule_utils.dart';
import 'api_serializers.dart' show userRoleFromApi, userRoleToApi;

EventType eventTypeFromApi(String value) {
  switch (value) {
    case 'school':
      return EventType.school;
    case 'medical':
      return EventType.medical;
    case 'activity':
      return EventType.activity;
    case 'handover':
      return EventType.handover;
    case 'holiday':
      return EventType.holiday;
    default:
      return EventType.other;
  }
}

String eventTypeToApi(EventType type) {
  switch (type) {
    case EventType.school:
      return 'school';
    case EventType.medical:
      return 'medical';
    case EventType.activity:
      return 'activity';
    case EventType.handover:
      return 'handover';
    case EventType.holiday:
      return 'holiday';
    case EventType.other:
      return 'other';
  }
}

SwapStatus swapStatusFromApi(String value) {
  switch (value) {
    case 'pending':
      return SwapStatus.pending;
    case 'accepted':
      return SwapStatus.accepted;
    case 'rejected':
      return SwapStatus.rejected;
    case 'counterProposed':
      return SwapStatus.counterProposed;
    default:
      return SwapStatus.pending;
  }
}

String swapStatusToApi(SwapStatus status) {
  switch (status) {
    case SwapStatus.pending:
      return 'pending';
    case SwapStatus.accepted:
      return 'accepted';
    case SwapStatus.rejected:
      return 'rejected';
    case SwapStatus.counterProposed:
      return 'counterProposed';
  }
}

CustodySlot custodySlotFromJson(Map<String, dynamic> json) {
  return CustodySlot(
    id: json['id'] as String,
    date: normalizeScheduleDate(DateTime.parse(json['date'] as String)),
    custodian: userRoleFromApi(json['custodian'] as String),
    handoverLocation: json['handoverLocation'] as String?,
    handoverTime: json['handoverTime'] as String?,
    source: custodySlotSourceFromApi(json['source'] as String? ?? 'schedule'),
  );
}

CustodySlotSource custodySlotSourceFromApi(String value) {
  switch (value) {
    case 'exception':
      return CustodySlotSource.exception;
    case 'manual':
      return CustodySlotSource.manual;
    case 'swap':
      return CustodySlotSource.swap;
    default:
      return CustodySlotSource.schedule;
  }
}

String custodySlotSourceToApi(CustodySlotSource source) {
  switch (source) {
    case CustodySlotSource.exception:
      return 'exception';
    case CustodySlotSource.manual:
      return 'manual';
    case CustodySlotSource.swap:
      return 'swap';
    case CustodySlotSource.schedule:
      return 'schedule';
  }
}

Map<String, dynamic> custodySlotToJson(CustodySlot slot) {
  return {
    'id': slot.id,
    'date': calendarDateToApiIso(slot.date),
    'custodian': userRoleToApi(slot.custodian),
    'handoverLocation': slot.handoverLocation,
    'handoverTime': slot.handoverTime,
    'source': custodySlotSourceToApi(slot.source),
  };
}

CustodySchedulePattern custodySchedulePatternFromApi(String value) {
  switch (value) {
    case 'everyOtherWeekend':
      return CustodySchedulePattern.everyOtherWeekend;
    case 'customWeek':
      return CustodySchedulePattern.customWeek;
    default:
      return CustodySchedulePattern.weekAlternating;
  }
}

String custodySchedulePatternToApi(CustodySchedulePattern pattern) {
  switch (pattern) {
    case CustodySchedulePattern.everyOtherWeekend:
      return 'everyOtherWeekend';
    case CustodySchedulePattern.customWeek:
      return 'customWeek';
    case CustodySchedulePattern.weekAlternating:
      return 'weekAlternating';
  }
}

CustodyScheduleStatus custodyScheduleStatusFromApi(String value) {
  switch (value) {
    case 'draft':
      return CustodyScheduleStatus.draft;
    case 'active':
      return CustodyScheduleStatus.active;
    case 'superseded':
      return CustodyScheduleStatus.superseded;
    default:
      return CustodyScheduleStatus.pendingApproval;
  }
}

CustodyWeekPattern _weekPatternFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return const CustodyWeekPattern({});
  }
  final days = <String, UserRole>{};
  for (final entry in json.entries) {
    if (entry.key.startsWith('_')) {
      continue;
    }
    final value = entry.value;
    if (value is! String) {
      continue;
    }
    days[entry.key] = userRoleFromApi(value);
  }
  return CustodyWeekPattern(days);
}

Map<String, String> weekPatternToApi(CustodyWeekPattern pattern) {
  return pattern.days.map(
    (key, value) => MapEntry(key, userRoleToApi(value)),
  );
}

Map<String, dynamic> weekPatternToApiWithInterval(
  CustodyWeekPattern pattern, {
  int? weekInterval,
}) {
  final map = <String, dynamic>{...weekPatternToApi(pattern)};
  if (weekInterval != null && weekInterval > 0) {
    map['_weekInterval'] = weekInterval;
  }
  return map;
}

CustodySchedule? custodyScheduleFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final weekAJson =
      Map<String, dynamic>.from(json['weekA'] as Map? ?? const {});
  return CustodySchedule(
    id: json['id'] as String,
    patternType: custodySchedulePatternFromApi(json['patternType'] as String),
    startDate: normalizeScheduleDate(DateTime.parse(json['startDate'] as String)),
    endDate: json['endDate'] == null
        ? null
        : normalizeScheduleDate(DateTime.parse(json['endDate'] as String)),
    weekA: _weekPatternFromJson(weekAJson),
    weekB: _weekPatternFromJson(
      Map<String, dynamic>.from(json['weekB'] as Map? ?? const {}),
    ),
    weekInterval: () {
      final top = json['weekInterval'];
      if (top is int) {
        return top;
      }
      if (top is num) {
        return top.toInt();
      }
      final raw = weekAJson['_weekInterval'];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return null;
    }(),
    handoverTime: json['handoverTime'] as String?,
    handoverLocation: json['handoverLocation'] as String?,
    status: custodyScheduleStatusFromApi(json['status'] as String),
    proposedById: json['proposedById'] as String,
    approvedById: json['approvedById'] as String?,
    approvedAt: json['approvedAt'] == null
        ? null
        : DateTime.parse(json['approvedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

Map<String, dynamic> custodyScheduleToJson(CustodySchedule schedule) {
  return {
    'id': schedule.id,
    'patternType': custodySchedulePatternToApi(schedule.patternType),
    'startDate': schedule.startDate.toIso8601String(),
    'endDate': schedule.endDate?.toIso8601String(),
    'weekA': weekPatternToApiWithInterval(
      schedule.weekA,
      weekInterval: schedule.weekInterval,
    ),
    'weekB': weekPatternToApi(schedule.weekB),
    if (schedule.weekInterval != null) 'weekInterval': schedule.weekInterval,
    'handoverTime': schedule.handoverTime,
    'handoverLocation': schedule.handoverLocation,
    'status': schedule.status.name == 'pendingApproval'
        ? 'pendingApproval'
        : schedule.status.name,
    'proposedById': schedule.proposedById,
    'approvedById': schedule.approvedById,
    'approvedAt': schedule.approvedAt?.toIso8601String(),
    'createdAt': schedule.createdAt.toIso8601String(),
  };
}

CustodyExceptionType custodyExceptionTypeFromApi(String value) {
  switch (value) {
    case 'range':
      return CustodyExceptionType.range;
    case 'holiday':
      return CustodyExceptionType.holiday;
    default:
      return CustodyExceptionType.singleDay;
  }
}

String custodyExceptionTypeToApi(CustodyExceptionType type) {
  switch (type) {
    case CustodyExceptionType.range:
      return 'range';
    case CustodyExceptionType.holiday:
      return 'holiday';
    case CustodyExceptionType.singleDay:
      return 'singleDay';
  }
}

CustodyExceptionStatus custodyExceptionStatusFromApi(String value) {
  switch (value) {
    case 'accepted':
      return CustodyExceptionStatus.accepted;
    case 'rejected':
      return CustodyExceptionStatus.rejected;
    default:
      return CustodyExceptionStatus.pending;
  }
}

String custodyExceptionStatusToApi(CustodyExceptionStatus status) {
  switch (status) {
    case CustodyExceptionStatus.accepted:
      return 'accepted';
    case CustodyExceptionStatus.rejected:
      return 'rejected';
    case CustodyExceptionStatus.pending:
      return 'pending';
  }
}

CustodyException custodyExceptionFromJson(Map<String, dynamic> json) {
  return CustodyException(
    id: json['id'] as String,
    fromDate: normalizeScheduleDate(
      parseApiDateTime(json['fromDate'] as String),
    ),
    toDate: normalizeScheduleDate(
      parseApiDateTime(json['toDate'] as String),
    ),
    custodian: userRoleFromApi(json['custodian'] as String),
    exceptionType: custodyExceptionTypeFromApi(
      json['exceptionType'] as String? ?? 'singleDay',
    ),
    reason: json['reason'] as String?,
    status: custodyExceptionStatusFromApi(json['status'] as String),
    requesterId: json['requesterId'] as String,
    responseNote: json['responseNote'] as String?,
    createdAt: parseApiDateTime(json['createdAt'] as String),
  );
}

Map<String, dynamic> custodyExceptionToJson(CustodyException exception) {
  return {
    'id': exception.id,
    'fromDate': calendarDateToApiIso(exception.fromDate),
    'toDate': calendarDateToApiIso(exception.toDate),
    'custodian': userRoleToApi(exception.custodian),
    'exceptionType': custodyExceptionTypeToApi(exception.exceptionType),
    'reason': exception.reason,
    'status': custodyExceptionStatusToApi(exception.status),
    'requesterId': exception.requesterId,
    'responseNote': exception.responseNote,
    'createdAt': exception.createdAt.toIso8601String(),
  };
}

CalendarEvent calendarEventFromJson(Map<String, dynamic> json) {
  return CalendarEvent(
    id: json['id'] as String,
    title: (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : 'Zdarzenie',
    description: json['description'] as String?,
    startDate: parseApiDateTime(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : parseApiDateTime(json['endDate'] as String),
    type: eventTypeFromApi(json['type'] as String? ?? 'other'),
    childId: json['childId'] as String?,
    createdBy: json['createdBy'] as String? ?? '',
    location: json['location'] as String?,
  );
}

Map<String, dynamic> calendarEventToJson(CalendarEvent event) {
  return {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'startDate': calendarStartDateToApiIso(event.startDate),
    'endDate':
        event.endDate == null ? null : calendarStartDateToApiIso(event.endDate!),
    'type': eventTypeToApi(event.type),
    'childId': event.childId,
    'createdBy': event.createdBy,
    'location': event.location,
  };
}

SwapRequest swapRequestFromJson(Map<String, dynamic> json) {
  return SwapRequest(
    id: json['id'] as String,
    requesterId: json['requesterId'] as String,
    requesterName: json['requesterName'] as String,
    originalDate: normalizeScheduleDate(
      parseApiDateTime(json['originalDate'] as String),
    ),
    proposedDate: normalizeScheduleDate(
      parseApiDateTime(json['proposedDate'] as String),
    ),
    reason: json['reason'] as String?,
    status: swapStatusFromApi(json['status'] as String),
    createdAt: parseApiDateTime(json['createdAt'] as String),
    responseNote: json['responseNote'] as String?,
  );
}

Map<String, dynamic> swapRequestToJson(SwapRequest swap) {
  return {
    'id': swap.id,
    'requesterId': swap.requesterId,
    'requesterName': swap.requesterName,
    'originalDate': swap.originalDate.toIso8601String(),
    'proposedDate': swap.proposedDate.toIso8601String(),
    'reason': swap.reason,
    'status': swapStatusToApi(swap.status),
    'createdAt': swap.createdAt.toIso8601String(),
    'responseNote': swap.responseNote,
  };
}
