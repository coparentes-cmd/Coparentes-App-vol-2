import 'package:coparentes/models/models.dart';
import 'package:coparentes/services/analytics/analytics_service.dart';
import 'package:coparentes/services/analytics/clarity_bridge_stub.dart';
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

class _RecordingClarity extends ClarityBridge {
  int loadCount = 0;
  int stopCount = 0;
  String? lastProjectId;
  bool loaded = false;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> ensureLoaded(String projectId) async {
    loadCount += 1;
    lastProjectId = projectId;
    loaded = true;
  }

  @override
  void stop() {
    stopCount += 1;
    loaded = false;
  }
}

AnalyticsService _analytics({
  required _RecordingBridge bridge,
  required _RecordingClarity clarity,
  String measurementId = 'G-TEST',
  String clarityProjectId = 'claritytest1',
}) {
  return AnalyticsService(
    bridge: bridge,
    clarityBridge: clarity,
    measurementId: measurementId,
    clarityProjectId: clarityProjectId,
    isWeb: true,
  );
}

void main() {
  test('stays disabled without analytics consent', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: false,
      role: UserRole.parentA,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isFalse);
    expect(clarity.loadCount, 0);
    analytics.logEvent('login');
    analytics.logScreen('home');
    expect(bridge.events, isEmpty);
    expect(bridge.pages, isEmpty);
  });

  test('stays disabled without cookie analytics even with account consent',
      () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(false);

    expect(analytics.isEnabled, isFalse);
    expect(clarity.loadCount, 0);
  });

  test('enables Clarity on login page when cookie analytics granted', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(
      bridge: bridge,
      clarity: clarity,
      measurementId: '',
      clarityProjectId: 'yyktc3x67w',
    );

    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isTrue);
    expect(clarity.loadCount, 1);
  });

  test('disables for child role even with consent', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.child,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isFalse);
    expect(bridge.loadCount, 0);
    expect(clarity.loadCount, 0);
  });

  test('disables in demo mode', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: true,
    );
    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isFalse);
    expect(clarity.loadCount, 0);
  });

  test('enables for parent with consent and logs screens/events', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isTrue);
    expect(bridge.lastConsent, isTrue);
    expect(bridge.configCount, 1);
    expect(bridge.events, contains('consent_analytics_granted'));
    expect(clarity.loadCount, 1);
    expect(clarity.lastProjectId, 'claritytest1');

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

  test('disable revokes analytics consent and stops Clarity', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentB,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);
    await analytics.disable();

    expect(analytics.isEnabled, isFalse);
    expect(bridge.lastConsent, isFalse);
    expect(clarity.stopCount, 1);
    analytics.logEvent('login');
    expect(bridge.events.where((e) => e == 'login'), isEmpty);
  });

  test('Clarity alone can enable when GA id is empty', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(
      bridge: bridge,
      clarity: clarity,
      measurementId: '',
      clarityProjectId: 'yyktc3x67w',
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);

    expect(analytics.isEnabled, isTrue);
    expect(bridge.loadCount, 0);
    expect(clarity.loadCount, 1);
  });

  test('revoking cookie analytics stops Clarity', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );
    await analytics.syncCookieAnalytics(true);
    expect(analytics.isEnabled, isTrue);

    await analytics.syncCookieAnalytics(false);
    expect(analytics.isEnabled, isFalse);
    expect(clarity.stopCount, 1);
  });

  test('demo_enter can be logged while analytics enabled before demo disable',
      () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = _analytics(bridge: bridge, clarity: clarity);

    await analytics.syncCookieAnalytics(true);
    expect(analytics.isEnabled, isTrue);

    analytics.logEvent('demo_enter', {'role': 'parentA'});
    await analytics.disable();

    expect(bridge.events, contains('demo_enter'));
    final params = bridge.eventParams[bridge.events.indexOf('demo_enter')];
    expect(params?['role'], 'parentA');
    expect(analytics.isEnabled, isFalse);
  });
}
