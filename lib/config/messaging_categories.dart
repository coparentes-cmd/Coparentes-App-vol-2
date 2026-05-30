import '../models/models.dart';

const List<String> messagingCategoryChannels = [
  'Szkoła',
  'Zdrowie',
  'Finansowe',
  'Zmiana grafiku',
  'Inne',
];

bool isCategoryChannel(MessageThread thread) {
  return messagingCategoryChannels.contains(thread.category) &&
      thread.subject == thread.category;
}

MessageThread? findCategoryChannel(
  List<MessageThread> threads,
  String category,
) {
  for (final thread in threads) {
    if (thread.category == category && thread.subject == category) {
      return thread;
    }
  }
  return null;
}

String categoryChannelSubtitle(String category) {
  switch (category) {
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
