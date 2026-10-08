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

  group('messageFromJson KEY_MESSAGES / legacy E2E', () {
    test('parses plaintext content without client E2E fields', () {
      final message = messageFromJson({
        'id': 'msg_1',
        'threadId': 'thread_1',
        'senderId': 'user_a',
        'senderName': 'Anna',
        'content': 'Cześć',
        'tone': 'neutral',
        'sentAt': '2026-01-01T12:00:00.000Z',
        'isDelivered': true,
        'isRead': false,
        'hash': 'h1',
      });

      expect(message.content, 'Cześć');
      expect(message.isE2E, isFalse);
      expect(message.needsDecryption, isFalse);
      expect(message.ciphertext, isNull);
    });

    test('maps legacyE2e empty content to archive label', () {
      final message = messageFromJson({
        'id': 'msg_old',
        'threadId': 'thread_1',
        'senderId': 'user_a',
        'senderName': 'Anna',
        'content': '',
        'legacyE2e': true,
        'tone': 'neutral',
        'sentAt': '2026-01-01T12:00:00.000Z',
        'isDelivered': true,
        'isRead': false,
        'hash': 'h_old',
      });

      expect(message.content, 'Starsza wiadomość nie jest już dostępna');
      expect(message.isE2E, isFalse);
      expect(message.needsDecryption, isFalse);
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

  group('appUserFromJson mustChangePassword', () {
    test('defaults to false when missing', () {
      final user = appUserFromJson({
        'id': 'u1',
        'name': 'Ada',
        'email': 'ada@test.app',
        'role': 'parentA',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(user.mustChangePassword, isFalse);
    });

    test('parses true', () {
      final user = appUserFromJson({
        'id': 'u1',
        'name': 'Ada',
        'email': 'ada@test.app',
        'role': 'parentA',
        'mustChangePassword': true,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(user.mustChangePassword, isTrue);
      expect(appUserToJson(user)['mustChangePassword'], isTrue);
    });
  });
}
