import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api/app_api_client.dart';
import '../data/local/offline_store.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/documents_repository.dart';
import '../data/repositories/export_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/messaging_repository.dart';

class OfflineSyncProvider extends ChangeNotifier {
  final AppApiClient _apiClient;
  final MessagingRepository _messagingRepository;
  final ExportRepository _exportRepository;
  final CalendarRepository _calendarRepository;
  final FinanceRepository _financeRepository;
  final DocumentsRepository _documentsRepository;
  final OfflineStore _offlineStore;
  final Future<void> Function()? _refreshMessaging;
  final Future<void> Function()? _refreshData;

  Timer? _messagingTimer;
  Timer? _fullRefreshTimer;
  bool _isOnline = true;
  bool _isPollingMessaging = false;
  static const _messagingPollInterval = Duration(seconds: 3);
  static const _fullRefreshInterval = Duration(seconds: 30);
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastSyncError;

  OfflineSyncProvider({
    required AppApiClient apiClient,
    required MessagingRepository messagingRepository,
    required ExportRepository exportRepository,
    required CalendarRepository calendarRepository,
    required FinanceRepository financeRepository,
    required DocumentsRepository documentsRepository,
    required OfflineStore offlineStore,
    Future<void> Function()? refreshMessaging,
    Future<void> Function()? refreshData,
  })  : _apiClient = apiClient,
        _messagingRepository = messagingRepository,
        _exportRepository = exportRepository,
        _calendarRepository = calendarRepository,
        _financeRepository = financeRepository,
        _documentsRepository = documentsRepository,
        _offlineStore = offlineStore,
        _refreshMessaging = refreshMessaging,
        _refreshData = refreshData {
    _offlineStore.addListener(_handleStoreChanged);
    unawaited(initialize());
  }

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncError => _lastSyncError;
  bool get showBanner =>
      !_isOnline || _isSyncing || _pendingCount > 0 || _lastSyncError != null;

  String get statusLabel {
    if (_isSyncing) {
      return 'Synchronizacja danych offline…';
    }
    if (!_isOnline) {
      return _pendingCount > 0
          ? 'Tryb offline • $_pendingCount zmian czeka na synchronizację'
          : 'Tryb offline • ostatnie dane zapisane lokalnie';
    }
    if (_lastSyncError != null) {
      return _pendingCount > 0
          ? 'Online • błąd synchronizacji, $_pendingCount zmian nadal czeka'
          : 'Online • ostatnia synchronizacja wymaga sprawdzenia';
    }
    if (_pendingCount > 0) {
      return 'Online • $_pendingCount zmian czeka na wysłanie';
    }
    return 'Online';
  }

  Future<void> initialize() async {
    await _refreshPendingCount();
    _isOnline = await _apiClient.pingHealth();
    notifyListeners();

    if (_isOnline && _pendingCount > 0) {
      await syncNow();
    } else {
      await pollMessagingNow();
    }

    _messagingTimer?.cancel();
    _messagingTimer = Timer.periodic(
      _messagingPollInterval,
      (_) => unawaited(pollMessagingNow()),
    );

    _fullRefreshTimer?.cancel();
    _fullRefreshTimer = Timer.periodic(
      _fullRefreshInterval,
      (_) => unawaited(refreshStatus()),
    );
  }

  Future<void> pollMessagingNow() async {
    if (_isPollingMessaging || _refreshMessaging == null) {
      return;
    }

    _isPollingMessaging = true;
    try {
      await _refreshMessaging!.call();
      _isOnline = true;
      _lastSyncError = null;
    } catch (_) {
      _isOnline = false;
    } finally {
      _isPollingMessaging = false;
    }
  }

  Future<void> refreshStatus() async {
    final previousOnline = _isOnline;
    final previousPendingCount = _pendingCount;
    final online = await _apiClient.pingHealth();
    _isOnline = online;
    await _refreshPendingCount();

    if (_isOnline && _pendingCount > 0) {
      await syncNow();
      return;
    }

    if (_isOnline && _refreshData != null) {
      try {
        await _refreshData!.call();
        await pollMessagingNow();
      } catch (_) {
        // Keep polling on transient API errors.
      }
    }

    if (previousOnline != _isOnline || previousPendingCount != _pendingCount) {
      notifyListeners();
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      _lastSyncError = null;
      await _messagingRepository.syncPendingActions();
      await _exportRepository.syncPendingActions();
      await _calendarRepository.syncPendingActions();
      await _financeRepository.syncPendingActions();
      await _documentsRepository.syncPendingActions();
      _isOnline = await _apiClient.pingHealth();
      await _refreshPendingCount();
      if (_isOnline && _refreshData != null) {
        await _refreshData!.call();
      }
      await pollMessagingNow();
    } catch (error) {
      _lastSyncError = error.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = _offlineStore.pendingActionCount();
  }

  void _handleStoreChanged() {
    unawaited(_syncPendingCountFromStore());
  }

  Future<void> _syncPendingCountFromStore() async {
    await _refreshPendingCount();
    notifyListeners();
  }

  @override
  void dispose() {
    _messagingTimer?.cancel();
    _fullRefreshTimer?.cancel();
    _offlineStore.removeListener(_handleStoreChanged);
    super.dispose();
  }
}
