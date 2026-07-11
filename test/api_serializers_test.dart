import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/data/serializers/api_serializers.dart';
import 'package:coparentes/models/models.dart';

void main() {
  group('userRoleFromApi', () {
    test('maps known roles', () {
      expect(userRoleFromApi('parentA'), UserRole.parentA);
      expect(userRoleFromApi('parentB'), UserRole.parentB);
      expect(userRoleFromApi('child'), UserRole.child);
      expect(userRoleFromApi('observer'), UserRole.observer);
    });

    test('throws on unknown role', () {
      expect(() => userRoleFromApi('admin'), throwsFormatException);
    });
  });

  group('messageThreadFromJson', () {
    test('parses family audience thread', () {
      final thread = messageThreadFromJson({
        'id': 'thread_1',
        'subject': 'Rodzina',
        'category': 'Rodzina',
        'childId': null,
        'audience': 'family',
        'lastActivity': '2026-01-01T12:00:00.000Z',
        'hasUnread': false,
        'messages': [],
      });

      expect(thread.id, 'thread_1');
      expect(thread.isFamilyAudience, isTrue);
      expect(thread.messages, isEmpty);
    });
  });

  group('messageTagsToMap', () {
    test('groups tags by message id', () {
      final map = messageTagsToMap([
        const MessageUserTag(
          messageId: 'msg_1',
          threadId: 'thread_1',
          tag: 'paragon',
        ),
        const MessageUserTag(
          messageId: 'msg_1',
          threadId: 'thread_1',
          tag: 'pilne',
        ),
      ]);

      expect(map['msg_1'], {'paragon', 'pilne'});
    });
  });
}
