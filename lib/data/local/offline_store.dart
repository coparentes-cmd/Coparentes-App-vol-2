import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_offline_codec.dart';

class OfflineStore extends ChangeNotifier {
  static const _sessionPayloadKey = 'coparentes_cached_session_payload_v1';
  static const _threadsKey = 'coparentes_cached_threads_v1';
  static const _exportsKey = 'coparentes_cached_exports_v1';
  static const _calendarKey = 'coparentes_cached_calendar_v1';
  static const _financesKey = 'coparentes_cached_finances_v1';
  static const _documentsKey = 'coparentes_cached_documents_v1';
  static const _pendingActionsKey = 'coparentes_pending_actions_v1';
  static const _exportDownloadPrefix = 'coparentes_cached_export_download_';
  static const _messagingThreadIdMapKey = 'coparentes_messaging_thread_id_map_v1';
  static const _messageTagsKey = 'coparentes_cached_message_tags_v1';
  static const _financeExpenseIdMapKey = 'coparentes_finance_expense_id_map_v1';

  final SharedPreferences _preferences;
  final SecureOfflineCodec _codec;

  OfflineStore({
    required SharedPreferences preferences,
    SecureOfflineCodec? codec,
  })  : _preferences = preferences,
        _codec = codec ?? SecureOfflineCodec();

  Future<void> initialize() => _codec.initialize();

  bool get _persistSensitiveData => !kIsWeb;

  Map<String, dynamic>? getSessionPayload() =>
      _decodeMap(_preferences.getString(_sessionPayloadKey));

  Future<void> saveSessionPayload(Map<String, dynamic> payload) async {
    await _preferences.setString(
      _sessionPayloadKey,
      jsonEncode(sanitizeSessionPayloadForCache(payload)),
    );
    notifyListeners();
  }

  Future<void> clearSessionPayload() async {
    await _preferences.remove(_sessionPayloadKey);
    notifyListeners();
  }

  List<Map<String, dynamic>> getThreads() =>
      _decodeList(_readSensitiveString(_threadsKey));

  Future<void> saveThreads(List<Map<String, dynamic>> threads) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_threadsKey, jsonEncode(threads));
    notifyListeners();
  }

  List<Map<String, dynamic>> getMessageTags() =>
      _decodeList(_readSensitiveString(_messageTagsKey));

  Future<void> saveMessageTags(List<Map<String, dynamic>> tags) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_messageTagsKey, jsonEncode(tags));
    notifyListeners();
  }

  List<Map<String, dynamic>> getExports() =>
      _decodeList(_readSensitiveString(_exportsKey));

  Future<void> saveExports(List<Map<String, dynamic>> jobs) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_exportsKey, jsonEncode(jobs));
    notifyListeners();
  }

  Map<String, dynamic>? getCalendarSnapshot() =>
      _decodeMap(_readSensitiveString(_calendarStorageKey()));

  Future<void> saveCalendarSnapshot(Map<String, dynamic> payload) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_calendarStorageKey(), jsonEncode(payload));
    notifyListeners();
  }

  String _calendarStorageKey() {
    final workspaceId = _activeWorkspaceId();
    if (workspaceId == null) {
      return _calendarKey;
    }
    return '${_calendarKey}_$workspaceId';
  }

  String? _activeWorkspaceId() {
    final session = getSessionPayload();
    final workspace = session?['workspace'];
    if (workspace is Map) {
      final id = workspace['id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> getFinancesExpenses() =>
      _decodeList(_readSensitiveString(_financesKey));

  Future<void> saveFinancesExpenses(List<Map<String, dynamic>> expenses) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_financesKey, jsonEncode(expenses));
    notifyListeners();
  }

  List<Map<String, dynamic>> getDocuments() =>
      _decodeList(_readSensitiveString(_documentsKey));

  Future<void> saveDocuments(List<Map<String, dynamic>> documents) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(_documentsKey, jsonEncode(documents));
    notifyListeners();
  }

  Map<String, dynamic>? getExportDownload(String exportId) => _decodeMap(
        _readSensitiveString('$_exportDownloadPrefix$exportId'),
      );

  Future<void> saveExportDownload(
    String exportId,
    Map<String, dynamic> payload,
  ) async {
    if (!_persistSensitiveData) {
      return;
    }
    await _writeSensitiveString(
      '$_exportDownloadPrefix$exportId',
      jsonEncode(payload),
    );
    notifyListeners();
  }

  List<Map<String, dynamic>> getPendingActions() => _decodeList(
        _preferences.getString(_pendingActionsKey),
      );

  Future<void> savePendingActions(List<Map<String, dynamic>> actions) async {
    await _preferences.setString(_pendingActionsKey, jsonEncode(actions));
    notifyListeners();
  }

  Future<void> appendPendingAction(Map<String, dynamic> action) async {
    final actions = getPendingActions()..add(action);
    await savePendingActions(actions);
  }

  Map<String, String> getMessagingThreadIdMap() {
    final raw = _decodeMap(_preferences.getString(_messagingThreadIdMapKey));
    if (raw == null) {
      return {};
    }

    return raw.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> saveMessagingThreadIdMap(Map<String, String> map) async {
    await _preferences.setString(_messagingThreadIdMapKey, jsonEncode(map));
    notifyListeners();
  }

  Map<String, String> getFinanceExpenseIdMap() {
    final raw = _decodeMap(_preferences.getString(_financeExpenseIdMapKey));
    if (raw == null) {
      return {};
    }

    return raw.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> saveFinanceExpenseIdMap(Map<String, String> map) async {
    await _preferences.setString(_financeExpenseIdMapKey, jsonEncode(map));
    notifyListeners();
  }

  int pendingActionCount() => getPendingActions().length;

  Future<void> clearSessionScopedData() async {
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith(_exportDownloadPrefix)) {
        await _preferences.remove(key);
      }
    }

    await _preferences.remove(_sessionPayloadKey);
    await _preferences.remove(_threadsKey);
    await _preferences.remove(_exportsKey);
    for (final key in _preferences.getKeys()) {
      if (key == _calendarKey || key.startsWith('${_calendarKey}_')) {
        await _preferences.remove(key);
      }
    }
    await _preferences.remove(_financesKey);
    await _preferences.remove(_documentsKey);
    await _preferences.remove(_pendingActionsKey);
    await _preferences.remove(_messagingThreadIdMapKey);
    await _preferences.remove(_messageTagsKey);
    await _preferences.remove(_financeExpenseIdMapKey);
    notifyListeners();
  }

  String? _readSensitiveString(String key) {
    final raw = _preferences.getString(key);
    return _codec.decryptString(raw) ?? raw;
  }

  Future<void> _writeSensitiveString(String key, String plaintext) async {
    final encoded = _codec.encryptString(plaintext) ?? plaintext;
    await _preferences.setString(key, encoded);
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}
