import '../models/models.dart';

bool threadHasUnreadForViewer(MessageThread thread, String viewerUserId) {
  return thread.messages.any(
    (message) => !message.isRead && message.senderId != viewerUserId,
  );
}

int countUnreadThreadsForViewer(
  List<MessageThread> threads,
  String viewerUserId,
) {
  return threads
      .where((thread) => threadHasUnreadForViewer(thread, viewerUserId))
      .length;
}

Message? findNewIncomingMessage(
  List<MessageThread> threads,
  String viewerUserId,
  Map<String, Set<String>> knownMessageIds,
) {
  Message? newest;
  for (final thread in threads) {
    final known = knownMessageIds[thread.id] ?? const {};
    for (final message in thread.messages) {
      if (message.senderId == viewerUserId) {
        continue;
      }
      if (known.contains(message.id)) {
        continue;
      }
      if (newest == null || message.sentAt.isAfter(newest.sentAt)) {
        newest = message;
      }
    }
  }
  return newest;
}

void syncKnownMessageIds(
  List<MessageThread> threads,
  Map<String, Set<String>> knownMessageIds,
) {
  for (final thread in threads) {
    knownMessageIds[thread.id] = thread.messages.map((message) => message.id).toSet();
  }
}

String formatMessageNotification(Message message) {
  final preview = message.content.length > 80
      ? '${message.content.substring(0, 80)}…'
      : message.content;
  return '${message.senderName}: $preview';
}
