import 'push_token_source.dart';

/// Web / test fallback — never talks to Firebase.
class StubPushTokenSource implements PushTokenSource {
  StubPushTokenSource({this.token});

  final String? token;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<String?> getToken() async => token;
}

PushTokenSource createPushTokenSource() => StubPushTokenSource();
