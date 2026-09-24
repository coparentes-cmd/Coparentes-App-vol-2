import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeE2eSession extends E2eSessionService {
  _FakeE2eSession() : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  bool unlocked = false;
  int decryptCalls = 0;

  @override
  Future<bool> hasUnlockedKey() async => unlocked;

  @override
  Future<String> decryptMessageFromThread({
    required String threadId,
    required String ciphertext,
    required String nonce,
  }) async {
    decryptCalls += 1;
    if (!unlocked) {
      throw NoUnlockedKeyException();
    }
    return 'ok';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed decrypt before unlock does not stick after clearDecryptCaches',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final e2e = _FakeE2eSession();
    final messaging = MessagingProvider(
      repository: MessagingRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        offlineStore: OfflineStore(preferences: prefs),
      ),
      e2eSessionService: e2e,
    );

    final piotr = Message(
      id: 'msg-piotr-ok',
      threadId: 'thread-test',
      senderId: 'piotr',
      senderName: 'Piotr',
      content: '',
      tone: MessageTone.neutral,
      attachments: const [],
      sentAt: DateTime.utc(2026, 9, 23, 20, 38, 2),
      hash: 'x',
      isE2E: true,
      ciphertext: 'cipher',
      nonce: 'nonce12',
    );

    // Poison: list preview while locked
    await expectLater(
      messaging.decryptMessageBody(piotr),
      throwsA(isA<NoUnlockedKeyException>()),
    );
    expect(e2e.decryptCalls, 1);

    // Unlock + clear (AppProvider.onE2eSessionChanged → clearDecryptCaches)
    e2e.unlocked = true;
    messaging.clearDecryptCaches();

    final plain = await messaging.decryptMessageBody(piotr);
    expect(plain, 'ok');
    expect(e2e.decryptCalls, 2);

    // Resolved cache hit — no extra decrypt
    final again = await messaging.decryptMessageBody(piotr);
    expect(again, 'ok');
    expect(e2e.decryptCalls, 2);
  });

  test('remove-on-fail alone also allows retry after unlock', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final e2e = _FakeE2eSession();
    final messaging = MessagingProvider(
      repository: MessagingRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        offlineStore: OfflineStore(preferences: prefs),
      ),
      e2eSessionService: e2e,
    );

    final msg = Message(
      id: 'msg-2',
      threadId: 't',
      senderId: 'p',
      senderName: 'P',
      content: '',
      tone: MessageTone.neutral,
      attachments: const [],
      sentAt: DateTime.now(),
      hash: 'h',
      isE2E: true,
      ciphertext: 'c',
      nonce: 'n',
    );

    await expectLater(
      messaging.decryptMessageBody(msg),
      throwsA(isA<NoUnlockedKeyException>()),
    );

    e2e.unlocked = true;
    // No clearDecryptCaches — putIfAbsent remove-on-fail must be enough
    expect(await messaging.decryptMessageBody(msg), 'ok');
  });
}
