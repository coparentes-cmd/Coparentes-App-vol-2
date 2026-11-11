import 'package:coparentes/services/cookie_consent/cookie_consent_controller.dart';
import 'package:coparentes/services/cookie_consent/cookie_consent_models.dart';
import 'package:coparentes/services/cookie_consent/cookie_consent_storage_stub.dart';
import 'package:coparentes/services/analytics/analytics_service.dart';
import 'package:coparentes/services/analytics/clarity_bridge_stub.dart';
import 'package:coparentes/services/analytics/ga_bridge_stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AnalyticsService _analytics() {
    return AnalyticsService(
      bridge: GaBridge(),
      clarityBridge: ClarityBridge(),
      measurementId: '',
      clarityProjectId: 'claritytest1',
      isWeb: true,
    );
  }

  test('first visit shows collapsed banner', () async {
    final controller = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await controller.initialize();

    expect(controller.ready, isTrue);
    expect(controller.bannerVisible, isTrue);
    expect(controller.settingsExpanded, isFalse);
    expect(controller.consent, isNull);
  });

  test('accept all stores consent and hides banner', () async {
    final controller = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await controller.initialize();
    await controller.acceptAll();

    expect(controller.bannerVisible, isFalse);
    expect(controller.consent?.analytics, isTrue);
    expect(controller.consent?.marketing, isTrue);
    expect(controller.consent?.functional, isTrue);

    final stored = await CookieConsentStorage().load();
    expect(stored?.analytics, isTrue);
    expect(stored?.consentVersion, CookieConsent.version);
  });

  test('reject optional keeps only necessary', () async {
    final controller = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await controller.initialize();
    await controller.rejectOptional();

    expect(controller.bannerVisible, isFalse);
    expect(controller.consent?.necessary, isTrue);
    expect(controller.consent?.analytics, isFalse);
    expect(controller.consent?.marketing, isFalse);
    expect(controller.consent?.functional, isFalse);
  });

  test('reload keeps banner hidden when consent exists', () async {
    final first = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await first.initialize();
    await first.acceptAll();

    final second = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await second.initialize();

    expect(second.bannerVisible, isFalse);
    expect(second.consent?.analytics, isTrue);
  });

  test('openSettings expands details', () async {
    final controller = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await controller.initialize();
    await controller.rejectOptional();
    controller.openSettings();

    expect(controller.bannerVisible, isTrue);
    expect(controller.settingsExpanded, isTrue);
    expect(controller.draftAnalytics, isFalse);
  });

  test('saveSelection persists draft toggles', () async {
    final controller = CookieConsentController(
      storage: CookieConsentStorage(),
      analytics: _analytics(),
    );
    await controller.initialize();
    controller.expandSettings();
    controller.setDraftAnalytics(true);
    controller.setDraftFunctional(true);
    controller.setDraftMarketing(false);
    await controller.saveSelection();

    expect(controller.bannerVisible, isFalse);
    expect(controller.consent?.analytics, isTrue);
    expect(controller.consent?.functional, isTrue);
    expect(controller.consent?.marketing, isFalse);
  });
}
