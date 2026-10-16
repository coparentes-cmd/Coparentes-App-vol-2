import 'package:flutter/foundation.dart';

import '../../config/app_environment.dart';
import '../../models/models.dart';
import 'clarity_bridge.dart';
import 'ga_bridge.dart';

/// Product analytics (GA4 + Clarity). Enabled only after ANALYTICS consent on web.
class AnalyticsService {
  AnalyticsService({
    GaBridge? bridge,
    ClarityBridge? clarityBridge,
    String? measurementId,
    String? clarityProjectId,
    bool? isWeb,
  })  : _bridge = bridge ?? GaBridge(),
        _clarity = clarityBridge ?? ClarityBridge(),
        _measurementId = measurementId ?? AppEnvironment.gaMeasurementId,
        _clarityProjectId =
            clarityProjectId ?? AppEnvironment.clarityProjectId,
        _isWeb = isWeb ?? kIsWeb;

  static AnalyticsService instance = AnalyticsService();

  final GaBridge _bridge;
  final ClarityBridge _clarity;
  final String _measurementId;
  final String _clarityProjectId;
  final bool _isWeb;

  bool _enabled = false;
  String? _lastScreen;

  bool get isEnabled => _enabled;

  String get measurementId => _measurementId;

  String get clarityProjectId => _clarityProjectId;

  /// Call after consents are known (login / settings / registration).
  Future<void> syncFromUserState({
    required bool analyticsConsentGranted,
    required UserRole? role,
    required bool isDemoMode,
  }) async {
    final allowedRole = role != null && role != UserRole.child;
    final hasVendor = _measurementId.isNotEmpty || _clarityProjectId.isNotEmpty;
    final shouldEnable = analyticsConsentGranted &&
        allowedRole &&
        !isDemoMode &&
        _isWeb &&
        hasVendor;

    if (shouldEnable) {
      await enable();
    } else {
      await disable();
    }
  }

  Future<void> enable() async {
    if (!_isWeb) {
      _enabled = false;
      return;
    }
    if (_measurementId.isEmpty && _clarityProjectId.isEmpty) {
      _enabled = false;
      return;
    }
    try {
      if (_measurementId.isNotEmpty) {
        await _bridge.ensureLoaded(_measurementId);
        _bridge.setAnalyticsConsent(true);
        _bridge.config(_measurementId);
      }
      if (_clarityProjectId.isNotEmpty) {
        await _clarity.ensureLoaded(_clarityProjectId);
      }
      final wasEnabled = _enabled;
      _enabled = true;
      if (!wasEnabled && _measurementId.isNotEmpty) {
        _bridge.event('consent_analytics_granted');
      }
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> disable() async {
    if (_enabled || _bridge.isLoaded || _clarity.isLoaded) {
      try {
        if (_bridge.isLoaded) {
          _bridge.setAnalyticsConsent(false);
        }
      } catch (_) {
        // Ignore JS errors when tearing down.
      }
      try {
        _clarity.stop();
      } catch (_) {
        // Ignore JS errors when tearing down.
      }
    }
    _enabled = false;
    _lastScreen = null;
  }

  void logScreen(String name) {
    final cleaned = name.trim();
    if (!_enabled || cleaned.isEmpty || cleaned == _lastScreen) {
      return;
    }
    _lastScreen = cleaned;
    final path = cleaned.startsWith('/') ? cleaned : '/$cleaned';
    _bridge.pageView(pagePath: path, pageTitle: cleaned);
  }

  void logEvent(String name, [Map<String, Object>? params]) {
    if (!_enabled) {
      return;
    }
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      return;
    }
    // Never forward free-text / PII-looking keys.
    final safe = <String, Object>{};
    if (params != null) {
      for (final entry in params.entries) {
        final key = entry.key;
        if (key == 'email' ||
            key == 'password' ||
            key == 'content' ||
            key == 'message' ||
            key == 'name') {
          continue;
        }
        safe[key] = entry.value;
      }
    }
    _bridge.event(cleaned, safe.isEmpty ? null : safe);
  }

  @visibleForTesting
  static void debugResetInstance(AnalyticsService service) {
    instance = service;
  }
}
