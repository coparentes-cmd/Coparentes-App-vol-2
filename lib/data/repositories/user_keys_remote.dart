import '../api/app_api_client.dart';

/// Thin HTTP layer for E2E public-key endpoints (`/user/...`).
class UserKeysRemote {
  UserKeysRemote({required AppApiClient apiClient}) : _apiClient = apiClient;

  final AppApiClient _apiClient;

  bool isNetworkError(Object error) => _apiClient.isNetworkError(error);

  /// GET `/user/:userId/public-key`.
  ///
  /// Returns the base64 public key, or `null` when the user has not uploaded
  /// one yet (`{ "publicKey": null }`).
  Future<String?> fetchPublicKey(String userId) async {
    final payload = await _apiClient.getJson('/user/$userId/public-key');
    final value = payload['publicKey'] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
