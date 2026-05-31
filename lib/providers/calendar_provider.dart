import 'package:flutter/material.dart';

import '../data/models/calendar_snapshot.dart';
import '../data/repositories/calendar_repository.dart';
import '../models/models.dart';
import '../utils/calendar_date_utils.dart';

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
  int _loadGeneration = 0;

  List<CustodySlot> get custodySlots => _custodySlots;
  List<CalendarEvent> get events => _events;
  List<SwapRequest> get swapRequests => _swapRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loadedFromApi => _loadedFromApi;

  bool get isEmpty =>
      _custodySlots.isEmpty && _events.isEmpty && _swapRequests.isEmpty;

  Future<void> load({bool silent = false}) async {
    final generation = ++_loadGeneration;

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final snapshot = await _repository.fetchCalendar();
      if (generation != _loadGeneration) {
        return;
      }
      _applySnapshot(snapshot);
      _loadedFromApi = true;
      _error = null;
    } catch (error) {
      if (generation != _loadGeneration) {
        return;
      }
      if (!silent) {
        _error = error.toString();
      }
      if (_custodySlots.isEmpty &&
          _events.isEmpty &&
          _swapRequests.isEmpty) {
        _loadedFromApi = false;
      }
    } finally {
      if (generation != _loadGeneration) {
        return;
      }
      if (!silent) {
        _isLoading = false;
      }
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
        startDate: DateTime(
          now.add(const Duration(days: 2)).year,
          now.add(const Duration(days: 2)).month,
          now.add(const Duration(days: 2)).day,
          17,
        ),
        type: EventType.school,
        childId: 'child_001',
        createdBy: 'user_001',
        location: 'ul. Mokotowska 12',
        description: 'Zajęcia o 17:00',
      ),
      CalendarEvent(
        id: 'evt_001b',
        title: 'Piłka nożna',
        startDate: DateTime(
          now.add(const Duration(days: 2)).year,
          now.add(const Duration(days: 2)).month,
          now.add(const Duration(days: 2)).day,
          18,
          30,
        ),
        type: EventType.activity,
        childId: 'child_001',
        createdBy: 'user_002',
      ),
      CalendarEvent(
        id: 'evt_001c',
        title: 'Korepetycje matma',
        startDate: DateTime(
          now.add(const Duration(days: 2)).year,
          now.add(const Duration(days: 2)).month,
          now.add(const Duration(days: 2)).day,
          19,
        ),
        type: EventType.school,
        childId: 'child_001',
        createdBy: 'user_001',
      ),
      CalendarEvent(
        id: 'evt_001d',
        title: 'Kino',
        startDate: DateTime(
          now.add(const Duration(days: 2)).year,
          now.add(const Duration(days: 2)).month,
          now.add(const Duration(days: 2)).day,
          20,
        ),
        type: EventType.other,
        childId: 'child_001',
        createdBy: 'user_001',
      ),
      CalendarEvent(
        id: 'evt_002',
        title: 'Dentysta – Tomek',
        startDate: DateTime(
          now.add(const Duration(days: 5)).year,
          now.add(const Duration(days: 5)).month,
          now.add(const Duration(days: 5)).day,
          10,
          30,
        ),
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
        .where((slot) => isSameCalendarDay(slot.date, date))
        .toList();
  }

  List<CalendarEvent> getEventsForDay(DateTime date) {
    return _events.where((event) {
      if (isSameCalendarDay(event.startDate, date)) {
        return true;
      }
      if (event.endDate == null) {
        return false;
      }

      final target = DateTime(date.year, date.month, date.day);
      final start = event.startDate.toLocal();
      final end = event.endDate!.toLocal();
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      return !target.isBefore(startDay) && !target.isAfter(endDay);
    }).toList();
  }

  Future<void> _reloadBestEffort() async {
    try {
      await load(silent: true);
    } catch (_) {
      // Keep optimistic/local state if refresh fails temporarily.
    }
  }

  void _upsertEvent(CalendarEvent event) {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      _events[index] = event;
    } else {
      _events.add(event);
    }
    _events.sort((a, b) => a.startDate.compareTo(b.startDate));
    notifyListeners();
  }

  void _upsertSwap(SwapRequest swap) {
    final index = _swapRequests.indexWhere((item) => item.id == swap.id);
    if (index >= 0) {
      _swapRequests[index] = swap;
    } else {
      _swapRequests.insert(0, swap);
    }
    notifyListeners();
  }

  void _applyAcceptedSwapToSlots(SwapRequest swap) {
    final originalIndex = _custodySlots.indexWhere(
      (slot) => isSameCalendarDay(slot.date, swap.originalDate),
    );
    final proposedIndex = _custodySlots.indexWhere(
      (slot) => isSameCalendarDay(slot.date, swap.proposedDate),
    );
    if (originalIndex < 0 || proposedIndex < 0) {
      return;
    }

    final originalSlot = _custodySlots[originalIndex];
    final proposedSlot = _custodySlots[proposedIndex];
    final originalCustodian = originalSlot.custodian;
    final proposedCustodian = proposedSlot.custodian;

    _custodySlots[originalIndex] = CustodySlot(
      id: originalSlot.id,
      date: originalSlot.date,
      custodian: proposedCustodian,
      handoverLocation: originalSlot.handoverLocation,
      handoverTime: originalSlot.handoverTime,
    );
    _custodySlots[proposedIndex] = CustodySlot(
      id: proposedSlot.id,
      date: proposedSlot.date,
      custodian: originalCustodian,
      handoverLocation: proposedSlot.handoverLocation,
      handoverTime: proposedSlot.handoverTime,
    );
    notifyListeners();
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
      _upsertSwap(updated);
      if (status == SwapStatus.accepted) {
        _applyAcceptedSwapToSlots(updated);
      }
      await _reloadBestEffort();
      if (status == SwapStatus.accepted) {
        _applyAcceptedSwapToSlots(updated);
      }
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void addLocalEvent({
    required String title,
    required DateTime startDate,
    required EventType type,
    required String createdBy,
    String? description,
    DateTime? endDate,
    String? childId,
    String? location,
  }) {
    final day = calendarDayFrom(startDate);
    _upsertEvent(
      CalendarEvent(
        id: 'local_evt_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: description,
        startDate: day,
        endDate: endDate == null ? null : calendarDayFrom(endDate),
        type: type,
        childId: childId,
        createdBy: createdBy,
        location: location,
      ),
    );
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
      final day = calendarDayFrom(startDate);
      final created = await _repository.createEvent(
        title: title,
        startDate: day,
        type: type,
        description: description,
        endDate: endDate == null ? null : calendarDayFrom(endDate),
        childId: childId,
        location: location,
      );
      _upsertEvent(created);
      await _reloadBestEffort();
      // Keep the saved event visible if an older refresh finishes last.
      _upsertEvent(created);
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
      _upsertSwap(created);
      await _reloadBestEffort();
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
