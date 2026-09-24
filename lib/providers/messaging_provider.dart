import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/message_tags.dart';
import '../config/messaging_categories.dart';
import '../data/api/app_api_client.dart';
import '../data/repositories/messaging_repository.dart';
import '../l10n/demo_copy.dart';
import '../models/models.dart';
import '../services/e2e_crypto_service.dart';
import '../services/e2e_key_storage_service.dart';
import '../services/e2e_session_service.dart';
import '../utils/demo_time.dart';
import '../utils/messaging_helpers.dart';
import '../utils/swap_message_utils.dart';

class MessagingProvider extends ChangeNotifier {
  final MessagingRepository _repository;
  final E2eSessionService? _e2eSession;

  MessagingProvider({
    required MessagingRepository repository,
    E2eSessionService? e2eSessionService,
  })  : _repository = repository,
        _e2eSession = e2eSessionService;

  final List<MessageThread> _threads = [];
  final Map<String, Set<String>> _tagsByMessageId = {};
  bool _isLoading = false;
  String? _error;
  bool _snapshotSeeded = false;
  final Map<String, Set<String>> _knownMessageIds = {};
  String? _pendingNewMessageAlert;
  DateTime? _suppressRemoteLoadUntil;
  /// In-flight decrypt attempts (single-flight per message id).
  final Map<String, Future<String>> _decryptFutures = {};

  /// Successfully decrypted plaintext (separate from in-flight Futures).
  final Map<String, String> _decryptedCache = {};

  /// Drops in-flight and resolved decrypt caches (e.g. after E2E unlock).
  void clearDecryptCaches() {
    _decryptFutures.clear();
    _decryptedCache.clear();
    notifyListeners();
  }

  void suppressRemoteLoad([Duration duration = const Duration(seconds: 4)]) {
    _suppressRemoteLoadUntil = DateTime.now().add(duration);
  }

  List<MessageThread> get threads => _threads;
  Map<String, Set<String>> get tagsByMessageId => _tagsByMessageId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingNewMessageAlert => _pendingNewMessageAlert;

  void clearPendingNotification() {
    _pendingNewMessageAlert = null;
  }

  Set<String> tagsForMessage(String messageId) =>
      _tagsByMessageId[messageId] ?? const {};

  Set<String> get allUserTags => {
        for (final tags in _tagsByMessageId.values) ...tags,
      };

  List<MessageThread> get allTabThreads {
    final items = _threads.where(isAllTabThread).toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return items;
  }

  List<MessageThread> get customUserThreads {
    final items = _threads.where(isCustomUserThread).toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return items;
  }

  Future<void> setMessageTags({
    required String messageId,
    required List<String> tags,
    bool localOnly = false,
  }) async {
    final normalized = tags
        .map(normalizeMessageTag)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    suppressRemoteLoad();

    if (normalized.isEmpty) {
      _tagsByMessageId.remove(messageId);
    } else {
      _tagsByMessageId[messageId] = normalized.toSet();
    }
    notifyListeners();

    if (localOnly) {
      return;
    }

    try {
      final updated = await _repository.setMessageTags(
        messageId: messageId,
        tags: normalized,
      );
      _tagsByMessageId
        ..clear()
        ..addAll(updated);
      notifyListeners();
    } catch (error) {
      await loadThreads(silent: true);
      rethrow;
    }
  }

