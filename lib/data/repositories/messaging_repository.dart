import '../../config/messaging_categories.dart';
import '../../config/message_tags.dart';
import '../../models/models.dart';
import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../serializers/api_serializers.dart';
import 'messaging_local_cache.dart';
import 'messaging_remote.dart';

class MessagingLoadResult {
  final List<MessageThread> threads;
  final Map<String, Set<String>> tagsByMessageId;

  const MessagingLoadResult({
    required this.threads,
    required this.tagsByMessageId,
  });
}

class MessagingRepository {
  final MessagingRemote _remote;
  final MessagingLocalCache _cache;
  final OfflineStore _offlineStore;

  MessagingRepository({
    required AppApiClient apiClient,
    required OfflineStore offlineStore,
  })  : _remote = MessagingRemote(apiClient: apiClient),
        _cache = MessagingLocalCache(offlineStore: offlineStore),
        _offlineStore = offlineStore;

  Future<MessagingLoadResult> getThreads() async {
    if (_offlineStore.getPendingActions().isNotEmpty) {
      await syncPendingActions();
    }

    try {
      final result = await _remote.fetchThreads();
      await _cache.saveThreads(result.threads);
      await _cache.saveMessageTags(result.tags);
      return MessagingLoadResult(
        threads: result.threads,
        tagsByMessageId: result.tags,
      );
    } catch (error) {
      if (!_remote.isNetworkError(error)) {
        rethrow;
      }
      final cached = _cache.getCachedThreads();
      if (cached.isNotEmpty) {
        return MessagingLoadResult(
          threads: cached,
          tagsByMessageId: _cache.getCachedMessageTags(),
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
      final updated = await _remote.updateMessageTags(
        messageId: messageId,
        tags: normalized,
      );
      await _cache.saveMessageTags(updated);
      return updated;
    } catch (error) {
      if (!_remote.isNetworkError(error)) {
        rethrow;
      }

      final cached = Map<String, Set<String>>.from(_cache.getCachedMessageTags());
      if (normalized.isEmpty) {
        cached.remove(messageId);
      } else {
        cached[messageId] = normalized.toSet();
      }
      await _cache.saveMessageTags(cached);
      return cached;
    }
  }

  Future<MessageThread> createThread({
    required String subject,
    required String category,
    String? childId,
  }) async {
    try {
      final thread = await _remote.createThread(
        subject: subject,
        category: category,
        childId: childId,
      );
      await _cache.upsertThread(thread);
      return thread;
    } catch (error) {
      if (!_remote.isNetworkError(error)) {
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

      await _cache.upsertThread(localThread);
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

    final cachedThread = _cache.findCachedCategoryThread(category);
    if (cachedThread != null) {
      return cachedThread;
    }

    try {
      final thread = await _remote.createChannel(category: category);
      await _cache.replaceChannelThreadInCache(thread);
      return thread;
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        final fallback = _cache.findCachedCategoryThread(category);
        if (fallback != null) {
          return fallback;
        }
      }
      if (!_remote.isNetworkError(error)) {
        rethrow;
      }

      final cached = _cache.getCachedThreads();
      final offlineExisting = category == familyCategoryChannel
          ? findFamilyChannel(cached)
          : findCategoryChannel(cached, category);
      if (offlineExisting != null && !_cache.isLocalThreadId(offlineExisting.id)) {
        return offlineExisting;
      }

      return createThread(subject: category, category: category);
    } catch (error) {
      if (!_remote.isNetworkError(error)) {
        rethrow;
      }

      final cached = _cache.getCachedThreads();
      final offlineExisting = category == familyCategoryChannel
          ? findFamilyChannel(cached)
          : findCategoryChannel(cached, category);
      if (offlineExisting != null && !_cache.isLocalThreadId(offlineExisting.id)) {
        return offlineExisting;
      }

      return createThread(subject: category, category: category);
    }
  }

  Future<String> _resolveThreadIdForSend(
    String threadId, {
    String? channelCategory,
  }) async {
    if (channelCategory != null) {
      final channelThread = await getOrCreateCategoryThread(channelCategory);
      if (!_cache.isLocalThreadId(channelThread.id)) {
        return channelThread.id;
      }
    }

    if (!_cache.isLocalThreadId(threadId)) {
      return threadId;
    }

    if (_offlineStore.getPendingActions().isNotEmpty) {
      await syncPendingActions();
    }

    final mapped = _offlineStore.getMessagingThreadIdMap()[threadId];
    if (mapped != null && !_cache.isLocalThreadId(mapped)) {
      return mapped;
    }

    final localThread = _cache.findCachedThreadById(threadId);
    final category =
        localThread != null ? _cache.inferChannelCategory(localThread) : null;
    if (category != null) {
      final thread = await getOrCreateCategoryThread(category);
      if (!_cache.isLocalThreadId(thread.id)) {
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
    final thread = await _remote.sendMessage(
      threadId: resolvedThreadId,
      content: content,
      tone: tone,
      attachments: attachments,
    );
    if (_cache.isLocalThreadId(originalThreadId) && thread.id != originalThreadId) {
      final cachedThreads = _cache.getCachedThreads()
        ..removeWhere((item) => item.id == originalThreadId);
      await _cache.saveThreads(cachedThreads);
      final map = Map<String, String>.from(
        _offlineStore.getMessagingThreadIdMap(),
      );
      map[originalThreadId] = thread.id;
      await _offlineStore.saveMessagingThreadIdMap(map);
    }
    await _cache.upsertThread(thread);
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

      await _cache.removeThreadFromCache(resolvedThreadId);

      final channelThread = await getOrCreateCategoryThread(channelCategory);
      if (_cache.isLocalThreadId(channelThread.id)) {
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
      if (!_remote.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final cachedThreads = _cache.getCachedThreads();
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

      await _cache.saveThreads(cachedThreads);
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
      final thread = await _remote.createChannel(category: allTabLabel);
      await _cache.replaceChannelThreadInCache(thread);
      return thread;
    } catch (error) {
      if (!_remote.isNetworkError(error)) {
        try {
          final thread = await createThread(
            subject: allTabLabel,
            category: allTabLabel,
          );
          if (!_cache.isLocalThreadId(thread.id)) {
            await _cache.replaceChannelThreadInCache(thread);
          }
          return thread;
        } catch (_) {
          rethrow;
        }
      }

      final cached = _cache.getCachedThreads();
      final offlineExisting = findCategoryChannel(cached, allTabLabel);
      if (offlineExisting != null && !_cache.isLocalThreadId(offlineExisting.id)) {
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
    return _remote.downloadMessageAttachment(
      threadId: threadId,
      messageId: messageId,
      attachmentId: attachmentId,
    );
  }

  Future<MessageThread?> markThreadRead(String threadId) async {
    try {
      final thread = await _remote.markThreadRead(threadId);
      await _cache.upsertThread(thread);
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

    final cachedThreads = _cache.getCachedThreads();
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
            final response = await _remote.createThreadViaApi(
              subject: payload['subject'] as String,
              category: payload['category'] as String,
              childId: payload['childId'],
            );
            final createdThread = messageThreadFromJson(response);
            final clientThreadId = payload['clientThreadId'] as String;
            localThreadIdMap[clientThreadId] = createdThread.id;
            _cache.replaceThreadId(cachedThreads, clientThreadId, createdThread);
            break;
          case 'messaging.sendMessage':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final requestedThreadId = payload['threadId'] as String;
            final resolvedThreadId = localThreadIdMap[requestedThreadId] ?? requestedThreadId;
            final updatedThread = await _remote.sendMessageWithApiTone(
              threadId: resolvedThreadId,
              content: payload['content'] as String,
              tone: payload['tone'] as String,
              attachments: payload['attachments'] != null
                  ? List<Map<String, dynamic>>.from(
                      payload['attachments'] as List,
                    )
                  : const [],
            );
            _cache.replaceThreadId(cachedThreads, resolvedThreadId, updatedThread);
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

    await _cache.saveThreads(cachedThreads);
    await _offlineStore.saveMessagingThreadIdMap(localThreadIdMap);
    await _offlineStore.savePendingActions(rewrittenQueue);
  }
}
