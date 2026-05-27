import 'package:flutter/material.dart';

import '../data/models/calendar_snapshot.dart';
import '../data/repositories/calendar_repository.dart';
import '../models/models.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarRepository _repository;

  CalendarProvider({required CalendarRepository repository})
      : _repository = repository;

  final List<CustodySlot> _custodySlots = [];
  final List<CalendarEvent> _events = [];
  final List<SwapRequest> _swapRequests = [];
  bool _isLoading = false;
  String? _error;
  bool _loadedFromApi = false;

  List<CustodySlot> get custodySlots => _custodySlots;
  List<CalendarEvent> get events => _events;
  List<SwapRequest> get swapRequests => _swapRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loadedFromApi => _loadedFromApi;

  bool get isEmpty =>
      _custodySlots.isEmpty && _events.isEmpty && _swapRequests.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _repository.fetchCalendar();
      _applySnapshot(snapshot);
      _loadedFromApi = true;
    } catch (error) {
      _error = error.toString();
      _loadedFromApi = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void initializeSampleData() {
    _custodySlots.clear();
    _events.clear();
    _swapRequests.clear();
    _loadedFromApi = false;
    _error = null;

    final now = DateTime.now();

    for (int i = -14; i <= 30; i++) {
      final date = now.add(Duration(days: i));
      final weekOfYear =
          date.difference(DateTime(date.year, 1, 1)).inDays ~/ 7;
      _custodySlots.add(CustodySlot(
        id: 'slot_$i',
        date: date,
        custodian: weekOfYear.isEven ? UserRole.parentA : UserRole.parentB,
        handoverLocation: 'Szkoła SP nr 15',
        handoverTime: '16:00',
      ));
    }

    _events.addAll([
      CalendarEvent(
        id: 'evt_001',
        title: 'Angielski – Zosia',
        startDate: now.add(const Duration(days: 2)),
        type: EventType.school,
        childId: 'child_001',
        createdBy: 'user_001',
        location: 'ul. Mokotowska 12',
        description: 'Zajęcia o 17:00',
      ),
      CalendarEvent(
        id: 'evt_002',
        title: 'Dentysta – Tomek',
        startDate: now.add(const Duration(days: 5)),
        type: EventType.medical,
        childId: 'child_002',
        createdBy: 'user_001',
        location: 'Przychodnia Centrum',
        description: 'Wizyta o 10:30',
      ),
      CalendarEvent(
        id: 'evt_003',
        title: 'Basen – Tomek',
        startDate: now.add(const Duration(days: 3)),
        type: EventType.activity,
        childId: 'child_002',
        createdBy: 'user_002',
        location: 'Wodny Park',
        description: 'Trening o 15:00',
      ),
      CalendarEvent(
        id: 'evt_004',
        title: 'Przekazanie dzieci',
        startDate: now.add(const Duration(days: 7)),
        type: EventType.handover,
        createdBy: 'system',
        location: 'Szkoła SP nr 15',
        description: 'Godz. 16:00',
      ),
      CalendarEvent(
        id: 'evt_005',
        title: 'Ferie zimowe',
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 17)),
        type: EventType.holiday,
        createdBy: 'system',
      ),
    ]);

    _swapRequests.addAll([
      SwapRequest(
        id: 'swap_001',
        requesterId: 'user_002',
        requesterName: 'Marek',
        originalDate: now.add(const Duration(days: 11)),
        proposedDate: now.add(const Duration(days: 18)),
        reason: 'Wyjazd służbowy do Krakowa',
        status: SwapStatus.pending,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      SwapRequest(
        id: 'swap_002',
        requesterId: 'user_001',
        requesterName: 'Anna',
        originalDate: now.subtract(const Duration(days: 5)),
        proposedDate: now.subtract(const Duration(days: 3)),
        reason: 'Urodziny babci',
        status: SwapStatus.accepted,
        createdAt: now.subtract(const Duration(days: 10)),
        responseNote: 'Oczywiście, bez problemu.',
      ),
    ]);

    notifyListeners();
  }

  void clear() {
    _custodySlots.clear();
    _events.clear();
    _swapRequests.clear();
    _error = null;
    _isLoading = false;
    _loadedFromApi = false;
    notifyListeners();
  }

  List<CustodySlot> getSlotsForDay(DateTime date) {
    return _custodySlots
        .where(
          (s) =>
              s.date.year == date.year &&
              s.date.month == date.month &&
              s.date.day == date.day,
        )
        .toList();
  }

  List<CalendarEvent> getEventsForDay(DateTime date) {
    return _events.where((e) {
      final sameDay = e.startDate.year == date.year &&
          e.startDate.month == date.month &&
          e.startDate.day == date.day;
      if (e.endDate == null) return sameDay;
      return date.isAfter(e.startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(e.endDate!.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> respondToSwap(
    String swapId,
    SwapStatus status, {
    String? note,
  }) async {
    try {
      final updated = await _repository.respondToSwap(
        swapId: swapId,
        status: status,
        responseNote: note,
      );
      final index = _swapRequests.indexWhere((s) => s.id == swapId);
      if (index >= 0) {
        _swapRequests[index] = updated;
      }
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addEvent({
    required String title,
    required DateTime startDate,
    required EventType type,
    String? description,
    DateTime? endDate,
    String? childId,
    String? location,
  }) async {
    try {
      final created = await _repository.createEvent(
        title: title,
        startDate: startDate,
        type: type,
        description: description,
        endDate: endDate,
        childId: childId,
        location: location,
      );
      _events.add(created);
      _events.sort((a, b) => a.startDate.compareTo(b.startDate));
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createSwapRequest({
    required DateTime originalDate,
    required DateTime proposedDate,
    String? reason,
  }) async {
    try {
      final created = await _repository.createSwapRequest(
        originalDate: originalDate,
        proposedDate: proposedDate,
        reason: reason,
      );
      _swapRequests.insert(0, created);
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _applySnapshot(CalendarSnapshot snapshot) {
    _custodySlots
      ..clear()
      ..addAll(snapshot.custodySlots);
    _events
      ..clear()
      ..addAll(snapshot.events);
    _swapRequests
      ..clear()
      ..addAll(snapshot.swapRequests);
  }
}
