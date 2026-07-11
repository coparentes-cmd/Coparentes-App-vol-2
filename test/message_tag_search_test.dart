import 'package:coparentes/models/models.dart';
import 'package:coparentes/utils/message_tag_search.dart';
import 'package:flutter_test/flutter_test.dart';

Message _message({required String id, required String content}) {
  return Message(
    id: id,
    threadId: 'thread_1',
    senderId: 'user_a',
    senderName: 'Anna',
    content: content,
    tone: MessageTone.neutral,
    attachments: const [],
    sentAt: DateTime(2026, 1, 1),
    hash: 'hash_$id',
  );
}

void main() {
  group('parseMessageSearchQuery', () {
    test('parses tag: prefix', () {
      final query = parseMessageSearchQuery('tag:paragon szkoła');
      expect(query.tags, ['paragon']);
      expect(query.text, 'szkoła');
    });

    test('empty input is empty query', () {
      final query = parseMessageSearchQuery('   ');
      expect(query.isEmpty, isTrue);
    });
  });

  group('filterMessagesForSearch', () {
    test('filters by tag', () {
      final messages = [
        _message(id: 'm1', content: 'Paragon za lekcje'),
        _message(id: 'm2', content: 'Inna wiadomość'),
      ];
      final tags = {
        'm1': {'paragon'},
      };
      final filtered = filterMessagesForSearch(
        messages: messages,
        query: const MessageSearchQuery(text: '', tags: ['paragon']),
        tagsByMessageId: tags,
      );
      expect(filtered.map((m) => m.id), ['m1']);
    });

    test('filters by text and tag together', () {
      final messages = [
        _message(id: 'm1', content: 'Paragon za lekcje'),
        _message(id: 'm2', content: 'Paragon za obiad'),
      ];
      final tags = {
        'm1': {'paragon'},
        'm2': {'paragon'},
      };
      final filtered = filterMessagesForSearch(
        messages: messages,
        query: const MessageSearchQuery(text: 'lekcje', tags: ['paragon']),
        tagsByMessageId: tags,
      );
      expect(filtered.map((m) => m.id), ['m1']);
    });
  });

  group('threadMatchesAllTabSearch', () {
    MessageThread _thread(List<Message> messages) {
      return MessageThread(
        id: 'thread_1',
        subject: 'Test',
        category: 'Ogólne',
        lastActivity: DateTime(2026, 1, 1),
        hasUnread: false,
        messages: messages,
      );
    }

    test('matches thread when any message has the tag', () {
      final thread = _thread([
        _message(id: 'm1', content: 'Bez etykiety'),
        _message(id: 'm2', content: 'Z paragonem'),
      ]);
      final tags = {
        'm2': {'paragon'},
      };
      final matches = threadMatchesAllTabSearch(
        thread: thread,
        query: const MessageSearchQuery(text: '', tags: ['paragon']),
        tagsByMessageId: tags,
      );
      expect(matches, isTrue);
    });

    test('does not match thread without the tag', () {
      final thread = _thread([
        _message(id: 'm1', content: 'Inna wiadomość'),
      ]);
      final matches = threadMatchesAllTabSearch(
        thread: thread,
        query: const MessageSearchQuery(text: '', tags: ['paragon']),
        tagsByMessageId: const {},
      );
      expect(matches, isFalse);
    });
  });
}
