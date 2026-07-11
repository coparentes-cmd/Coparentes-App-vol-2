import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/features/messaging/messaging_permissions.dart';
import 'package:coparentes/models/models.dart';

AppUser _user(UserRole role) => AppUser(
      id: 'user_1',
      name: 'Test User',
      email: 'test@example.com',
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('canSendMessages', () {
    test('parents and child can send', () {
      expect(canSendMessages(_user(UserRole.parentA)), isTrue);
      expect(canSendMessages(_user(UserRole.parentB)), isTrue);
      expect(canSendMessages(_user(UserRole.child)), isTrue);
    });

    test('observer cannot send', () {
      expect(canSendMessages(_user(UserRole.observer)), isFalse);
    });

    test('null user cannot send', () {
      expect(canSendMessages(null), isFalse);
    });
  });

  group('canUsePrivateTags', () {
    test('parents can use private tags', () {
      expect(canUsePrivateTags(_user(UserRole.parentA)), isTrue);
      expect(canUsePrivateTags(_user(UserRole.parentB)), isTrue);
    });

    test('child and observer cannot use private tags', () {
      expect(canUsePrivateTags(_user(UserRole.child)), isFalse);
      expect(canUsePrivateTags(_user(UserRole.observer)), isFalse);
    });
  });

  group('shouldResolveChannelFromCache', () {
    test('child resolves from cache', () {
      expect(shouldResolveChannelFromCache(_user(UserRole.child)), isTrue);
    });

    test('parents resolve from API first', () {
      expect(shouldResolveChannelFromCache(_user(UserRole.parentA)), isFalse);
      expect(shouldResolveChannelFromCache(_user(UserRole.parentB)), isFalse);
    });
  });

  group('isMessagingReadOnly', () {
    test('observer is read-only', () {
      expect(isMessagingReadOnly(_user(UserRole.observer)), isTrue);
    });

    test('other roles are not read-only', () {
      expect(isMessagingReadOnly(_user(UserRole.parentA)), isFalse);
      expect(isMessagingReadOnly(_user(UserRole.child)), isFalse);
    });
  });
}
