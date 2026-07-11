import 'dart:convert';

import 'package:coparentes/config/messaging_categories.dart';
import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/data/serializers/api_serializers.dart';
import 'package:coparentes/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _ForbiddenChannelClient extends AppApiClient {
  _ForbiddenChannelClient()
      : super(
          baseUrl: 'http://127.0.0.1:0/api',
          httpClient: _ForbiddenHttpClient(),
        );
}

class _ForbiddenHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/threads/channel')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"error":"forbidden"}')),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error":"unexpected"}')),
      500,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

MessageThread _familyThread({required String id}) {
  return MessageThread(
    id: id,
    subject: familyCategoryChannel,
    category: familyCategoryChannel,
    audience: 'family',
    lastActivity: DateTime(2026, 6, 1),
    hasUnread: false,
    messages: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessagingRepository.getOrCreateCategoryThread', () {
    late SharedPreferences preferences;
    late OfflineStore offlineStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      offlineStore = OfflineStore(preferences: preferences);
    });

    test('returns cached Rodzina thread when API returns 403', () async {
      final family = _familyThread(id: 'thread_family_cached');
      await offlineStore.saveThreads([
        messageThreadToJson(family),
      ]);

      final repository = MessagingRepository(
        apiClient: _ForbiddenChannelClient(),
        offlineStore: offlineStore,
      );

      final thread = await repository.getOrCreateCategoryThread(
        familyCategoryChannel,
      );

      expect(thread.id, 'thread_family_cached');
      expect(thread.category, familyCategoryChannel);
    });

    test('returns cached thread without calling API when present', () async {
      final family = _familyThread(id: 'thread_family_local');
      await offlineStore.saveThreads([
        messageThreadToJson(family),
      ]);

      final repository = MessagingRepository(
        apiClient: _ForbiddenChannelClient(),
        offlineStore: offlineStore,
      );

      final thread = await repository.getOrCreateCategoryThread(
        familyCategoryChannel,
      );

      expect(thread.id, 'thread_family_local');
    });
  });
}
