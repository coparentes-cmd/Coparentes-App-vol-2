import '../models/models.dart';

const String familyCategoryChannel = 'Rodzina';
const String scheduleCategoryChannel = 'Zmiana grafiku';
const String allTabLabel = 'Wszystkie';

const List<String> legacyThematicChannels = [
  'Szkoła',
  'Zdrowie',
  'Finanse',
];

const List<String> messagingParentCategoryChannels = [
  ...legacyThematicChannels,
  scheduleCategoryChannel,
];

/// Chips shown in parent messaging UI.
const List<String> messagingNavChips = [
  allTabLabel,
  familyCategoryChannel,
  scheduleCategoryChannel,
];

/// Legacy list kept for channel detection helpers.
const List<String> messagingCategoryChannels = [
  familyCategoryChannel,
  ...messagingParentCategoryChannels,
];

bool isFamilyChannel(MessageThread thread) {
  return thread.isFamilyAudience ||
      (thread.category == familyCategoryChannel &&
          thread.subject == familyCategoryChannel);
}

bool isScheduleChannel(MessageThread thread) {
  final category =
      thread.category == 'Finansowe' ? 'Finanse' : thread.category;
  final subject = thread.subject == 'Finansowe' ? 'Finanse' : thread.subject;
  return category == scheduleCategoryChannel ||
      subject == scheduleCategoryChannel;
}

bool isAllTabThread(MessageThread thread) {
  return !isFamilyChannel(thread) && !isScheduleChannel(thread);
}

bool isCategoryChannel(MessageThread thread) {
  if (isFamilyChannel(thread) || isScheduleChannel(thread)) {
    return false;
  }
  final category = thread.category == 'Finansowe' ? 'Finanse' : thread.category;
  final subject = thread.subject == 'Finansowe' ? 'Finanse' : thread.subject;
  return legacyThematicChannels.contains(category) && subject == category;
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
    case scheduleCategoryChannel:
      return 'Opieka, wymiany terminów';
    default:
      return 'Sprawy rodzinne';
  }
}

String threadListTitle(MessageThread thread) {
  if (isCategoryChannel(thread)) {
    return thread.category == 'Finansowe' ? 'Finanse' : thread.category;
  }
  return thread.subject;
}
