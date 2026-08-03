import '../models/models.dart';

const String familyCategoryChannel = 'Rodzina';
/// UI label for [familyCategoryChannel] — channel id stays unchanged for API/data.
const String familyCategoryDisplayLabel = 'z dziećmi';
const String scheduleCategoryChannel = 'Zmiana grafiku';
const String allTabLabel = 'Wszystkie';

/// Visible label for messaging category chips and titles.
String messagingCategoryLabel(String category) {
  if (category == familyCategoryChannel) {
    return familyCategoryDisplayLabel;
  }
  return category;
}

const List<String> legacyThematicChannels = [
  'Szkoła',
  'Zdrowie',
  'Finanse',
];

const List<String> messagingParentCategoryChannels = [
  ...legacyThematicChannels,
  scheduleCategoryChannel,
];

/// Reserved channel names — cannot be used as custom thread subjects.
const List<String> messagingCategoryChannels = [
  allTabLabel,
  familyCategoryChannel,
  ...messagingParentCategoryChannels,
];

/// Chips shown in parent messaging UI.
const List<String> messagingNavChips = [
  allTabLabel,
  familyCategoryChannel,
  scheduleCategoryChannel,
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

bool isParentsInboxChannel(MessageThread thread) {
  return thread.category == allTabLabel && thread.subject == allTabLabel;
}

bool isAllTabThread(MessageThread thread) {
  return !isFamilyChannel(thread) && !isScheduleChannel(thread);
}

bool isCustomUserThread(MessageThread thread) {
  if (!isAllTabThread(thread)) {
    return false;
  }
  if (isParentsInboxChannel(thread) ||
      isFamilyChannel(thread) ||
      isScheduleChannel(thread) ||
      isCategoryChannel(thread)) {
    return false;
  }
  return true;
}

bool isSameManagedChannelThread(MessageThread a, MessageThread b) {
  if (a.id == b.id) {
    return true;
  }
  if (isParentsInboxChannel(a) && isParentsInboxChannel(b)) {
    return true;
  }
  if (isFamilyChannel(a) && isFamilyChannel(b)) {
    return true;
  }
  if (isScheduleChannel(a) && isScheduleChannel(b)) {
    return true;
  }
  if (isCategoryChannel(a) && isCategoryChannel(b)) {
    final categoryA = a.category == 'Finansowe' ? 'Finanse' : a.category;
    final categoryB = b.category == 'Finansowe' ? 'Finanse' : b.category;
    return categoryA == categoryB;
  }
  return false;
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
  if (category == allTabLabel) {
    for (final thread in threads) {
      if (isParentsInboxChannel(thread)) {
        return thread;
      }
    }
    return null;
  }

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
    case allTabLabel:
      return 'Wspólne wiadomości — oznaczaj własnymi etykietami';
    case familyCategoryChannel:
      return 'Rozmowy z dziećmi i rodzicami';
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
  if (isParentsInboxChannel(thread)) {
    return allTabLabel;
  }
  if (isFamilyChannel(thread)) {
    return familyCategoryDisplayLabel;
  }
  if (isScheduleChannel(thread)) {
    return scheduleCategoryChannel;
  }
  if (isCategoryChannel(thread)) {
    return thread.category == 'Finansowe' ? 'Finanse' : thread.category;
  }
  return thread.subject;
}
