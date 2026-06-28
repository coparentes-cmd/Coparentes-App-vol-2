import '../api/app_api_client.dart';
import '../models/user_consent.dart';

class ConsentRepository {
  final AppApiClient _apiClient;

  ConsentRepository({required AppApiClient apiClient}) : _apiClient = apiClient;

  Future<List<UserConsentRecord>> fetchConsents() async {
    final payload = await _apiClient.getJson('/consents');
    return (payload['consents'] as List<dynamic>)
        .map(
          (item) => UserConsentRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<UserConsentRecord> updateConsent({
    required ConsentType type,
    required bool granted,
  }) async {
    final payload = await _apiClient.patchJson(
      '/consents/${type.apiValue}',
      {'granted': granted},
    );
    return UserConsentRecord.fromJson(
      Map<String, dynamic>.from(payload['consent'] as Map),
    );
  }
}
