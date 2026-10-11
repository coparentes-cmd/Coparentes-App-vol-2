import 'package:coparentes/models/models.dart';
import 'package:coparentes/services/analytics/analytics_service.dart';
import 'package:coparentes/services/analytics/ga_bridge_stub.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBridge extends GaBridge {
  final List<String> events = <String>[];
  final List<String> pages = <String>[];
  final List<Map<String, Object>?> eventParams = <Map<String, Object>?>[];
  bool? lastConsent;
  int configCount = 0;
  int loadCount = 0;

  @override
  bool get isLoaded => loadCount > 0;

  @override
  Future<void> ensureLoaded(String measurementId) async {
    loadCount += 1;
  }

  @override
  void setAnalyticsConsent(bool granted) {
    lastConsent = granted;
  }

  @override
  void config(String measurementId) {
    configCount += 1;
  }

  @override
  void event(String name, [Map<String, Object>? params]) {
    events.add(name);
    eventParams.add(params);
  }

  @override
  void pageView({required String pagePath, String? pageTitle}) {
    pages.add(pagePath);
  }
}

void main() {
  test('stays disabled without analytics consent', () async {
    final bridge = _RecordingBridge();
    final analytics = AnalyticsService(
      bridge: bridge,
      measurementId: 'G-TEST',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: false,
      role: UserRole.parentA,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isFalse);
    analytics.logEvent('login');
    analytics.logScreen('home');
    expect(bridge.events, isEmpty);
    expect(bridge.pages, isEmpty);
  });

  test('disables for child role even with consent', () async {
    final bridge = _RecordingBridge();
    final analytics = AnalyticsService(
      bridge: bridge,
      measurementId: 'G-TEST',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.child,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isFalse);
    expect(bridge.loadCount, 0);
  });

  test('disables in demo mode', () async {
    final bridge = _RecordingBridge();
    final analytics = AnalyticsService(
      bridge: bridge,
      measurementId: 'G-TEST',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: true,
    );

    expect(analytics.isEnabled, isFalse);
  });

  test('enables for parent with consent and logs screens/events', () async {
    final bridge = _RecordingBridge();
    final analytics = AnalyticsService(
      bridge: bridge,
      measurementId: 'G-TEST',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isTrue);
    expect(bridge.lastConsent, isTrue);
    expect(bridge.configCount, 1);
    expect(bridge.events, contains('consent_analytics_granted'));

    analytics.logScreen('home_parent');
    analytics.logScreen('home_parent'); // dedupe
    analytics.logEvent('login', {
      'email': 'secret@example.com',
      'method': 'password',
    });

    expect(bridge.pages, ['/home_parent']);
    expect(bridge.events, contains('login'));
    final loginParams = bridge.eventParams[bridge.events.indexOf('login')];
    expect(loginParams, isNotNull);
    expect(loginParams!.containsKey('email'), isFalse);
    expect(loginParams['method'], 'password');
  });

  test('disable revokes analytics consent', () async {
    final bridge = _RecordingBridge();
    final analytics = AnalyticsService(
      bridge: bridge,
      measurementId: 'G-TEST',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentB,
      isDemoMode: false,
    );
    await analytics.disable();

    expect(analytics.isEnabled, isFalse);
    expect(bridge.lastConsent, isFalse);
    analytics.logEvent('login');
    expect(bridge.events.where((e) => e == 'login'), isEmpty);
  });
}