  Future<void> loadThreads({
    String? viewerUserId,
    bool notifyEnabled = false,
    bool silent = false,
  }) async {
    if (_suppressRemoteLoadUntil != null &&
        DateTime.now().isBefore(_suppressRemoteLoadUntil!)) {
      return;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _repository.getThreads();

      if (!_snapshotSeeded) {
        syncKnownMessageIds(result.threads, _knownMessageIds);
        _snapshotSeeded = true;
      } else if (notifyEnabled && viewerUserId != null) {
        final incoming = findNewIncomingMessage(
          result.threads,
          viewerUserId,
          _knownMessageIds,
        );
        if (incoming != null) {
          _pendingNewMessageAlert = formatMessageNotification(incoming);
        }
        syncKnownMessageIds(result.threads, _knownMessageIds);
      } else {
        syncKnownMessageIds(result.threads, _knownMessageIds);
      }

      final previousById = {
        for (final thread in _threads) thread.id: thread,
      };
      final merged = result.threads
          .map(
            (remote) => mergeThreadPreservingLocalReads(
              remote: remote,
              local: previousById[remote.id],
            ),
          )
          .toList();
      _threads
        ..clear()
        ..addAll(merged);
      _tagsByMessageId
        ..clear()
        ..addAll(result.tagsByMessageId);
    } catch (error) {
      if (!silent) {
        _error = 'Nie udało się pobrać wiadomości.';
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> markThreadRead(String threadId, {required String viewerUserId}) async {
    // Optimistically clear unread so Nieprzeczytane updates immediately and
    // a concurrent poll cannot resurrect stale unread flags.
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index >= 0) {
      final thread = _threads[index];
      final readMessages = thread.messages
          .map(
            (message) => message.senderId == viewerUserId
                ? message
                : message.copyWith(isRead: true),
          )
          .toList();
      _threads[index] = MessageThread(
        id: thread.id,
        subject: thread.subject,
        category: thread.category,
        childId: thread.childId,
        audience: thread.audience,
        lastActivity: thread.lastActivity,
        hasUnread: false,
        messages: readMessages,
      );
      syncKnownMessageIds(_threads, _knownMessageIds);
      notifyListeners();
    }

    suppressRemoteLoad(const Duration(seconds: 2));

    final updated = await _repository.markThreadRead(threadId);
    if (updated == null) {
      return;
    }

    final updatedIndex = _threads.indexWhere((thread) => thread.id == threadId);
    if (updatedIndex >= 0) {
      _threads[updatedIndex] = mergeThreadPreservingLocalReads(
        remote: updated,
        local: _threads[updatedIndex],
      );
    } else {
      _threads.insert(0, updated);
    }
    syncKnownMessageIds(_threads, _knownMessageIds);
    notifyListeners();
  }

  void initializeSampleData() {
    _threads.clear();
    _error = null;
    _isLoading = false;

    final now = DemoTime.now();
    _threads.addAll([
      MessageThread(
        id: 'thread_demo_all',
        subject: 'Wszystkie',
        category: 'Wszystkie',
        childId: null,
        lastActivity: now.subtract(const Duration(minutes: 30)),
        hasUnread: false,
        messages: const [],
      ),
      MessageThread(
        id: 'thread_demo_family',
        subject: 'Rodzina',
        category: 'Rodzina',
        audience: 'family',
        childId: null,
        lastActivity: now.subtract(const Duration(hours: 1)),
        hasUnread: false,
        messages: [
          Message(
            id: 'msg_demo_family_001',
            threadId: 'thread_demo_family',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content: 'Pamietajcie o kolacji o 18:30!',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 1)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_family_001',
          ),
        ],
      ),
      MessageThread(
        id: 'thread_demo_schedule',
        subject: 'Zmiana grafiku',
        category: 'Zmiana grafiku',
        childId: null,
        lastActivity: now.subtract(const Duration(hours: 3)),
        hasUnread: false,
        messages: const [],
      ),
      MessageThread(
        id: 'thread_demo_001',
        subject: 'Angielski – zmiana terminu',
        category: 'Szkoła',
        childId: 'child_001',
        lastActivity: now.subtract(const Duration(hours: 2)),
        hasUnread: true,
        messages: [
          Message(
            id: 'msg_demo_001',
            threadId: 'thread_demo_001',
            senderId: 'user_demo_parent_b',
            senderName: 'Marek Kowalski',
            content: 'Czy mozemy przeniesc angielski z wtorku na srode o 17:00?',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 2)),
            isDelivered: true,
            isRead: false,
            hash: 'sha256_msg_demo_001',
          ),
        ],
      ),
      MessageThread(
        id: 'thread_demo_002',
        subject: 'Wizyta u dentysty – Zosia',
        category: 'Zdrowie',
        childId: 'child_001',
        lastActivity: now.subtract(const Duration(days: 1)),
        hasUnread: false,
        messages: [
          Message(
            id: 'msg_demo_002',
            threadId: 'thread_demo_002',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content: 'Potwierdzam wizyte w piatek o 10:30. Dolozylam paragon do finansow.',
            tone: MessageTone.positive,
            attachments: const [],
            sentAt: now.subtract(const Duration(days: 1)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_002',
          ),
        ],
      ),
      MessageThread(
        id: 'thread_demo_vacations',
        subject: 'Wakacje',
        category: 'Wszystkie',
        childId: 'child_001',
        lastActivity: now.subtract(const Duration(hours: 5)),
        hasUnread: true,
        messages: [
          Message(
            id: 'msg_demo_vacations_001',
            threadId: 'thread_demo_vacations',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content:
                'Proponuję wyjazd nad morze w pierwszym tygodniu sierpnia. Co myślisz?',
            tone: MessageTone.positive,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 6)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_vacations_001',
          ),
          Message(
            id: 'msg_demo_vacations_002',
            threadId: 'thread_demo_vacations',
            senderId: 'user_demo_parent_b',
            senderName: 'Marek Kowalski',
            content:
                'Pasuje mi 3–10 sierpnia. Mogę zabrać dzieci na drogę w sobotę rano.',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 5)),
            isDelivered: true,
            isRead: false,
            hash: 'sha256_msg_demo_vacations_002',
          ),
        ],
      ),
      MessageThread(
        id: 'thread_demo_school_year',
        subject: 'Początek roku szkolnego',
        category: 'Szkoła',
        childId: 'child_001',
        lastActivity: now.subtract(const Duration(hours: 8)),
        hasUnread: false,
        messages: [
          Message(
            id: 'msg_demo_school_year_001',
            threadId: 'thread_demo_school_year',
            senderId: 'user_demo_parent_b',
            senderName: 'Marek Kowalski',
            content:
                'We wrześniu zaczyna się nowy rok. Ustalmy, kto kupuje wyprawkę i kto idzie na rozpoczęcie.',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 10)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_school_year_001',
          ),
          Message(
            id: 'msg_demo_school_year_002',
            threadId: 'thread_demo_school_year',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content:
                'Ja biorę wyprawkę Zosi, Ty Tomka. Na rozpoczęcie idę z Zosią — OK?',
            tone: MessageTone.positive,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 8)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_school_year_002',
          ),
        ],
      ),
    ]);
    notifyListeners();
  }

  /// Updates only the original demo thread/message ids. Session threads stay.
  void localizeDemoSeed(String languageCode) {
    var changed = false;
    for (var i = 0; i < _threads.length; i++) {
      final thread = _threads[i];
      if (!DemoCopy.isDemoThread(thread.id)) {
        continue;
      }
      final subject =
          DemoCopy.threadSubject(thread.id, languageCode) ?? thread.subject;
      final messages = thread.messages.map((message) {
        final content =
            DemoCopy.messageContent(message.id, languageCode) ?? message.content;
        if (content == message.content) {
          return message;
        }
        return message.copyWith(content: content);
      }).toList();
      final messagesChanged = messages.asMap().entries.any(
            (entry) => entry.value.content != thread.messages[entry.key].content,
          );
      if (subject == thread.subject && !messagesChanged) {
        continue;
      }
      _threads[i] = MessageThread(
        id: thread.id,
        subject: subject,
        category: thread.category,
        messages: messages,
        lastActivity: thread.lastActivity,
        hasUnread: thread.hasUnread,
        childId: thread.childId,
        audience: thread.audience,
      );
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void initializeChildSampleData() {
    _threads.clear();
    _error = null;
    _isLoading = false;

    final now = DateTime.now();
    _threads.add(
      MessageThread(
        id: 'thread_demo_family',
        subject: 'Rodzina',
        category: 'Rodzina',
        audience: 'family',
        childId: null,
        lastActivity: now.subtract(const Duration(hours: 1)),
        hasUnread: false,
        messages: [
          Message(
            id: 'msg_demo_family_001',
            threadId: 'thread_demo_family',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content: 'Pamietajcie o kolacji o 18:30!',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: now.subtract(const Duration(hours: 1)),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_demo_family_001',
          ),
        ],
      ),
    );
    notifyListeners();
  }

  MessageThread? getThreadById(String threadId) {
    try {
      return _threads.firstWhere((thread) => thread.id == threadId);
    } catch (_) {
      return null;
    }
  }

  MessageThread? getCategoryChannel(String category) {
    if (category == familyCategoryChannel) {
      return findFamilyChannel(_threads);
    }
    if (category == allTabLabel) {
      return findCategoryChannel(_threads, allTabLabel);
    }
    return findCategoryThreadFallback(_threads, category);
  }

  Future<MessageThread?> openCategoryChannel(
    String category, {
    List<String> parentUserIds = const [],
  }) async {
    final cached = getCategoryChannel(category);
    if (cached != null) {
      return cached;
    }

    try {
      final threadKeys = await _threadKeysForCategory(
        category,
        parentUserIds: parentUserIds,
      );
      final thread = await _repository.getOrCreateCategoryThread(
        category,
        threadKeys: threadKeys,
      );
      final index = _threads.indexWhere(
        (item) => isSameManagedChannelThread(item, thread),
      );
      if (index >= 0) {
        _threads[index] = thread;
      } else {
        _threads.insert(0, thread);
      }
      notifyListeners();
      return thread;
    } on IncompleteParticipantKeysException catch (error) {
      debugPrint(
        '[e2e] openCategoryChannel incomplete keys for $category: $error',
      );
      _error =
          'Nie można teraz otworzyć rozmowy — brakuje kluczy szyfrowania u uczestników. Spróbuj ponownie później.';
      notifyListeners();
      return null;
    } catch (error) {
      _error = 'Nie udało się otworzyć rozmowy tematycznej.';
      notifyListeners();
      return null;
    }
  }

  Future<MessageThread?> createThread({
    required String subject,
    required String category,
    String? childId,
    bool localOnly = false,
    List<String> parentUserIds = const [],
  }) async {
    if (localOnly) {
      final now = DateTime.now();
      final thread = MessageThread(
        id: 'thread_demo_${now.microsecondsSinceEpoch}',
        subject: subject,
        category: category,
        childId: childId,
        lastActivity: now,
        hasUnread: false,
        messages: const [],
      );
      _threads.insert(0, thread);
      notifyListeners();
      return thread;
    }

    try {
      final threadKeys = await _requireThreadKeys(parentUserIds);
      final thread = await _repository.createThread(
        subject: subject,
        category: category,
        childId: childId,
        threadKeys: threadKeys,
      );
      final index = _threads.indexWhere((item) => item.id == thread.id);
      if (index >= 0) {
        _threads[index] = thread;
      } else {
        _threads.insert(0, thread);
      }
      notifyListeners();
      await loadThreads(silent: true);
      return getThreadById(thread.id) ?? thread;
    } on IncompleteParticipantKeysException catch (error) {
      debugPrint('[e2e] createThread incomplete keys: $error');
      _error =
          'Nie można teraz utworzyć wątku — brakuje kluczy szyfrowania u uczestników. Spróbuj ponownie później.';
      notifyListeners();
      return null;
    } catch (error) {
      _error = 'Nie udało się utworzyć wątku.';
      notifyListeners();
      return null;
    }
  }

  Future<MessageThread?> sendMessage({
    required String threadId,
    required String content,
    required MessageTone tone,
    List<Map<String, dynamic>> attachments = const [],
    String? channelCategory,
    bool localOnly = false,
    AppUser? demoSender,
    List<String> parentUserIds = const [],
  }) async {
    if (localOnly) {
      final sender = demoSender;
      if (sender == null) {
        _error = 'Nie udało się wysłać wiadomości.';
        notifyListeners();
        return null;
      }
      return _appendLocalDemoMessage(
        threadId: threadId,
        channelCategory: channelCategory,
        content: content,
        tone: tone,
        sender: sender,
      );
    }

    try {
      final threadKeys = channelCategory == null
          ? null
          : await _threadKeysForCategory(
              channelCategory,
              parentUserIds: parentUserIds,
            );
      final updatedThread = await _repository.sendMessage(
        threadId: threadId,
        content: content,
        tone: tone,
        attachments: attachments,
        channelCategory: channelCategory,
        threadKeys: threadKeys,
      );
      // Just-sent outgoing messages must stay unread until the other parent
      // opens the thread — never trust a premature isRead on the send response.
      final sanitized = _withOutgoingSendUnread(updatedThread);
      if (threadId != sanitized.id) {
        _threads.removeWhere((thread) => thread.id == threadId);
      }
      final index =
          _threads.indexWhere((thread) => thread.id == sanitized.id);
      if (index >= 0) {
        _threads[index] = sanitized;
      } else {
        _threads.insert(0, sanitized);
      }

      final lastMessage = sanitized.messages.isNotEmpty
          ? sanitized.messages.last
          : null;
      if (lastMessage != null &&
          (lastMessage.id.startsWith('local_msg_') || !lastMessage.isDelivered)) {
        _error =
            'Wiadomość zapisana tylko na tym urządzeniu. Użyj „Synchronizuj” u góry ekranu.';
      } else {
        _error = null;
      }

      suppressRemoteLoad();
      notifyListeners();
      return sanitized;
    } catch (error) {
      _error = _mapSendMessageError(error);
      notifyListeners();
      return null;
    }
  }

  /// Send response can race with the other parent's mark-as-read; the message
  /// that was just created in this request must still show as unread locally.
  MessageThread _withOutgoingSendUnread(MessageThread thread) {
    if (thread.messages.isEmpty) {
      return thread;
    }
    final last = thread.messages.last;
    if (!last.isRead) {
      return thread;
    }
    final messages = [
      ...thread.messages.sublist(0, thread.messages.length - 1),
      last.copyWith(isRead: false),
    ];
    return MessageThread(
      id: thread.id,
      subject: thread.subject,
      category: thread.category,
      childId: thread.childId,
      audience: thread.audience,
      lastActivity: thread.lastActivity,
      hasUnread: thread.hasUnread,
      messages: messages,
    );
  }

  String _mapSendMessageError(Object error) {
    if (error is NoUnlockedKeyException) {
      return 'Odblokuj szyfrowanie czatu, żeby wysłać wiadomość.';
    }
    if (error is IncompleteParticipantKeysException) {
      debugPrint('[e2e] sendMessage incomplete keys: $error');
      return 'Nie można teraz wysłać wiadomości — brakuje kluczy szyfrowania u uczestników. Spróbuj ponownie później.';
    }
    if (error is MessageDecryptionException ||
        error is SealedBoxDecryptionException) {
      return 'Nie udało się zaszyfrować wiadomości. Spróbuj ponownie.';
    }
    if (error is ApiException) {
      switch (error.message) {
        case 'missing_token':
        case 'invalid_session':
        case 'invalid_token':
          return 'Sesja wygasła. Zaloguj się ponownie.';
        case 'forbidden':
          return 'Brak uprawnień do wysłania wiadomości w tym kanale.';
        case 'internal_server_error':
          return 'Błąd serwera podczas wysyłania. Spróbuj ponownie za chwilę.';
        case 'encryption_not_configured':
          return 'Serwer nie ma skonfigurowanego szyfrowania wiadomości. Skontaktuj się z administratorem.';
        case 'thread_not_ready':
        case 'thread_not_found':
          return 'Nie udało się połączyć z rozmową. Odśwież wiadomości (Synchronizuj).';
        case 'message_empty':
          return 'Wiadomość jest pusta.';
        case 'invalid_request':
          return 'Nieprawidłowe dane wiadomości. Odśwież ekran i spróbuj ponownie.';
        default:
          break;
      }
    }
    return 'Nie udało się wysłać wiadomości.';
  }

  /// System schedule channel has no E2E threadKeys; all other creates need parents.
  Future<List<Map<String, String>>?> _threadKeysForCategory(
    String category, {
    required List<String> parentUserIds,
  }) async {
    if (category == scheduleCategoryChannel) {
      return null;
    }
    return _requireThreadKeys(parentUserIds);
  }

  Future<List<Map<String, String>>> _requireThreadKeys(
    List<String> parentUserIds,
  ) async {
    final e2e = _e2eSession;
    if (e2e == null) {
      throw IncompleteParticipantKeysException(
        missingKey: parentUserIds,
        failed: const {},
      );
    }
    return e2e.buildThreadKeysPayload(participantUserIds: parentUserIds);
  }

  /// Decrypts an E2E message body for UI (bubble / previews).
  Future<String> decryptMessageBody(Message message) async {
    if (!message.needsDecryption) {
      return message.content;
    }

    // Resolved success cache — keep separate from in-flight Futures.
    final cached = _decryptedCache[message.id];
    if (cached != null) return cached;

    return _decryptFutures.putIfAbsent(message.id, () async {
      try {
        final e2e = _e2eSession;
        if (e2e == null) {
          throw MessageDecryptionException('e2e_unavailable');
        }
        final result = await e2e.decryptMessageFromThread(
          threadId: message.threadId,
          ciphertext: message.ciphertext!,
          nonce: message.nonce!,
        );
        _decryptedCache[message.id] = result;
        return result;
      } catch (error) {
        // Allow a later call to retry instead of replaying a failed Future.
        _decryptFutures.remove(message.id);
        rethrow;
      }
    });
  }

  MessageThread? _appendLocalDemoMessage({
    required String threadId,
    required String content,
    required MessageTone tone,
    required AppUser sender,
    String? channelCategory,
  }) {
    final now = DateTime.now();
    var resolvedThreadId = threadId;
    if (channelCategory != null) {
      final channel = getCategoryChannel(channelCategory);
      if (channel != null) {
        resolvedThreadId = channel.id;
      }
    }

    final message = Message(
      id: 'msg_demo_${now.microsecondsSinceEpoch}',
      threadId: resolvedThreadId,
      senderId: sender.id,
      senderName: sender.name.split(' ').first,
      content: content,
      tone: tone,
      attachments: const [],
      sentAt: now,
      isDelivered: true,
      isRead: false,
      hash: 'sha256_demo_${now.microsecondsSinceEpoch}',
    );

    final index = _threads.indexWhere((thread) => thread.id == resolvedThreadId);
    if (index < 0) {
      _error = 'Nie udało się wysłać wiadomości.';
      notifyListeners();
      return null;
    }

    final thread = _threads[index];
    final updatedThread = MessageThread(
      id: thread.id,
      subject: thread.subject,
      category: thread.category,
      childId: thread.childId,
      audience: thread.audience,
      lastActivity: now,
      hasUnread: thread.hasUnread,
      messages: [...thread.messages, message],
    );
    _threads[index] = updatedThread;
    _error = null;
    notifyListeners();
    return updatedThread;
  }

  Future<Map<String, dynamic>?> downloadMessageAttachment({
    required String threadId,
    required String messageId,
    required String attachmentId,
  }) async {
    try {
      return await _repository.downloadMessageAttachment(
        threadId: threadId,
        messageId: messageId,
        attachmentId: attachmentId,
      );
    } catch (_) {
      _error = 'Nie udało się pobrać załącznika.';
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _threads.clear();
    _error = null;
    _isLoading = false;
    _snapshotSeeded = false;
    _knownMessageIds.clear();
    _pendingNewMessageAlert = null;
    notifyListeners();
  }

  void appendDemoScheduleProposal({
    required CustodySchedule schedule,
    required AppUser sender,
  }) {
    const category = 'Zmiana grafiku';
    final start =
        '${schedule.startDate.day.toString().padLeft(2, '0')}.${schedule.startDate.month.toString().padLeft(2, '0')}.${schedule.startDate.year}';
    final end = schedule.endDate;
    final rangeLabel = end == null
        ? 'od $start'
        : '$start – ${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}';

    final content = [
      scheduleProposalMessageHeader,
      '',
      'Szablon: ${schedule.patternLabel}',
      'Obowiązuje: $rangeLabel',
      if (schedule.handoverTime != null)
        'Przekazanie: ${schedule.handoverTime}',
      if (schedule.handoverLocation != null)
        'Miejsce: ${schedule.handoverLocation}',
      '',
      'Zaakceptuj lub odrzuć w Kalendarzu lub w czacie Zmiana grafiku.',
    ].join('\n');

    final now = DateTime.now();
    final message = Message(
      id: 'msg_demo_schedule_${now.microsecondsSinceEpoch}',
      threadId: 'thread_demo_schedule',
      senderId: sender.id,
      senderName: sender.name,
      content: content,
      tone: MessageTone.neutral,
      attachments: const [],
      sentAt: now,
      isDelivered: true,
      isRead: false,
      hash: 'sha256_demo_schedule_${now.microsecondsSinceEpoch}',
    );

    final index = _threads.indexWhere((thread) => thread.category == category);
    if (index >= 0) {
      final thread = _threads[index];
      _threads[index] = MessageThread(
        id: thread.id,
        subject: thread.subject,
        category: thread.category,
        childId: thread.childId,
        lastActivity: now,
        hasUnread: true,
        messages: [...thread.messages, message],
      );
    } else {
      _threads.insert(
        0,
        MessageThread(
          id: 'thread_demo_schedule',
          subject: 'Grafik opieki',
          category: category,
          lastActivity: now,
          hasUnread: true,
          messages: [message],
        ),
      );
    }
    notifyListeners();
  }
}
