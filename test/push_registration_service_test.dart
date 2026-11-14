import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/services/push/push_registration_service.dart';
import 'package:coparentes/services/push/push_token_source_stub.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends AppApiClient {
  _FakeApiClient() : super(baseUrl: 'http://example.test/api');

  final List<String> posts = [];
  final List<String> deletes = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    posts.add(path);
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    deletes.add(path);
    return {'deleted': 1};
  }
}

void main() {
  test('web/stub source with null token does not call API', () async {
    final api = _FakeApiClient();
    final service = PushRegistrationService(
      apiClient: api,
      tokenSource: StubPushTokenSource(),
    );

    await service.registerForCurrentUser();
    await service.unregisterCurrentDevice();

    // On web kIsWeb is true in flutter test? Actually flutter test defaults to VM
    // (not web), so stub with null token must no-op without posting.
    expect(api.posts, isEmpty);
    expect(api.deletes, isEmpty);
  });

  test('mobile path registers stub token via API', () async {
    final api = _FakeApiClient();
    final service = PushRegistrationService(
      apiClient: api,
      tokenSource: StubPushTokenSource(token: 'sim-stub-ios'),
    );

    await service.registerForCurrentUser();
    expect(api.posts, ['/user/push-token']);

    await service.unregisterCurrentDevice();
    expect(api.deletes, ['/user/push-token']);
  });
}
