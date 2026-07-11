import '../../config/messaging_categories.dart';
import '../../models/models.dart';

/// Returns the category channel to open for [thread], or null if it should
/// open as an inline thread in the All tab.
String? categoryChannelForThread(MessageThread thread) {
  if (isFamilyChannel(thread)) {
    return familyCategoryChannel;
  }
  if (isScheduleChannel(thread)) {
    return scheduleCategoryChannel;
  }
  return null;
}
