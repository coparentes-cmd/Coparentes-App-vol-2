import '../config/message_tags.dart';
import '../models/models.dart';

class MessageSearchQuery {
  final String text;
  final List<String> tags;

  const MessageSearchQuery({
    required this.text,
    required this.tags,
  });

  bool get isEmpty => text.isEmpty && tags.isEmpty;
}

MessageSearchQuery parseMessageSearchQuery(String raw) {
  final tags = <String>[];
  final textParts = <String>[];

  for (final part in raw.trim().split(RegExp(r'\s+'))) {
    if (part.isEmpty) {
      continue;
    }
    if (part.toLowerCase().startsWith('tag:')) {
      final tag = normalizeMessageTag(part.substring(4));
      if (tag.isNotEmpty) {
        tags.add(tag);
      }
    } else {
      textParts.add(part);
    }
  }

  return MessageSearchQuery(
    text: textParts.join(' ').toLowerCase(),
    tags: tags,
  );
}

bool threadMatchesAllTabSearch({
  required MessageThread thread,
  required MessageSearchQuery query,
  required Map<String, Set<String>> tagsByMessageId,
}) {
  if (query.isEmpty) {
    return true;
  }

  final textMatch = query.text.isEmpty ||
      thread.subject.toLowerCase().contains(query.text) ||
      thread.messages.any(
        (message) => message.content.toLowerCase().contains(query.text),
      );

  if (query.tags.isEmpty) {
    return textMatch;
  }

  final threadTags = <String>{};
  for (final message in thread.messages) {
    threadTags.addAll(tagsByMessageId[message.id] ?? const {});
  }
  final tagMatch = query.tags.every(threadTags.contains);

  if (query.text.isNotEmpty) {
    return textMatch && tagMatch;
  }
  return tagMatch;
}

bool messageMatchesAllTabSearch({
  required Message message,
  required MessageSearchQuery query,
  required Map<String, Set<String>> tagsByMessageId,
}) {
  if (query.isEmpty) {
    return true;
  }

  final textMatch = query.text.isEmpty ||
      message.content.toLowerCase().contains(query.text);

  if (query.tags.isEmpty) {
    return textMatch;
  }

  final messageTags = tagsByMessageId[message.id] ?? const {};
  final tagMatch = query.tags.every(messageTags.contains);

  if (query.text.isNotEmpty) {
    return textMatch && tagMatch;
  }
  return tagMatch;
}

List<Message> filterMessagesForSearch({
  required List<Message> messages,
  required MessageSearchQuery query,
  required Map<String, Set<String>> tagsByMessageId,
}) {
  if (query.isEmpty) {
    return messages;
  }
  return messages
      .where(
        (message) => messageMatchesAllTabSearch(
          message: message,
          query: query,
          tagsByMessageId: tagsByMessageId,
        ),
      )
      .toList();
}

Set<String> collectThreadUserTags(
  MessageThread thread,
  Map<String, Set<String>> tagsByMessageId,
) {
  final tags = <String>{};
  for (final message in thread.messages) {
    tags.addAll(tagsByMessageId[message.id] ?? const {});
  }
  return tags;
}
