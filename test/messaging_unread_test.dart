import 'package:coparentes/models/models.dart';
import 'package:coparentes/utils/messaging_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

Message _msg({
  required String id,
  required String senderId,
  required bool isRead,
  DateTime? sentAt,
}) {
  return Message(
    id: id,
    threadId: 't1',
    senderId: senderId,
    senderName: senderId,
    content: 'hello $id',
    tone: MessageTone.neutral,
    attachments: const [],
    sentAt: sentAt ?? DateTime(2026, 8, 1, 12),
    isDelivered: true,
    isRead: isRead,
    hash: id,
  );
}

MessageThread _thread({
  required List<Message> messages,
  bool hasUnread = false,
}) {
  return MessageThread(
    id: 't1',
    subject: 'Temat',
    category: 'Ogólne',
    messages: messages,
    lastActivity: DateTime(2026, 8, 1, 12),
    hasUnread: hasUnread,
  );
}

void main() {
  const viewer = 'user_a';
  const other = 'user_b';

  test('collectUnreadMessagesForViewer ignores own unread outgoing', () {
    final threads = [
      _thread(
        messages: [
          _msg(id: '1', senderId: viewer, isRead: false),
          _msg(id: '2', senderId: other, isRead: false),
        ],
      ),
    ];

    final unread = collectUnreadMessagesForViewer(threads, viewer);
    expect(unread, hasLength(1));
    expect(unread.single.message.id, '2');
  });

  test('collectUnreadMessagesForViewer falls back to hasUnread flag', () {
    final threads = [
      _thread(
        hasUnread: true,
        messages: [
          _msg(id: '1', senderId: other, isRead: true),
          _msg(
            id: '2',
            senderId: other,
            isRead: true,
            sentAt: DateTime(2026, 8, 1, 13),
          ),
        ],
      ),
    ];

    final unread = collectUnreadMessagesForViewer(threads, viewer);
    expect(unread, hasLength(1));
    expect(unread.single.message.id, '2');
  });

  test('mergeThreadPreservingLocalReads keeps local read over stale unread', () {
    final local = _thread(
      messages: [
        _msg(id: '1', senderId: other, isRead: true),
      ],
    );
    final remote = _thread(
      hasUnread: true,
      messages: [
        _msg(id: '1', senderId: other, isRead: false),
      ],
    );

    final merged = mergeThreadPreservingLocalReads(
      remote: remote,
      local: local,
    );
    expect(merged.messages.single.isRead, isTrue);
    expect(merged.hasUnread, isFalse);
  });

  test('countUnreadMessagesForViewer matches collected items', () {
    final threads = [
      _thread(
        messages: [
          _msg(id: '1', senderId: other, isRead: false),
          _msg(id: '2', senderId: other, isRead: false),
          _msg(id: '3', senderId: viewer, isRead: false),
        ],
      ),
    ];
    expect(countUnreadMessagesForViewer(threads, viewer), 2);
  });
}
