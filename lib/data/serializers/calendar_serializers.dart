import '../../models/models.dart';
import '../../utils/calendar_date_utils.dart';
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
    date: DateTime.parse(json['date'] as String),
    custodian: userRoleFromApi(json['custodian'] as String),
    handoverLocation: json['handoverLocation'] as String?,
    handoverTime: json['handoverTime'] as String?,
  );
}

Map<String, dynamic> custodySlotToJson(CustodySlot slot) {
  return {
    'id': slot.id,
    'date': calendarDateToApiIso(slot.date),
    'custodian': userRoleToApi(slot.custodian),
    'handoverLocation': slot.handoverLocation,
    'handoverTime': slot.handoverTime,
  };
}

CalendarEvent calendarEventFromJson(Map<String, dynamic> json) {
  return CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String),
    type: eventTypeFromApi(json['type'] as String),
    childId: json['childId'] as String?,
    createdBy: json['createdBy'] as String,
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
    originalDate: DateTime.parse(json['originalDate'] as String),
    proposedDate: DateTime.parse(json['proposedDate'] as String),
    reason: json['reason'] as String?,
    status: swapStatusFromApi(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
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
