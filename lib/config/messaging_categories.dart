import '../models/models.dart';

const String familyCategoryChannel = 'Rodzina';

const List<String> messagingParentCategoryChannels = [
  'Szkoła',
  'Zdrowie',
  'Finanse',
  'Zmiana grafiku',
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
  final category = thread.category == 'Finansowe' ? 'Finanse' : thread.category;
  final subject = thread.subject == 'Finansowe' ? 'Finanse' : thread.subject;
  return messagingParentCategoryChannels.contains(category) &&
      subject == category;
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

  // Legacy channel name before rename Finansowe → Finanse.
  if (category == 'Finanse') {
    for (final thread in threads) {
      if (thread.category == 'Finansowe' && thread.subject == 'Finansowe') {
        return thread;
      }
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
    final threadCategory =
        thread.category == 'Finansowe' ? 'Finanse' : thread.category;
    if (threadCategory != category && thread.category != category) {
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
    case 'Finanse':
    case 'Finansowe':
      return 'Wydatki, rozliczenia';
    case 'Zmiana grafiku':
      return 'Opieka, wymiany terminów';
    default:
      return 'Sprawy rodzinne';
  }
}
