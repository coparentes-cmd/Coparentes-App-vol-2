import '../../models/models.dart';
import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../models/calendar_snapshot.dart';
import '../serializers/calendar_serializers.dart';

class CalendarRepository {
  final AppApiClient _apiClient;
  final OfflineStore _offlineStore;

  CalendarRepository({
    required AppApiClient apiClient,
    required OfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<CalendarSnapshot> fetchCalendar() async {
    await syncPendingActions();

    try {
      final payload = await _apiClient.getJson('/calendar');
      final snapshot = _snapshotFromPayload(payload);
      await _saveSnapshot(snapshot);
      return snapshot;
    } catch (error) {
      final cached = _getCachedSnapshot();
      if (!cached.isEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startDate,
    required EventType type,
    String? description,
    DateTime? endDate,
    String? childId,
    String? location,
  }) async {
    try {
      final payload = await _apiClient.postJson('/calendar/events', {
        'title': title,
        'startDate': startDate.toIso8601String(),
        'type': eventTypeToApi(type),
        if (description != null) 'description': description,
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (childId != null) 'childId': childId,
        if (location != null) 'location': location,
      });
      final event = calendarEventFromJson(payload);
      await _upsertEventInCache(event);
      return event;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final local = CalendarEvent(
        id: 'local_evt_${now.microsecondsSinceEpoch}',
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        type: type,
        childId: childId,
        createdBy: 'pending',
        location: location,
      );
      await _upsertEventInCache(local);
      await _offlineStore.appendPendingAction({
        'type': 'calendar.createEvent',
        'createdAt': now.toIso8601String(),
        'payload': {
          'clientEventId': local.id,
          'title': title,
          'description': description,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
          'type': eventTypeToApi(type),
          'childId': childId,
          'location': location,
        },
      });
      return local;
    }
  }

  Future<SwapRequest> createSwapRequest({
    required DateTime originalDate,
    required DateTime proposedDate,
    String? reason,
  }) async {
    try {
      final payload = await _apiClient.postJson('/calendar/swaps', {
        'originalDate': originalDate.toIso8601String(),
        'proposedDate': proposedDate.toIso8601String(),
        if (reason != null) 'reason': reason,
      });
      final swap = swapRequestFromJson(payload);
      await _upsertSwapInCache(swap);
      return swap;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final local = SwapRequest(
        id: 'local_swap_${now.microsecondsSinceEpoch}',
        requesterId: 'pending',
        requesterName: 'Ja',
        originalDate: originalDate,
        proposedDate: proposedDate,
        reason: reason,
        status: SwapStatus.pending,
        createdAt: now,
      );
      await _upsertSwapInCache(local);
      await _offlineStore.appendPendingAction({
        'type': 'calendar.createSwap',
        'createdAt': now.toIso8601String(),
        'payload': {
          'clientSwapId': local.id,
          'originalDate': originalDate.toIso8601String(),
          'proposedDate': proposedDate.toIso8601String(),
          'reason': reason,
        },
      });
      return local;
    }
  }

  Future<SwapRequest> respondToSwap({
    required String swapId,
    required SwapStatus status,
    String? responseNote,
  }) async {
    try {
      final payload = await _apiClient.postJson('/calendar/swaps/$swapId/respond', {
        'status': swapStatusToApi(status),
        if (responseNote != null) 'responseNote': responseNote,
      });
      final swap = swapRequestFromJson(payload);
      await _upsertSwapInCache(swap);
      return swap;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final cached = _getCachedSnapshot();
      final index = cached.swapRequests.indexWhere((s) => s.id == swapId);
      if (index < 0) {
        rethrow;
      }

      final existing = cached.swapRequests[index];
      final optimistic = SwapRequest(
        id: existing.id,
        requesterId: existing.requesterId,
        requesterName: existing.requesterName,
        originalDate: existing.originalDate,
        proposedDate: existing.proposedDate,
        reason: existing.reason,
        status: status,
        createdAt: existing.createdAt,
        responseNote: responseNote,
      );
      cached.swapRequests[index] = optimistic;
      await _saveSnapshot(cached);

      await _offlineStore.appendPendingAction({
        'type': 'calendar.respondToSwap',
        'createdAt': DateTime.now().toIso8601String(),
        'payload': {
          'swapId': swapId,
          'status': swapStatusToApi(status),
          'responseNote': responseNote,
        },
      });
      return optimistic;
    }
  }

  Future<void> syncPendingActions() async {
    final actions = _offlineStore.getPendingActions();
    if (actions.isEmpty) {
      return;
    }

    var snapshot = _getCachedSnapshot();
    final rewrittenQueue = <Map<String, dynamic>>[];
    var networkFailed = false;

    for (final action in actions) {
      final type = action['type'] as String? ?? '';
      if (!type.startsWith('calendar.')) {
        rewrittenQueue.add(action);
        continue;
      }

      if (networkFailed) {
        rewrittenQueue.add(action);
        continue;
      }

      try {
        switch (type) {
          case 'calendar.createEvent':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _apiClient.postJson('/calendar/events', {
              'title': payload['title'],
              'startDate': payload['startDate'],
              'type': payload['type'],
              if (payload['description'] != null) 'description': payload['description'],
              if (payload['endDate'] != null) 'endDate': payload['endDate'],
              if (payload['childId'] != null) 'childId': payload['childId'],
              if (payload['location'] != null) 'location': payload['location'],
            });
            final event = calendarEventFromJson(response);
            final clientId = payload['clientEventId'] as String;
            _replaceEventId(snapshot, clientId, event);
            break;
          case 'calendar.createSwap':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _apiClient.postJson('/calendar/swaps', {
              'originalDate': payload['originalDate'],
              'proposedDate': payload['proposedDate'],
              if (payload['reason'] != null) 'reason': payload['reason'],
            });
            final swap = swapRequestFromJson(response);
            final clientId = payload['clientSwapId'] as String;
            _replaceSwapId(snapshot, clientId, swap);
            break;
          case 'calendar.respondToSwap':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _apiClient.postJson(
              '/calendar/swaps/${payload['swapId']}/respond',
              {
                'status': payload['status'],
                if (payload['responseNote'] != null)
                  'responseNote': payload['responseNote'],
              },
            );
            final swap = swapRequestFromJson(response);
            final index =
                snapshot.swapRequests.indexWhere((s) => s.id == swap.id);
            if (index >= 0) {
              snapshot.swapRequests[index] = swap;
            }
            break;
          default:
            rewrittenQueue.add(action);
        }
      } on ApiException catch (error) {
        if (error.statusCode >= 500) {
          rethrow;
        }
      } catch (_) {
        networkFailed = true;
        rewrittenQueue.add(action);
      }
    }

    await _saveSnapshot(snapshot);
    await _offlineStore.savePendingActions(rewrittenQueue);
  }

  CalendarSnapshot _snapshotFromPayload(Map<String, dynamic> payload) {
    final slots = (payload['custodySlots'] as List<dynamic>? ?? [])
        .map((item) => custodySlotFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final events = (payload['events'] as List<dynamic>? ?? [])
        .map((item) => calendarEventFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final swaps = (payload['swapRequests'] as List<dynamic>? ?? [])
        .map((item) => swapRequestFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    return CalendarSnapshot(
      custodySlots: slots,
      events: events,
      swapRequests: swaps,
    );
  }

  CalendarSnapshot _getCachedSnapshot() {
    final raw = _offlineStore.getCalendarSnapshot();
    if (raw == null) {
      return const CalendarSnapshot(
        custodySlots: [],
        events: [],
        swapRequests: [],
      );
    }
    return _snapshotFromPayload(raw);
  }

  Future<void> _saveSnapshot(CalendarSnapshot snapshot) {
    return _offlineStore.saveCalendarSnapshot({
      'custodySlots': snapshot.custodySlots.map(custodySlotToJson).toList(),
      'events': snapshot.events.map(calendarEventToJson).toList(),
      'swapRequests': snapshot.swapRequests.map(swapRequestToJson).toList(),
    });
  }

  Future<void> _upsertSwapInCache(SwapRequest swap) async {
    final snapshot = _getCachedSnapshot();
    final index = snapshot.swapRequests.indexWhere((s) => s.id == swap.id);
    if (index >= 0) {
      snapshot.swapRequests[index] = swap;
    } else {
      snapshot.swapRequests.insert(0, swap);
    }
    await _saveSnapshot(snapshot);
  }

  Future<void> _upsertEventInCache(CalendarEvent event) async {
    final snapshot = _getCachedSnapshot();
    final index = snapshot.events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      snapshot.events[index] = event;
    } else {
      snapshot.events.insert(0, event);
    }
    snapshot.events.sort((a, b) => a.startDate.compareTo(b.startDate));
    await _saveSnapshot(snapshot);
  }

  void _replaceEventId(
    CalendarSnapshot snapshot,
    String oldId,
    CalendarEvent replacement,
  ) {
    final index = snapshot.events.indexWhere((e) => e.id == oldId);
    if (index >= 0) {
      snapshot.events[index] = replacement;
    } else {
      snapshot.events.insert(0, replacement);
    }
  }

  void _replaceSwapId(
    CalendarSnapshot snapshot,
    String oldId,
    SwapRequest replacement,
  ) {
    final index = snapshot.swapRequests.indexWhere((s) => s.id == oldId);
    if (index >= 0) {
      snapshot.swapRequests[index] = replacement;
    } else {
      snapshot.swapRequests.insert(0, replacement);
    }
  }
}
