import '../../models/models.dart';

class CalendarSnapshot {
  final List<CustodySlot> custodySlots;
  final List<CalendarEvent> events;
  final List<SwapRequest> swapRequests;

  const CalendarSnapshot({
    required this.custodySlots,
    required this.events,
    required this.swapRequests,
  });

  bool get isEmpty =>
      custodySlots.isEmpty && events.isEmpty && swapRequests.isEmpty;
}
