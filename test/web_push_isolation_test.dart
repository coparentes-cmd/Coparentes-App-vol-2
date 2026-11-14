import 'dart:io';

import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/services/push/push_registration_service.dart';
import 'package:coparentes/services/push/push_token_source_stub.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApiClient extends AppApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://example.test/api');

  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    calls.add('POST $path');
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add('DELETE $path');
    return {'deleted': 1};
  }
}

void main() {
  test('web stub source file never imports Firebase', () {
    final stub = File('lib/services/push/push_token_source_stub.dart');
    final io = File('lib/services/push/push_token_source_io.dart');
    final bridge = File('lib/services/push/push_token_source.dart');

    final stubText = stub.readAsStringSync();
    final bridgeText = bridge.readAsStringSync();
    final ioText = io.readAsStringSync();

    expect(stubText.contains('package:firebase'), isFalse);
    expect(RegExp(r"^import .*firebase", multiLine: true).hasMatch(stubText),
        isFalse);
    expect(bridgeText.contains('if (dart.library.io)'), isTrue);
    expect(bridgeText.contains('push_token_source_stub.dart'), isTrue);
    expect(ioText.contains('firebase_core'), isTrue);
    expect(ioText.contains('firebase_messaging'), isTrue);
  });

  test('null stub token never calls push API (web default behaviour)', () async {
    final api = _RecordingApiClient();
    final service = PushRegistrationService(
      apiClient: api,
      tokenSource: StubPushTokenSource(),
    );
    await service.registerForCurrentUser();
    await service.unregisterCurrentDevice();
    expect(api.calls, isEmpty);
  });

  test('release web bundle must not embed mobile FCM registration markers', () {
    final mainJs = File('build/web/main.dart.js');
    expect(mainJs.existsSync(), isTrue,
        reason: 'run flutter build web before this test');
    final js = mainJs.readAsStringSync();

    // Mobile-only symbols / paths that must be tree-shaken out of web.
    expect(js.contains('IoPushTokenSource'), isFalse);
    expect(js.contains('sim-stub-ios'), isFalse);
    expect(js.contains('/user/push-token'), isFalse);
    expect(js.contains('FirebaseMessaging'), isFalse);
    expect(js.contains('firebase_messaging'), isFalse);
  });
}
