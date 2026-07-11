import '../../config/messaging_categories.dart';
import '../../config/message_tags.dart';
import '../../models/models.dart';
import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../serializers/api_serializers.dart';

class MessagingLoadResult {
  final List<MessageThread> threads;
  final Map<String, Set<String>> tagsByMessageId;

  const MessagingLoadResult({
    required this.threads,
    required this.tagsByMessageId,
  });
}

class MessagingRepository {
  final AppApiClient _apiClient;
  final OfflineStore _offlineStore;

  MessagingRepository({
    required AppApiClient apiClient,
    required OfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<MessagingLoadResult> getThreads() async {
    if (_offlineStore.getPendingActions().isNotEmpty) {
      await syncPendingActions();
    }

    try {
      final payload = await _apiClient.getJson('/threads');
      final threads = (payload['threads'] as List<dynamic>)
          .map(
            (item) => messageThreadFromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      final tags = messageTagsToMap(
        messageTagsFromJsonList(
          payload['messageTags'] as List<dynamic>? ?? const [],
        ),
      );
      await _saveThreads(threads);
      await _saveMessageTags(tags);
      return MessagingLoadResult(
        threads: threads,
        tagsByMessageId: tags,
      );
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }
      final cached = _getCachedThreads();
      if (cached.isNotEmpty) {
        return MessagingLoadResult(
          threads: cached,
          tagsByMessageId: _getCachedMessageTags(),
        );
      }
      rethrow;
    }
  }

  Future<Map<String, Set<String>>> setMessageTags({
    required String messageId,
    required List<String> tags,
  }) async {
    final normalized = tags
        .map(normalizeMessageTag)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    try {
      final payload = await _apiClient.putJson(
        '/threads/messages/$messageId/tags',
        {'tags': normalized},
      );
      final updated = messageTagsToMap(
        messageTagsFromJsonList(
          payload['messageTags'] as List<dynamic>? ?? const [],
        ),
      );
      await _saveMessageTags(updated);
      return updated;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final cached = Map<String, Set<String>>.from(_getCachedMessageTags());
      if (normalized.isEmpty) {
        cached.remove(messageId);
      } else {
        cached[messageId] = normalized.toSet();
      }
      await _saveMessageTags(cached);
      return cached;
    }
  }

  Future<MessageThread> createThread({
    required String subject,
    required String category,
    String? childId,
  }) async {
    try {
      final payload = await _apiClient.postJson('/threads', {
        'subject': subject,
        'category': category,
        'childId': childId,
      });
      final thread = messageThreadFromJson(payload);
      await _upsertThread(thread);
      return thread;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final localThread = MessageThread(
        id: 'local_thread_${now.microsecondsSinceEpoch}',
        subject: subject,
        category: category,
        childId: childId,
        lastActivity: now,
        hasUnread: false,
        messages: const [],
      );

      await _upsertThread(localThread);
      await _offlineStore.appendPendingAction({
        'type': 'messaging.createThread',
        'createdAt': now.toIso8601String(),
        'payload': {
          'clientThreadId': localThread.id,
          'subject': subject,
          'category': category,
          'childId': childId,
        },
      });
      return localThread;
    }
  }

  Future<MessageThread> getOrCreateCategoryThread(String category) async {
    if (category == allTabLabel) {
      return _getOrCreateParentsInboxThread();
    }

    try {
      final payload = await _apiClient.postJson('/threads/channel', {
        'category': category,
      });
      final thread = messageThreadFromJson(payload);
      await _replaceChannelThreadInCache(thread);
      return thread;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final cached = _getCachedThreads();
      final offlineExisting = category == familyCategoryChannel
          ? findFamilyChannel(cached)
          : findCategoryChannel(cached, category);
      if (offlineExisting != null && !_isLocalThreadId(offlineExisting.id)) {
        return offlineExisting;
      }

      return createThread(subject: category, category: category);
    }
  }

  Future<void> _replaceChannelThreadInCache(MessageThread thread) async {
    final cachedThreads = _getCachedThreads()
      ..removeWhere(
        (item) => isSameManagedChannelThread(item, thread),
      );
    cachedThreads.insert(0, thread);
    cachedThreads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    await _saveThreads(cachedThreads);
  }

  Future<void> _removeThreadFromCache(String threadId) async {
    final cachedThreads = _getCachedThreads()
      ..removeWhere((item) => item.id == threadId);
    await _saveThreads(cachedThreads);
  }

  MessageThread? _findCachedThreadById(String threadId) {
    for (final thread in _getCachedThreads()) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  String? _inferChannelCategory(MessageThread thread) {
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

  Future<Map<String, dynamic>> _createThreadViaApi({
    required String subject,
    required String category,
    Object? childId,
  }) {
    if (subject == category) {
      if (category == allTabLabel || category == familyCategoryChannel) {
        return _apiClient.postJson('/threads/channel', {
          'category': category,
        });
      }
      if (messagingCategoryChannels.contains(category)) {
        return _apiClient.postJson('/threads/channel', {
          'category': category,
        });
      }
    }

    return _apiClient.postJson('/threads', {
      'subject': subject,
      'category': category,
      'childId': childId,
    });
  }

  bool _isLocalThreadId(String threadId) => threadId.startsWith('local_');

  Future<String> _resolveThreadIdForSend(
    String threadId, {
    String? channelCategory,
  }) async {
    if (channelCategory != null) {
      final channelThread = await getOrCreateCategoryThread(channelCategory);
      if (!_isLocalThreadId(channelThread.id)) {
        return channelThread.id;
      }
    }

    if (!_isLocalThreadId(threadId)) {
      return threadId;
    }

    if (_offlineStore.getPendingActions().isNotEmpty) {
      await syncPendingActions();
    }

    final mapped = _offlineStore.getMessagingThreadIdMap()[threadId];
    if (mapped != null && !_isLocalThreadId(mapped)) {
      return mapped;
    }

    final localThread = _findCachedThreadById(threadId);
    final category =
        localThread != null ? _inferChannelCategory(localThread) : null;
    if (category != null) {
      final thread = await getOrCreateCategoryThread(category);
      if (!_isLocalThreadId(thread.id)) {
        return thread.id;
      }
    }

    throw ApiException(404, 'thread_not_ready');
  }

  Future<MessageThread> _deliverMessageToThread({
    required String resolvedThreadId,
    required String originalThreadId,
    required String content,
    required MessageTone tone,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final payload = await _apiClient.postJson(
      '/threads/$resolvedThreadId/messages',
      {
        'content': content,
        'tone': messageToneToApi(tone),
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
    final thread = messageThreadFromJson(payload);
    if (_isLocalThreadId(originalThreadId) && thread.id != originalThreadId) {
      final cachedThreads = _getCachedThreads()
        ..removeWhere((item) => item.id == originalThreadId);
      await _saveThreads(cachedThreads);
      final map = Map<String, String>.from(
        _offlineStore.getMessagingThreadIdMap(),
      );
      map[originalThreadId] = thread.id;
      await _offlineStore.saveMessagingThreadIdMap(map);
    }
    await _upsertThread(thread);
    return thread;
  }

  Future<MessageThread> sendMessage({
    required String threadId,
    required String content,
    required MessageTone tone,
    List<Map<String, dynamic>> attachments = const [],
    String? channelCategory,
  }) async {
    final resolvedThreadId = await _resolveThreadIdForSend(
      threadId,
      channelCategory: channelCategory,
    );

    try {
      return await _deliverMessageToThread(
        resolvedThreadId: resolvedThreadId,
        originalThreadId: threadId,
        content: content,
        tone: tone,
        attachments: attachments,
      );
    } on ApiException catch (error) {
      if (channelCategory == null ||
          (error.statusCode != 403 && error.statusCode != 404)) {
        rethrow;
      }

      await _removeThreadFromCache(resolvedThreadId);

      final channelThread = await getOrCreateCategoryThread(channelCategory);
      if (_isLocalThreadId(channelThread.id)) {
        rethrow;
      }

      return await _deliverMessageToThread(
        resolvedThreadId: channelThread.id,
        originalThreadId: threadId,
        content: content,
        tone: tone,
        attachments: attachments,
      );
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final cachedThreads = _getCachedThreads();
      final threadIndex =
          cachedThreads.indexWhere((thread) => thread.id == resolvedThreadId);
      final optimisticMessage = Message(
        id: 'local_msg_${now.microsecondsSinceEpoch}',
        threadId: resolvedThreadId,
        senderId: 'local_user',
        senderName: 'Ty',
        content: content,
        tone: tone,
        attachments: attachments
            .map(
              (item) => MessageAttachment(
                id: item['id'] as String,
                name: item['name'] as String,
                type: item['type'] as String,
                sizeBytes: (item['sizeBytes'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
        sentAt: now,
        isDelivered: false,
        isRead: false,
        hash: 'pending_${now.microsecondsSinceEpoch}',
        isShielded: tone == MessageTone.aggressive,
      );

      late final MessageThread optimisticThread;
      if (threadIndex >= 0) {
        final existing = cachedThreads[threadIndex];
        optimisticThread = MessageThread(
          id: existing.id,
          subject: existing.subject,
          category: existing.category,
          childId: existing.childId,
          lastActivity: now,
          hasUnread: existing.hasUnread,
          messages: [...existing.messages, optimisticMessage],
        );
        cachedThreads[threadIndex] = optimisticThread;
      } else {
        optimisticThread = MessageThread(
          id: resolvedThreadId,
          subject: channelCategory ?? 'Nowy wątek',
          category: channelCategory ?? 'Ogólne',
          childId: null,
          lastActivity: now,
          hasUnread: false,
          messages: [optimisticMessage],
        );
        cachedThreads.insert(0, optimisticThread);
      }

      await _saveThreads(cachedThreads);
      await _offlineStore.appendPendingAction({
        'type': 'messaging.sendMessage',
        'createdAt': now.toIso8601String(),
        'payload': {
          'threadId': resolvedThreadId,
          'content': content,
          'tone': messageToneToApi(tone),
          if (attachments.isNotEmpty) 'attachments': attachments,
        },
      });

      return optimisticThread;
    }
  }

  Future<MessageThread> _getOrCreateParentsInboxThread() async {
    try {
      final payload = await _apiClient.postJson('/threads/channel', {
        'category': allTabLabel,
      });
      final thread = messageThreadFromJson(payload);
      await _replaceChannelThreadInCache(thread);
      return thread;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        try {
          final thread = await createThread(
            subject: allTabLabel,
            category: allTabLabel,
          );
          if (!_isLocalThreadId(thread.id)) {
            await _replaceChannelThreadInCache(thread);
          }
          return thread;
        } catch (_) {
          rethrow;
        }
      }

      final cached = _getCachedThreads();
      final offlineExisting = findCategoryChannel(cached, allTabLabel);
      if (offlineExisting != null && !_isLocalThreadId(offlineExisting.id)) {
        return offlineExisting;
      }

      return createThread(subject: allTabLabel, category: allTabLabel);
    }
  }

  Future<Map<String, dynamic>> downloadMessageAttachment({
    required String threadId,
    required String messageId,
    required String attachmentId,
  }) {
    return _apiClient.getJson(
      '/threads/$threadId/messages/$messageId/attachments/$attachmentId',
    );
  }

  Future<MessageThread?> markThreadRead(String threadId) async {
    try {
      final payload = await _apiClient.postJson('/threads/$threadId/read', {});
      final thread = messageThreadFromJson(payload);
      await _upsertThread(thread);
      return thread;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncPendingActions() async {
    final actions = _offlineStore.getPendingActions();
    if (actions.isEmpty) {
      return;
    }

    final cachedThreads = _getCachedThreads();
    final rewrittenQueue = <Map<String, dynamic>>[];
    final localThreadIdMap = Map<String, String>.from(
      _offlineStore.getMessagingThreadIdMap(),
    );
    var networkFailed = false;

    for (final action in actions) {
      final type = action['type'] as String? ?? '';
      if (!type.startsWith('messaging.')) {
        rewrittenQueue.add(action);
        continue;
      }

      if (networkFailed) {
        rewrittenQueue.add(action);
        continue;
      }

      try {
        switch (type) {
          case 'messaging.createThread':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _createThreadViaApi(
              subject: payload['subject'] as String,
              category: payload['category'] as String,
              childId: payload['childId'],
            );
            final createdThread = messageThreadFromJson(response);
            final clientThreadId = payload['clientThreadId'] as String;
            localThreadIdMap[clientThreadId] = createdThread.id;
            _replaceThreadId(cachedThreads, clientThreadId, createdThread);
            break;
          case 'messaging.sendMessage':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final requestedThreadId = payload['threadId'] as String;
            final resolvedThreadId = localThreadIdMap[requestedThreadId] ?? requestedThreadId;
            final response = await _apiClient.postJson(
              '/threads/$resolvedThreadId/messages',
              {
                'content': payload['content'],
                'tone': payload['tone'],
                if (payload['attachments'] != null)
                  'attachments': payload['attachments'],
              },
            );
            final updatedThread = messageThreadFromJson(response);
            _replaceThreadId(cachedThreads, resolvedThreadId, updatedThread);
            break;
          default:
            rewrittenQueue.add(action);
        }
      } on ApiException catch (error) {
        if (error.statusCode >= 500) {
          rethrow;
        }

        if (error.statusCode == 404 && type == 'messaging.sendMessage') {
          final payload = Map<String, dynamic>.from(action['payload'] as Map);
          final requestedThreadId = payload['threadId'] as String;
          final resolvedThreadId =
              localThreadIdMap[requestedThreadId] ?? requestedThreadId;
          if (requestedThreadId.startsWith('local_') &&
              resolvedThreadId == requestedThreadId) {
            rewrittenQueue.add(action);
            continue;
          }
        }

        rewrittenQueue.add(action);
      } catch (_) {
        networkFailed = true;
        rewrittenQueue.add(action);
      }
    }

    await _saveThreads(cachedThreads);
    await _offlineStore.saveMessagingThreadIdMap(localThreadIdMap);
    await _offlineStore.savePendingActions(rewrittenQueue);
  }

  List<MessageThread> _getCachedThreads() {
    return _offlineStore
        .getThreads()
        .map(messageThreadFromJson)
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  Future<void> _saveThreads(List<MessageThread> threads) {
    return _offlineStore.saveThreads(threads.map(messageThreadToJson).toList());
  }

  Future<void> _saveMessageTags(Map<String, Set<String>> tags) {
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

  Map<String, Set<String>> _getCachedMessageTags() {
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

  Future<void> _upsertThread(MessageThread thread) async {
    final cachedThreads = _getCachedThreads();
    final index = cachedThreads.indexWhere((item) => item.id == thread.id);
    if (index >= 0) {
      cachedThreads[index] = thread;
    } else {
      cachedThreads.insert(0, thread);
    }
    cachedThreads.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    await _saveThreads(cachedThreads);
  }

  void _replaceThreadId(
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
