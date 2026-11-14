import 'push_token_source_stub.dart'
    if (dart.library.io) 'push_token_source_io.dart' as impl;

abstract class PushTokenSource {
  Future<void> ensureInitialized();
  Future<String?> getToken();
}

PushTokenSource createPushTokenSource() => impl.createPushTokenSource();
