/// Quick reactions (WhatsApp-style). Must match backend ALLOWED_MESSAGE_REACTIONS.
const List<String> quickMessageReactions = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
];

bool isAllowedMessageReaction(String emoji) {
  return quickMessageReactions.contains(emoji.trim());
}
