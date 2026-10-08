import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decryptMessageBody returns content without client E2E', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final messaging = MessagingProvider(
      repository: MessagingRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        offlineStore: OfflineStore(preferences: prefs),
      ),
    );

    final msg = Message(
      id: 'msg-1',
      threadId: 'thread-test',
      senderId: 'piotr',
      senderName: 'Piotr',
      content: 'Cześć',
      tone: MessageTone.neutral,
      attachments: const [],
      sentAt: DateTime.utc(2026, 9, 23, 20, 38, 2),
      hash: 'x',
    );

    expect(await messaging.decryptMessageBody(msg), 'Cześć');
  });
}
