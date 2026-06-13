import '../models/models.dart';

const String familyCategoryChannel = 'Rodzina';

const List<String> messagingParentCategoryChannels = [
  'Szkoła',
  'Zdrowie',
  'Finansowe',
  'Zmiana grafiku',
  'Inne',
];

/// All category chips shown to parents (family channel first).
const List<String> messagingCategoryChannels = [
  familyCategoryChannel,
  ...messagingParentCategoryChannels,
];

bool isFamilyChannel(MessageThread thread) {
  return thread.isFamilyAudience ||
      (thread.category == familyCategoryChannel &&
          thread.subject == familyCategoryChannel);
}

bool isCategoryChannel(MessageThread thread) {
  if (isFamilyChannel(thread)) {
    return false;
  }
  return messagingParentCategoryChannels.contains(thread.category) &&
      thread.subject == thread.category;
}

MessageThread? findFamilyChannel(List<MessageThread> threads) {
  for (final thread in threads) {
    if (isFamilyChannel(thread)) {
      return thread;
    }
  }
  return null;
}

MessageThread? findCategoryChannel(
  List<MessageThread> threads,
  String category,
) {
  if (category == familyCategoryChannel) {
    return findFamilyChannel(threads);
  }

  for (final thread in threads) {
    if (thread.category == category && thread.subject == category) {
      return thread;
    }
  }
  return null;
}

MessageThread? findCategoryThreadFallback(
  List<MessageThread> threads,
  String category,
) {
  if (category == familyCategoryChannel) {
    return findFamilyChannel(threads);
  }

  final canonical = findCategoryChannel(threads, category);
  if (canonical != null) {
    return canonical;
  }

  MessageThread? newest;
  for (final thread in threads) {
    if (thread.category != category) {
      continue;
    }
    if (newest == null || thread.lastActivity.isAfter(newest.lastActivity)) {
      newest = thread;
    }
  }
  return newest;
}

String categoryChannelSubtitle(String category) {
  switch (category) {
    case familyCategoryChannel:
      return 'Rozmowy z całą rodziną';
    case 'Szkoła':
      return 'Lekcje, zebrania, oceny';
    case 'Zdrowie':
      return 'Wizyty, recepty, badania';
    case 'Finansowe':
      return 'Wydatki, rozliczenia';
    case 'Zmiana grafiku':
      return 'Opieka, wymiany terminów';
    default:
      return 'Inne sprawy rodzinne';
  }
}
