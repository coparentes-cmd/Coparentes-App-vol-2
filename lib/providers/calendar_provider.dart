import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../data/models/calendar_snapshot.dart';
import '../data/repositories/calendar_repository.dart';
import '../models/models.dart';
import '../utils/calendar_date_utils.dart';
import '../utils/custody_schedule_utils.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarRepository _repository;

  CalendarProvider({required CalendarRepository repository})
      : _repository = repository;

  final List<CustodySlot> _custodySlots = [];
  final List<CalendarEvent> _events = [];
  final List<SwapRequest> _swapRequests = [];
  CustodySchedule? _custodySchedule;
  final List<CustodyException> _custodyExceptions = [];
  List<CustodySlot> _displaySlots = [];
  bool _isLoading = false;
  String? _error;
  bool _loadedFromApi = false;
  int _loadGeneration = 0;
  int _slotsRevision = 0;

  List<CustodySlot> get custodySlots => _custodySlots;
  List<CalendarEvent> get events => _events;
  List<SwapRequest> get swapRequests => _swapRequests;
  CustodySchedule? get custodySchedule => _custodySchedule;
  List<CustodyException> get custodyExceptions => _custodyExceptions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loadedFromApi => _loadedFromApi;

  bool get isEmpty =>
      _custodySlots.isEmpty &&
      _events.isEmpty &&
      _swapRequests.isEmpty &&
      _custodySchedule == null &&
      _custodyExceptions.isEmpty;

  List<CustodyException> get pendingExceptions => _custodyExceptions
      .where((item) => item.status == CustodyExceptionStatus.pending)
      .toList();

  bool hasPendingExceptionForDay(DateTime day) {
    return pendingExceptions.any((item) => item.coversDay(day));
  }

  bool isExceptionDay(DateTime day) {
    final slot = getSlotsForDay(day);
    return slot.isNotEmpty && slot.first.source == CustodySlotSource.exception;
  }

  bool get shouldPromptScheduleSetup =>
      _custodySchedule == null && _custodySlots.isEmpty;

  bool get hasPendingScheduleApproval =>
      _custodySchedule?.status == CustodyScheduleStatus.pendingApproval;

  bool get hasActiveSchedule =>
      _custodySchedule?.status == CustodyScheduleStatus.active;

  /// Grafik zapisany (oczekujący lub aktywny) — bezpośrednie edycje są zablokowane.
  bool get hasLockedSchedule =>
      hasActiveSchedule || hasPendingScheduleApproval;

  bool canRespondToPendingSchedule(String? userId) {
    final schedule = _custodySchedule;
    if (schedule == null ||
        schedule.status != CustodyScheduleStatus.pendingApproval) {
      return false;
    }
    if (userId == null || userId == schedule.proposedById) {
      return false;
    }
    return true;
  }

  bool canRespondToException(CustodyException exception, String? userId) {
    if (exception.status != CustodyExceptionStatus.pending) {
      return false;
    }
    if (userId == null || userId == exception.requesterId) {
      return false;
    }
    return true;
  }

  int get pendingRequestCount =>
      swapRequests.where((item) => item.status == SwapStatus.pending).length +
      pendingExceptions.length +
      (hasPendingScheduleApproval ? 1 : 0);

  CustodySlot? getNextHandover({DateTime? after}) {
    final primary =
        _displaySlots.isNotEmpty ? _displaySlots : _custodySlots;
    final fromPrimary = findNextCustodyHandover(
      slots: primary,
      schedule: _custodySchedule,
      after: after,
    );
    if (fromPrimary != null) {
      return fromPrimary;
    }

    final schedule = _custodySchedule;
    if (schedule == null) {
      return null;
    }
    if (schedule.status != CustodyScheduleStatus.active) {
      return null;
    }

    // API may return sparse custody slots without transitions; derive from grafik.
    return findNextCustodyHandover(
      slots: generateSlotsFromSchedule(schedule),
      schedule: schedule,
      after: after,
    );
  }

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
    _custodySchedule = null;
    _custodyExceptions.clear();
    _loadedFromApi = false;
    _error = null;

    _seedDemoCustodySlots();

    final now = DateTime.now();

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

    _rebuildDisplaySlots();
    notifyListeners();
  }

  /// Dodaje wydarzenie na dziś — wyłącznie w testach widget.
  @visibleForTesting
  void seedTodayTestEvent({
    required String title,
    String? childId,
  }) {
    final now = DateTime.now();
    _events.add(
      CalendarEvent(
        id: 'test_evt_today_${title.hashCode}',
        title: title,
        startDate: DateTime(now.year, now.month, now.day, 17),
        type: EventType.school,
        childId: childId,
        createdBy: 'test',
        location: 'Szkoła SP nr 15',
      ),
    );
    notifyListeners();
  }

  void _seedDemoCustodySlots() {
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
  }

  void clear() {
    _custodySlots.clear();
    _events.clear();
    _swapRequests.clear();
    _custodySchedule = null;
    _custodyExceptions.clear();
    _error = null;
    _isLoading = false;
    _loadedFromApi = false;
    _displaySlots = [];
    notifyListeners();
  }

  /// Bumps whenever custody colors should remount the month grid.
  int get slotsRevision => _slotsRevision;

  int get displaySlotCount => _displaySlots.length;

  List<CustodySlot> getSlotsForDay(DateTime date) {
    final day = normalizeScheduleDate(date);

    CustodySlot? overrideForDay() {
      for (final slot in _custodySlots) {
        if (!isSameCustodyDay(slot.date, day)) {
          continue;
        }
        if (slot.source == CustodySlotSource.exception ||
            slot.source == CustodySlotSource.swap) {
          return slot.copyWith(date: normalizeScheduleDate(slot.date));
        }
      }
      return null;
    }

    final override = overrideForDay();
    if (override != null) {
      return [override];
    }

    final matched = _displaySlots
        .where((slot) => isSameCustodyDay(slot.date, day))
        .toList();
    if (matched.isNotEmpty) {
      return matched;
    }

    // Live fallback: paint only from an approved (active) schedule.
    final schedule = _custodySchedule;
    if (schedule == null ||
        schedule.status != CustodyScheduleStatus.active) {
      return _custodySlots
          .where((slot) => isSameCustodyDay(slot.date, day))
          .toList();
    }

    final start = normalizeScheduleDate(schedule.startDate);
    if (day.isBefore(start)) {
      return const [];
    }
    if (schedule.endDate != null &&
        day.isAfter(normalizeScheduleDate(schedule.endDate!))) {
      return const [];
    }

    return [
      CustodySlot(
        id: 'live_${schedule.id}_${day.year}${day.month}${day.day}',
        date: day,
        custodian: custodianForScheduleDate(schedule, day),
        handoverLocation: schedule.handoverLocation,
        handoverTime: schedule.handoverTime,
        source: CustodySlotSource.schedule,
      ),
    ];
  }

  void _rebuildDisplaySlots() {
    final schedule = _custodySchedule;
    if (schedule == null) {
      _displaySlots = _custodySlots
          .map(
            (slot) => slot.copyWith(date: normalizeScheduleDate(slot.date)),
          )
          .toList();
      _slotsRevision++;
      return;
    }

    // Colors follow the approved schedule only — pending proposals stay
    // colorless until the other parent accepts.
    if (schedule.status == CustodyScheduleStatus.active) {
      final generated = generateSlotsFromSchedule(schedule);
      _displaySlots = mergeScheduleSlotsWithOverrides(
        generated: generated,
        overrides: _custodySlots,
      );
      _slotsRevision++;
      return;
    }

    _displaySlots = _custodySlots
        .map(
          (slot) => slot.copyWith(date: normalizeScheduleDate(slot.date)),
        )
        .toList();
    _slotsRevision++;
  }

  Future<bool> loadPersistedDemoIfAvailable() async {
    final snapshot = _repository.getCachedSnapshot();
    final schedule = snapshot.custodySchedule;
    if (schedule == null) {
      return false;
    }
    // Never reuse a production offline cache as "demo" — that left demo with
    // empty/wrong calendar while messaging showed sample threads.
    if (!schedule.id.startsWith('demo_schedule_')) {
      return false;
    }
    _applySnapshot(snapshot);
    _rebuildDisplaySlots();
    _loadedFromApi = true;
    notifyListeners();
    return true;
  }

  Future<void> _persistCurrentSnapshot() async {
    await _repository.persistSnapshot(
      CalendarSnapshot(
        custodySlots: _custodySlots,
        events: _events,
        swapRequests: _swapRequests,
        custodySchedule: _custodySchedule,
        custodyExceptions: _custodyExceptions,
      ),
    );
  }

  List<CalendarEvent> getEventsForDay(DateTime date) {
    final events = _events.where((event) {
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
    events.sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    return events;
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
    _events.sort((a, b) => compareEventTimes(a.startDate, b.startDate));
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
    final originalDay = normalizeScheduleDate(swap.originalDate);
    final proposedDay = normalizeScheduleDate(swap.proposedDate);
    final schedule = _custodySchedule;

    // Exchange the schedule custodians for these two days (idempotent).
    final originalCustodian = schedule != null
        ? custodianForScheduleDate(schedule, originalDay)
        : UserRole.parentA;
    final proposedCustodian = schedule != null
        ? custodianForScheduleDate(schedule, proposedDay)
        : UserRole.parentB;

    void upsertSwapOverride(DateTime day, UserRole custodian) {
      final index = _custodySlots.indexWhere(
        (slot) => isSameCustodyDay(slot.date, day),
      );
      final existing = index >= 0 ? _custodySlots[index] : null;
      final next = CustodySlot(
        id: existing?.id ??
            'swap_${day.year}${day.month}${day.day}_${custodian.name}',
        date: day,
        custodian: custodian,
        handoverLocation:
            existing?.handoverLocation ?? schedule?.handoverLocation,
        handoverTime: existing?.handoverTime ?? schedule?.handoverTime,
        source: CustodySlotSource.swap,
      );
      if (index >= 0) {
        _custodySlots[index] = next;
      } else {
        _custodySlots.add(next);
      }
    }

    upsertSwapOverride(originalDay, proposedCustodian);
    upsertSwapOverride(proposedDay, originalCustodian);
    _rebuildDisplaySlots();
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
        // Re-apply after reload so colors stay correct if the snapshot
        // briefly omits swap-sourced slots.
        _applyAcceptedSwapToSlots(updated);
      }
    } catch (_) {
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
    _upsertEvent(
      CalendarEvent(
        id: 'local_evt_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: description,
        startDate: _normalizeEventStart(startDate),
        endDate: endDate == null ? null : _normalizeEventStart(endDate),
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
      final normalizedStart = _normalizeEventStart(startDate);
      final created = await _repository.createEvent(
        title: title,
        startDate: normalizedStart,
        type: type,
        description: description,
        endDate: endDate == null ? null : _normalizeEventStart(endDate),
        childId: childId,
        location: location,
      );
      _upsertEvent(created);
      await _reloadBestEffort();
      // Keep the saved event visible if an older refresh finishes last.
      _upsertEvent(created);
    } catch (_) {
      rethrow;
    }
  }

  void updateLocalEvent({
    required String id,
    required String title,
    required DateTime startDate,
    required EventType type,
    String? description,
    DateTime? endDate,
    String? childId,
    String? location,
  }) {
    final index = _events.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }

    final existing = _events[index];
    _upsertEvent(
      CalendarEvent(
        id: id,
        title: title,
        description: description ?? existing.description,
        startDate: _normalizeEventStart(startDate),
        endDate: endDate == null
            ? existing.endDate
            : _normalizeEventStart(endDate),
        type: type,
        childId: childId ?? existing.childId,
        createdBy: existing.createdBy,
        location: location ?? existing.location,
      ),
    );
  }

  Future<void> updateEvent({
    required String id,
    required String title,
    required DateTime startDate,
    required EventType type,
    String? description,
    DateTime? endDate,
    String? childId,
    String? location,
  }) async {
    try {
      final normalizedStart = _normalizeEventStart(startDate);
      final updated = await _repository.updateEvent(
        id: id,
        title: title,
        startDate: normalizedStart,
        type: type,
        description: description,
        endDate: endDate == null ? null : _normalizeEventStart(endDate),
        childId: childId,
        location: location,
      );
      _upsertEvent(updated);
      await _reloadBestEffort();
      _upsertEvent(updated);
    } catch (_) {
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
    } catch (_) {
      rethrow;
    }
  }

  Future<CustodySchedule> proposeSchedule({
    required CustodySchedulePattern patternType,
    required DateTime startDate,
    DateTime? endDate,
    CustodyWeekPattern? weekA,
    CustodyWeekPattern? weekB,
    int? weekInterval,
    String? handoverTime,
    String? handoverLocation,
  }) async {
    try {
      final schedule = await _repository.proposeSchedule(
        patternType: patternType,
        startDate: startDate,
        endDate: endDate,
        weekA: weekA,
        weekB: weekB,
        weekInterval: weekInterval,
        handoverTime: handoverTime,
        handoverLocation: handoverLocation,
      );
      _custodySchedule = schedule;
      _rebuildDisplaySlots();
      notifyListeners();
      await _reloadBestEffort();
      return schedule;
    } catch (_) {
      rethrow;
    }
  }

  CustodySchedule proposeScheduleDemo({
    required String proposedById,
    required CustodySchedulePattern patternType,
    required DateTime startDate,
    DateTime? endDate,
    CustodyWeekPattern? weekA,
    CustodyWeekPattern? weekB,
    int? weekInterval,
    String? handoverTime,
    String? handoverLocation,
  }) {
    final schedule = CustodySchedule(
      id: 'demo_schedule_${DateTime.now().millisecondsSinceEpoch}',
      patternType: patternType,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endDate == null
          ? null
          : DateTime(endDate.year, endDate.month, endDate.day),
      weekA: weekA ?? const CustodyWeekPattern({}),
      weekB: weekB ?? const CustodyWeekPattern({}),
      weekInterval: weekInterval,
      handoverTime: handoverTime,
      handoverLocation: handoverLocation,
      status: CustodyScheduleStatus.pendingApproval,
      proposedById: proposedById,
      createdAt: DateTime.now(),
    );
    _custodySchedule = schedule;
    // Do not paint colors until the other parent accepts.
    _rebuildDisplaySlots();
    notifyListeners();
    unawaited(_persistCurrentSnapshot());
    return schedule;
  }

  Future<void> respondToScheduleDemo({
    required bool approve,
    String? approvedById,
  }) async {
    final schedule = _custodySchedule;
    if (schedule == null ||
        schedule.status != CustodyScheduleStatus.pendingApproval) {
      return;
    }

    if (!approve) {
      _custodySchedule = null;
      _custodySlots.clear();
      _seedDemoCustodySlots();
      _rebuildDisplaySlots();
      notifyListeners();
      await _persistCurrentSnapshot();
      return;
    }

    final active = CustodySchedule(
      id: schedule.id,
      patternType: schedule.patternType,
      startDate: schedule.startDate,
      endDate: schedule.endDate,
      weekA: schedule.weekA,
      weekB: schedule.weekB,
      weekInterval: schedule.weekInterval,
      handoverTime: schedule.handoverTime,
      handoverLocation: schedule.handoverLocation,
      status: CustodyScheduleStatus.active,
      proposedById: schedule.proposedById,
      approvedById: approvedById,
      approvedAt: DateTime.now(),
      createdAt: schedule.createdAt,
    );
    _custodySchedule = active;
    _custodySlots
      ..clear()
      ..addAll(generateSlotsFromSchedule(active));
    _rebuildDisplaySlots();
    notifyListeners();
    await _persistCurrentSnapshot();
  }

  Future<void> respondToSchedule({
    required String scheduleId,
    required bool approve,
    String? responseNote,
  }) async {
    try {
      final updated = await _repository.respondToSchedule(
        scheduleId: scheduleId,
        approve: approve,
        responseNote: responseNote,
      );

      if (!approve) {
        if (_custodySchedule?.id == scheduleId) {
          _custodySchedule = null;
        }
      } else {
        _custodySchedule = updated;
        // Paint immediately from the pattern; server slots arrive on reload.
        final generated = generateSlotsFromSchedule(updated);
        final overrides = _custodySlots
            .where(
              (slot) =>
                  slot.source == CustodySlotSource.exception ||
                  slot.source == CustodySlotSource.swap,
            )
            .toList();
        _custodySlots
          ..clear()
          ..addAll(generated)
          ..addAll(overrides);
      }
      _rebuildDisplaySlots();
      notifyListeners();
      await _persistCurrentSnapshot();
      await _reloadBestEffort();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> requestException({
    required DateTime fromDate,
    DateTime? toDate,
    required UserRole custodian,
    CustodyExceptionType? exceptionType,
    String? reason,
  }) async {
    try {
      final created = await _repository.createException(
        fromDate: fromDate,
        toDate: toDate,
        custodian: custodian,
        exceptionType: exceptionType,
        reason: reason,
      );
      _custodyExceptions.insert(0, created);
      notifyListeners();
      await _reloadBestEffort();
    } catch (_) {
      rethrow;
    }
  }

  void _applyAcceptedExceptionToSlots(CustodyException exception) {
    final from = normalizeScheduleDate(exception.fromDate);
    final to = normalizeScheduleDate(exception.toDate);
    for (var cursor = from;
        !cursor.isAfter(to);
        cursor = cursor.add(const Duration(days: 1))) {
      final day = normalizeScheduleDate(cursor);
      final index = _custodySlots.indexWhere(
        (slot) => isSameCustodyDay(slot.date, day),
      );
      final existing = index >= 0 ? _custodySlots[index] : null;
      final next = CustodySlot(
        id: existing?.id ??
            'exception_${day.year}${day.month}${day.day}_${exception.id}',
        date: day,
        custodian: exception.custodian,
        handoverLocation:
            existing?.handoverLocation ?? _custodySchedule?.handoverLocation,
        handoverTime: existing?.handoverTime ?? _custodySchedule?.handoverTime,
        source: CustodySlotSource.exception,
      );
      if (index >= 0) {
        _custodySlots[index] = next;
      } else {
        _custodySlots.add(next);
      }
    }
    _rebuildDisplaySlots();
    notifyListeners();
  }

  Future<void> respondToException({
    required String exceptionId,
    required bool approve,
    String? responseNote,
  }) async {
    try {
      final updated = await _repository.respondToException(
        exceptionId: exceptionId,
        approve: approve,
        responseNote: responseNote,
      );
      final index = _custodyExceptions.indexWhere((item) => item.id == exceptionId);
      if (index >= 0) {
        _custodyExceptions[index] = updated;
      }
      if (approve && updated.status == CustodyExceptionStatus.accepted) {
        _applyAcceptedExceptionToSlots(updated);
      } else {
        notifyListeners();
      }
      await _reloadBestEffort();
      if (approve && updated.status == CustodyExceptionStatus.accepted) {
        _applyAcceptedExceptionToSlots(updated);
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateSlotHandover({
    required String slotId,
    String? handoverTime,
    String? handoverLocation,
  }) async {
    if (hasLockedSchedule) {
      throw StateError('schedule_locked');
    }
    try {
      final updated = await _repository.updateSlotHandover(
        slotId: slotId,
        handoverTime: handoverTime,
        handoverLocation: handoverLocation,
      );
      final index = _custodySlots.indexWhere((item) => item.id == slotId);
      if (index >= 0) {
        _custodySlots[index] = updated;
      }
      notifyListeners();
      await _reloadBestEffort();
    } catch (_) {
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
    _events.sort((a, b) => compareEventTimes(a.startDate, b.startDate));
    _swapRequests
      ..clear()
      ..addAll(snapshot.swapRequests);
    _custodySchedule = snapshot.custodySchedule;
    _custodyExceptions
      ..clear()
      ..addAll(snapshot.custodyExceptions);
    _rebuildDisplaySlots();
  }

  DateTime _normalizeEventStart(DateTime startDate) {
    final local = startDate.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }
}
