import 'package:coparentes/config/message_reactions.dart';
import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReactionsRepository extends MessagingRepository {
  _FakeReactionsRepository()
      : super(
          apiClient: AppApiClient(baseUrl: 'http://127.0.0.1:0/api'),
          offlineStore: OfflineStore(preferences: _prefs!),
        );

  static SharedPreferences? _prefs;

  static Future<void> initPrefs() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  }

  final List<({String messageId, String? emoji})> calls = [];

  @override
  Future<List<MessageReaction>> setMessageReaction({
    required String messageId,
    String? emoji,
  }) async {
    calls.add((messageId: messageId, emoji: emoji));
    if (emoji == null) {
      return const [];
    }
    return [
      MessageReaction(
        messageId: messageId,
        threadId: 'thread_1',
        userId: 'user_1',
        emoji: emoji,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _FakeReactionsRepository.initPrefs();
  });

  test('quickMessageReactions matches WhatsApp set', () {
    expect(quickMessageReactions, ['👍', '❤️', '😂', '😮', '😢', '🙏']);
    expect(isAllowedMessageReaction('👍'), isTrue);
    expect(isAllowedMessageReaction('🔥'), isFalse);
  });

  test('setMessageReaction toggles same emoji off (local + remote)', () async {
    final repo = _FakeReactionsRepository();
    final provider = MessagingProvider(repository: repo);

    await provider.setMessageReaction(
      messageId: 'msg_1',
      threadId: 'thread_1',
      userId: 'user_1',
      emoji: '👍',
    );
    expect(provider.myReactionEmoji(messageId: 'msg_1', userId: 'user_1'), '👍');
    expect(repo.calls.last.emoji, '👍');

    await provider.setMessageReaction(
      messageId: 'msg_1',
      threadId: 'thread_1',
      userId: 'user_1',
      emoji: '👍',
    );
    expect(provider.myReactionEmoji(messageId: 'msg_1', userId: 'user_1'), isNull);
    expect(repo.calls.last.emoji, isNull);
  });

  test('setMessageReaction localOnly skips remote', () async {
    final repo = _FakeReactionsRepository();
    final provider = MessagingProvider(repository: repo);

    await provider.setMessageReaction(
      messageId: 'msg_1',
      threadId: 'thread_1',
      userId: 'user_1',
      emoji: '❤️',
      localOnly: true,
    );

    expect(provider.myReactionEmoji(messageId: 'msg_1', userId: 'user_1'), '❤️');
    expect(repo.calls, isEmpty);
  });
}
