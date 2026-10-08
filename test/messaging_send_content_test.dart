import 'dart:convert';

import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/data/serializers/api_serializers.dart';
import 'package:coparentes/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureSendClient extends http.BaseClient {
  Map<String, dynamic>? lastBody;
  String? lastPath;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastPath = request.url.path;
    if (request is http.Request) {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
    }

    final thread = MessageThread(
      id: 'thread_1',
      subject: 'Rodzina',
      category: 'Rodzina',
      audience: 'family',
      lastActivity: DateTime(2026, 6, 1),
      hasUnread: false,
      messages: [
        Message(
          id: 'msg_1',
          threadId: 'thread_1',
          senderId: 'me',
          senderName: 'Ja',
          content: lastBody?['content'] as String? ?? '',
          tone: MessageTone.neutral,
          attachments: const [],
          sentAt: DateTime(2026, 6, 1, 12),
          isDelivered: true,
          isRead: false,
          hash: 'h1',
        ),
      ],
    );

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(messageThreadToJson(thread)))),
      201,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sendMessage posts plaintext content without ciphertext', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    final httpClient = _CaptureSendClient();

    final repository = MessagingRepository(
      apiClient: AppApiClient(
        baseUrl: 'http://127.0.0.1:0/api',
        httpClient: httpClient,
      ),
      offlineStore: offline,
    );

    final thread = await repository.sendMessage(
      threadId: 'thread_1',
      content: 'Hej z nowego czatu',
      tone: MessageTone.neutral,
    );

    expect(httpClient.lastPath, '/api/threads/thread_1/messages');
    expect(httpClient.lastBody?['content'], 'Hej z nowego czatu');
    expect(httpClient.lastBody?.containsKey('ciphertext'), isFalse);
    expect(httpClient.lastBody?.containsKey('nonce'), isFalse);
    expect(thread.messages.single.content, 'Hej z nowego czatu');
    expect(thread.messages.single.isE2E, isFalse);
  });
}
