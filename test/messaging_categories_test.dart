import 'package:coparentes/config/messaging_categories.dart';
import 'package:coparentes/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

MessageThread _thread({
  required String id,
  required String subject,
  required String category,
  String audience = 'parents',
}) {
  return MessageThread(
    id: id,
    subject: subject,
    category: category,
    lastActivity: DateTime(2026, 1, 1),
    messages: const [],
    audience: audience,
  );
}

void main() {
  group('isParentsInboxChannel', () {
    test('matches Wszystkie channel', () {
      final thread = _thread(
        id: '1',
        subject: allTabLabel,
        category: allTabLabel,
      );
      expect(isParentsInboxChannel(thread), isTrue);
    });

    test('rejects custom thread', () {
      final thread = _thread(
        id: '2',
        subject: 'Angielski',
        category: 'Ogólne',
      );
      expect(isParentsInboxChannel(thread), isFalse);
    });
  });

  group('isCustomUserThread', () {
    test('custom Ogólne thread is custom', () {
      final thread = _thread(
        id: '3',
        subject: 'Angielski',
        category: 'Ogólne',
      );
      expect(isCustomUserThread(thread), isTrue);
      expect(isAllTabThread(thread), isTrue);
    });

    test('Rodzina channel is not custom', () {
      final thread = _thread(
        id: '4',
        subject: familyCategoryChannel,
        category: familyCategoryChannel,
        audience: 'family',
      );
      expect(isCustomUserThread(thread), isFalse);
    });

    test('Zmiana grafiku is not custom', () {
      final thread = _thread(
        id: '5',
        subject: scheduleCategoryChannel,
        category: scheduleCategoryChannel,
      );
      expect(isCustomUserThread(thread), isFalse);
      expect(isAllTabThread(thread), isFalse);
    });
  });

  group('isSameManagedChannelThread', () {
    test('same id matches', () {
      final a = _thread(id: 'x', subject: 'A', category: 'Ogólne');
      final b = _thread(id: 'x', subject: 'B', category: 'Ogólne');
      expect(isSameManagedChannelThread(a, b), isTrue);
    });

    test('two Wszystkie channels match', () {
      final a = _thread(id: '1', subject: allTabLabel, category: allTabLabel);
      final b = _thread(id: '2', subject: allTabLabel, category: allTabLabel);
      expect(isSameManagedChannelThread(a, b), isTrue);
    });

    test('two custom Ogólne threads do not match', () {
      final a = _thread(id: '1', subject: 'A', category: 'Ogólne');
      final b = _thread(id: '2', subject: 'B', category: 'Ogólne');
      expect(isSameManagedChannelThread(a, b), isFalse);
    });
  });
}
