import 'package:flutter/foundation.dart';

import '../../data/api/app_api_client.dart';
import 'push_token_source.dart';

/// Registers / clears FCM device tokens with the backend.
/// No-op on web so Netlify builds never touch Firebase messaging.
class PushRegistrationService {
  PushRegistrationService({
    required AppApiClient apiClient,
    PushTokenSource? tokenSource,
  })  : _apiClient = apiClient,
        _tokenSource = tokenSource ?? createPushTokenSource();

  final AppApiClient _apiClient;
  final PushTokenSource _tokenSource;
  String? _lastRegisteredToken;

  /// Call after a real (non-demo) mobile session is ready.
  Future<void> registerForCurrentUser() async {
    if (kIsWeb) {
      return;
    }
    try {
      await _tokenSource.ensureInitialized();
      final token = await _tokenSource.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await _apiClient.postJson('/user/push-token', {
        'token': token,
        'platform': platform,
      });
      _lastRegisteredToken = token;
    } catch (error, stack) {
      debugPrint('[push] register failed: $error\n$stack');
    }
  }

  /// Call on logout (best-effort).
  Future<void> unregisterCurrentDevice() async {
    if (kIsWeb) {
      return;
    }
    final token = _lastRegisteredToken;
    _lastRegisteredToken = null;
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _apiClient.deleteJson('/user/push-token', body: {'token': token});
    } catch (error, stack) {
      debugPrint('[push] unregister failed: $error\n$stack');
    }
  }
}
