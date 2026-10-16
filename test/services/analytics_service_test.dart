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

void main() {
  test('stays disabled without analytics consent', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: 'G-TEST',
      clarityProjectId: 'claritytest1',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: false,
      role: UserRole.parentA,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isFalse);
    expect(clarity.loadCount, 0);
    analytics.logEvent('login');
    analytics.logScreen('home');
    expect(bridge.events, isEmpty);
    expect(bridge.pages, isEmpty);
  });

  test('disables for child role even with consent', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: 'G-TEST',
      clarityProjectId: 'claritytest1',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.child,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isFalse);
    expect(bridge.loadCount, 0);
    expect(clarity.loadCount, 0);
  });

  test('disables in demo mode', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: 'G-TEST',
      clarityProjectId: 'claritytest1',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: true,
    );

    expect(analytics.isEnabled, isFalse);
    expect(clarity.loadCount, 0);
  });

  test('enables for parent with consent and logs screens/events', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: 'G-TEST',
      clarityProjectId: 'claritytest1',
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
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: 'G-TEST',
      clarityProjectId: 'claritytest1',
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
    expect(clarity.stopCount, 1);
    analytics.logEvent('login');
    expect(bridge.events.where((e) => e == 'login'), isEmpty);
  });

  test('Clarity alone can enable when GA id is empty', () async {
    final bridge = _RecordingBridge();
    final clarity = _RecordingClarity();
    final analytics = AnalyticsService(
      bridge: bridge,
      clarityBridge: clarity,
      measurementId: '',
      clarityProjectId: 'yyktc3x67w',
      isWeb: true,
    );

    await analytics.syncFromUserState(
      analyticsConsentGranted: true,
      role: UserRole.parentA,
      isDemoMode: false,
    );

    expect(analytics.isEnabled, isTrue);
    expect(bridge.loadCount, 0);
    expect(clarity.loadCount, 1);
    expect(clarity.lastProjectId, 'yyktc3x67w');
  });
}
