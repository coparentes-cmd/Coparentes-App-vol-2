import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';
import 'cookie_consent_models.dart';
import 'cookie_consent_storage.dart';

/// Landing-compatible cookie banner state + Clarity gate.
class CookieConsentController extends ChangeNotifier {
  CookieConsentController({
    CookieConsentStorage? storage,
    AnalyticsService? analytics,
  })  : _storage = storage ?? CookieConsentStorage(),
        _analytics = analytics ?? AnalyticsService.instance;

  final CookieConsentStorage _storage;
  final AnalyticsService _analytics;

  CookieConsent? _consent;
  bool _ready = false;
  bool _bannerVisible = false;
  bool _settingsExpanded = false;
  bool _draftFunctional = false;
  bool _draftAnalytics = false;
  bool _draftMarketing = false;

  bool get ready => _ready;
  bool get bannerVisible => _bannerVisible;
  bool get settingsExpanded => _settingsExpanded;
  CookieConsent? get consent => _consent;
  bool get analyticsGranted => _consent?.analytics == true;
  bool get draftFunctional => _draftFunctional;
  bool get draftAnalytics => _draftAnalytics;
  bool get draftMarketing => _draftMarketing;

  Future<void> initialize() async {
    final stored = await _storage.load();
    _consent = stored;
    _ready = true;
    if (stored == null) {
      final defaults = CookieConsent.defaults();
      _syncDraftFrom(defaults);
      _bannerVisible = true;
      _settingsExpanded = false;
    } else {
      _syncDraftFrom(stored);
      _bannerVisible = false;
      _settingsExpanded = false;
      _storage.applyDocumentDataset(stored);
      await _analytics.syncCookieAnalytics(stored.analytics);
    }
    notifyListeners();
  }

  void openSettings() {
    final base = _consent ?? CookieConsent.defaults();
    _syncDraftFrom(base);
    _bannerVisible = true;
    _settingsExpanded = true;
    notifyListeners();
  }

  void expandSettings() {
    final base = _consent ?? CookieConsent.defaults();
    _syncDraftFrom(base);
    _settingsExpanded = true;
    notifyListeners();
  }

  void setDraftFunctional(bool value) {
    _draftFunctional = value;
    notifyListeners();
  }

  void setDraftAnalytics(bool value) {
    _draftAnalytics = value;
    notifyListeners();
  }

  void setDraftMarketing(bool value) {
    _draftMarketing = value;
    notifyListeners();
  }

  Future<void> acceptAll() => _persist(CookieConsent.acceptAll());

  Future<void> rejectOptional() => _persist(CookieConsent.rejectOptional());

  Future<void> saveSelection() => _persist(
        CookieConsent(
          necessary: true,
          functional: _draftFunctional,
          analytics: _draftAnalytics,
          marketing: _draftMarketing,
          savedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );

  Future<void> _persist(CookieConsent next) async {
    await _storage.save(next);
    _consent = next;
    _syncDraftFrom(next);
    _bannerVisible = false;
    _settingsExpanded = false;
    _storage.applyDocumentDataset(next);
    _storage.dispatchUpdatedEvent(next);
    await _analytics.syncCookieAnalytics(next.analytics);
    notifyListeners();
  }

  void _syncDraftFrom(CookieConsent value) {
    _draftFunctional = value.functional;
    _draftAnalytics = value.analytics;
    _draftMarketing = value.marketing;
  }
}
