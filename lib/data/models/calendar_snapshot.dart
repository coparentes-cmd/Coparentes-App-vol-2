import '../../models/models.dart';

class CalendarSnapshot {
  final List<CustodySlot> custodySlots;
  final List<CalendarEvent> events;
  final List<SwapRequest> swapRequests;
  final CustodySchedule? custodySchedule;
  final List<CustodyException> custodyExceptions;

  const CalendarSnapshot({
    required this.custodySlots,
    required this.events,
    required this.swapRequests,
    this.custodySchedule,
    this.custodyExceptions = const [],
  });

  bool get isEmpty =>
      custodySlots.isEmpty &&
      events.isEmpty &&
      swapRequests.isEmpty &&
      custodySchedule == null &&
      custodyExceptions.isEmpty;

  List<CustodyException> get pendingExceptions => custodyExceptions
      .where((item) => item.status == CustodyExceptionStatus.pending)
      .toList();
}
