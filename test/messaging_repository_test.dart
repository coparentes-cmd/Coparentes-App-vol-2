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

class _FailingMarkReadHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error":"unavailable"}')),
      503,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _MarkReadSyncHttpClient extends http.BaseClient {
  final List<String> readPaths = [];
  final MessageThread threadResponse;
  final bool fail;

  _MarkReadSyncHttpClient({
    required this.threadResponse,
    this.fail = false,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (fail) {
      throw http.ClientException('network down', request.url);
    }

    if (request.method == 'POST' && request.url.path.endsWith('/read')) {
      readPaths.add(request.url.path);
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(messageThreadToJson(threadResponse)))),
        200,
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

MessageThread _unreadThread({required String id}) {
  return MessageThread(
    id: id,
    subject: 'Rodzina',
    category: familyCategoryChannel,
    audience: 'family',
    lastActivity: DateTime(2026, 6, 1, 12),
    hasUnread: true,
    messages: [
      Message(
        id: 'msg_1',
        threadId: id,
        senderId: 'other',
        senderName: 'Other',
        content: 'hello',
        tone: MessageTone.neutral,
        attachments: const [],
        sentAt: DateTime(2026, 6, 1, 12),
        isDelivered: true,
        isRead: false,
        hash: 'hash_1',
      ),
    ],
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

  group('MessagingRepository.markThreadRead offline queue', () {
    late SharedPreferences preferences;
    late OfflineStore offlineStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      offlineStore = OfflineStore(preferences: preferences);
    });

    test('enqueues messaging.markThreadRead when API fails', () async {
      final repository = MessagingRepository(
        apiClient: AppApiClient(
          baseUrl: 'http://127.0.0.1:0/api',
          httpClient: _FailingMarkReadHttpClient(),
        ),
        offlineStore: offlineStore,
      );

      final result = await repository.markThreadRead('thread_abc');

      expect(result, isNull);
      final pending = offlineStore.getPendingActions();
      expect(pending, hasLength(1));
      expect(pending.single['type'], 'messaging.markThreadRead');
      expect(pending.single['payload'], {'threadId': 'thread_abc'});
      expect(pending.single['createdAt'], isA<String>());
    });

    test('syncPendingActions marks thread read and drops queue item on success',
        () async {
      final unread = _unreadThread(id: 'thread_read_me');
      final read = MessageThread(
        id: unread.id,
        subject: unread.subject,
        category: unread.category,
        audience: unread.audience,
        lastActivity: unread.lastActivity,
        hasUnread: false,
        messages: unread.messages
            .map((m) => m.copyWith(isRead: true))
            .toList(),
      );

      await offlineStore.saveThreads([messageThreadToJson(unread)]);
      await offlineStore.appendPendingAction({
        'type': 'messaging.markThreadRead',
        'createdAt': DateTime(2026, 6, 1).toIso8601String(),
        'payload': {'threadId': 'thread_read_me'},
      });

      final httpClient = _MarkReadSyncHttpClient(threadResponse: read);
      final repository = MessagingRepository(
        apiClient: AppApiClient(
          baseUrl: 'http://127.0.0.1:0/api',
          httpClient: httpClient,
        ),
        offlineStore: offlineStore,
      );

      await repository.syncPendingActions();

      expect(httpClient.readPaths, ['/api/threads/thread_read_me/read']);
      expect(offlineStore.getPendingActions(), isEmpty);
      final cached = offlineStore
          .getThreads()
          .map(messageThreadFromJson)
          .toList();
      expect(cached.single.hasUnread, isFalse);
      expect(cached.single.messages.single.isRead, isTrue);
    });

    test('syncPendingActions requeues markThreadRead when sync fails', () async {
      await offlineStore.appendPendingAction({
        'type': 'messaging.markThreadRead',
        'createdAt': DateTime(2026, 6, 1).toIso8601String(),
        'payload': {'threadId': 'thread_retry'},
      });

      final repository = MessagingRepository(
        apiClient: AppApiClient(
          baseUrl: 'http://127.0.0.1:0/api',
          httpClient: _MarkReadSyncHttpClient(
            threadResponse: _familyThread(id: 'thread_retry'),
            fail: true,
          ),
        ),
        offlineStore: offlineStore,
      );

      await repository.syncPendingActions();

      final pending = offlineStore.getPendingActions();
      expect(pending, hasLength(1));
      expect(pending.single['type'], 'messaging.markThreadRead');
      expect(pending.single['payload'], {'threadId': 'thread_retry'});
    });
  });
}
