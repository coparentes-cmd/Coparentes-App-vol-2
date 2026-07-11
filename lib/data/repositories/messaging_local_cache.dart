import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../local/offline_store.dart';
import '../serializers/api_serializers.dart';

class MessagingLocalCache {
  final OfflineStore _offlineStore;

  MessagingLocalCache({required OfflineStore offlineStore})
      : _offlineStore = offlineStore;

  List<MessageThread> getCachedThreads() {
    return _offlineStore
        .getThreads()
        .map(messageThreadFromJson)
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  Future<void> saveThreads(List<MessageThread> threads) {
    return _offlineStore.saveThreads(threads.map(messageThreadToJson).toList());
  }

  Future<void> saveMessageTags(Map<String, Set<String>> tags) {
    final payload = tags.entries
        .expand(
          (entry) => entry.value.map(
            (tag) => {
              'messageId': entry.key,
              'tag': tag,
            },
          ),
        )
        .toList();
    return _offlineStore.saveMessageTags(payload);
  }

  Map<String, Set<String>> getCachedMessageTags() {
    final raw = _offlineStore.getMessageTags();
    final result = <String, Set<String>>{};
    for (final item in raw) {
      final messageId = item['messageId'] as String?;
      final tag = item['tag'] as String?;
      if (messageId == null || tag == null) {
        continue;
      }
      result.putIfAbsent(messageId, () => <String>{}).add(tag.toLowerCase());
    }
    return result;
  }

  MessageThread? findCachedCategoryThread(String category) {
    final cached = getCachedThreads();
    final existing = category == familyCategoryChannel
        ? findFamilyChannel(cached)
        : findCategoryChannel(cached, category);
    if (existing != null && !isLocalThreadId(existing.id)) {
      return existing;
    }
    return null;
  }

  Future<void> replaceChannelThreadInCache(MessageThread thread) async {
    final cachedThreads = getCachedThreads()
      ..removeWhere(
        (item) => isSameManagedChannelThread(item, thread),
      );
    cachedThreads.insert(0, thread);
    cachedThreads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    await saveThreads(cachedThreads);
  }

  Future<void> removeThreadFromCache(String threadId) async {
    final cachedThreads = getCachedThreads()
      ..removeWhere((item) => item.id == threadId);
    await saveThreads(cachedThreads);
  }

  MessageThread? findCachedThreadById(String threadId) {
    for (final thread in getCachedThreads()) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  String? inferChannelCategory(MessageThread thread) {
    if (isParentsInboxChannel(thread)) {
      return allTabLabel;
    }
    if (isFamilyChannel(thread)) {
      return familyCategoryChannel;
    }
    if (isScheduleChannel(thread)) {
      return scheduleCategoryChannel;
    }
    if (thread.subject == thread.category &&
        messagingCategoryChannels.contains(thread.category)) {
      return thread.category == 'Finansowe' ? 'Finanse' : thread.category;
    }
    return null;
  }

  bool isLocalThreadId(String threadId) => threadId.startsWith('local_');

  Future<void> upsertThread(MessageThread thread) async {
    final cachedThreads = getCachedThreads();
    final index = cachedThreads.indexWhere((item) => item.id == thread.id);
    if (index >= 0) {
      cachedThreads[index] = thread;
    } else {
      cachedThreads.insert(0, thread);
    }
    cachedThreads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    await saveThreads(cachedThreads);
  }

  void replaceThreadId(
    List<MessageThread> threads,
    String threadId,
    MessageThread replacement,
  ) {
    final index = threads.indexWhere((thread) => thread.id == threadId);
    if (index >= 0) {
      threads[index] = replacement;
    } else {
      threads.insert(0, replacement);
    }
  }
}
