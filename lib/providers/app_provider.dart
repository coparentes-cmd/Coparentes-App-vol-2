import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/country_profiles.dart';
import '../data/api/app_api_client.dart';
import '../data/models/auth_session.dart';
import '../data/repositories/auth_repository.dart';
import '../config/messaging_categories.dart';
import '../data/repositories/messaging_repository.dart';
import '../models/models.dart';
import '../utils/messaging_helpers.dart';

export 'calendar_provider.dart';
export 'finance_provider.dart';

// ─── Theme & Color Settings ───────────────────────────────────────────────────

enum AppColorScheme {
  teal,
  blue,
  purple,
  rose,
  amber,
  green,
}

extension AppColorSchemeExt on AppColorScheme {
  String get label {
    switch (this) {
      case AppColorScheme.teal:
        return 'Coparentes Green';
      case AppColorScheme.blue:
        return 'Electric Blue';
      case AppColorScheme.purple:
        return 'Lavender';
      case AppColorScheme.rose:
        return 'Coral';
      case AppColorScheme.amber:
        return 'Sun Yellow';
      case AppColorScheme.green:
        return 'Mint';
    }
  }

  Color get primary {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF00C896);
      case AppColorScheme.blue:
        return const Color(0xFF0080FF);
      case AppColorScheme.purple:
        return const Color(0xFF9C27B0);
      case AppColorScheme.rose:
        return const Color(0xFFFF6B68);
      case AppColorScheme.amber:
        return const Color(0xFFF4B400);
      case AppColorScheme.green:
        return const Color(0xFF63E0BC);
    }
  }

  Color get light {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF63E0BC);
      case AppColorScheme.blue:
        return const Color(0xFF5EA8FF);
      case AppColorScheme.purple:
        return const Color(0xFFC77DFF);
      case AppColorScheme.rose:
        return const Color(0xFFFF9D9B);
      case AppColorScheme.amber:
        return const Color(0xFFFDE47A);
      case AppColorScheme.green:
        return const Color(0xFFA8F0D3);
    }
  }

  Color get swatch {
    switch (this) {
      case AppColorScheme.teal:
        return const Color(0xFF00C896);
      case AppColorScheme.blue:
        return const Color(0xFF0080FF);
      case AppColorScheme.purple:
        return const Color(0xFF9C27B0);
      case AppColorScheme.rose:
        return const Color(0xFFFF6B68);
      case AppColorScheme.amber:
        return const Color(0xFFF4B400);
      case AppColorScheme.green:
        return const Color(0xFF63E0BC);
    }
  }
}

// ─── AppProvider ──────────────────────────────────────────────────────────────

class AppProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AppProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    unawaited(bootstrap());
  }

  AppUser? _currentUser;
  Workspace? _currentWorkspace;
  bool _highConflictMode = false;
  bool _aiCoachEnabled = true;
  bool _aiShieldEnabled = true;
  bool _isInitializing = true;
  bool _isDemoMode = false;
  bool _needsChildOnboarding = false;
  String? _authError;
  Locale _locale = const Locale('pl');
  CountryProfile _countryProfile = CountryProfiles.poland;

  // Theme & appearance
  ThemeMode _themeMode = ThemeMode.light;
  AppColorScheme _colorScheme = AppColorScheme.teal;

  // Notification preferences
  bool _notifyMessages = true;
  bool _notifyCalendar = true;
  bool _notifyFinance = true;
  bool _notifySwaps = true;

  // PIN lock setting
  bool _requirePinOnResume = true;

  // Language (placeholder for future)
  String _language = 'pl';

  // Getters
  AppUser? get currentUser => _currentUser;
  Workspace? get currentWorkspace => _currentWorkspace;
  bool get highConflictMode => _highConflictMode;
  bool get aiCoachEnabled => _aiCoachEnabled;
  bool get aiShieldEnabled => _aiShieldEnabled;
  ThemeMode get themeMode => _themeMode;
  AppColorScheme get colorScheme => _colorScheme;
  bool get notifyMessages => _notifyMessages;
  bool get notifyCalendar => _notifyCalendar;
  bool get notifyFinance => _notifyFinance;
  bool get notifySwaps => _notifySwaps;
  bool get requirePinOnResume => _requirePinOnResume;
  String get language => _language;
  bool get isInitializing => _isInitializing;
  bool get isDemoMode => _isDemoMode;
  bool get needsChildOnboarding => _needsChildOnboarding;
  String? get authError => _authError;
  Locale get locale => _locale;
  CountryProfile get countryProfile => _countryProfile;
  String get currencyCode => _countryProfile.currencyCode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Color get primaryColor => _colorScheme.primary;
  Color get primaryLight => _colorScheme.light;

  String _mapAuthError(Object error, {required String fallback}) {
    if (error is ApiException) {
      switch (error.message) {
        case 'email_in_use':
          return 'Ten e-mail jest już zarejestrowany. Spróbuj się zalogować.';
        case 'invalid_request':
          return 'Sprawdź dane: hasło min. 10 znaków, imię i nazwa przestrzeni min. 2 znaki.';
        case 'invalid_credentials':
          return 'Nieprawidłowy e-mail lub hasło.';
        case 'not_found':
          return 'Nie znaleziono API backendu. W Netlify ustaw COPARENTES_API_BASE_URL z końcówką /api.';
        case 'internal_server_error':
          return 'Błąd serwera podczas zapisu konta. Spróbuj ponownie za chwilę.';
        case 'invalid_invite':
          return 'Nieprawidłowy kod zaproszenia.';
        case 'cors_not_allowed':
          return 'Serwer odrzucił połączenie (CORS). Skontaktuj się z administratorem.';
        case 'Too many requests, try again later':
          return 'Zbyt wiele prób. Odczekaj kilka minut i spróbuj ponownie.';
        default:
          break;
      }

      if (error.statusCode == 429) {
        return 'Zbyt wiele prób. Odczekaj kilka minut i spróbuj ponownie.';
      }
      if (error.statusCode >= 500) {
        return 'Błąd serwera. Spróbuj ponownie za chwilę.';
      }
    }

    if (error is TimeoutException) {
      return 'Serwer nie odpowiada. Sprawdź internet i spróbuj ponownie.';
    }

    if (error is http.ClientException) {
      return 'Brak połączenia z serwerem API. Sprawdź Netlify → COPARENTES_API_BASE_URL.';
    }

    if (error is FormatException) {
      return 'Serwer zwrócił nieprawidłową odpowiedź. Sprawdź adres API (/api na końcu).';
    }

    return fallback;
  }

  Future<void> bootstrap() async {
    _isInitializing = true;
    notifyListeners();

    try {
      final session = await _authRepository.restoreSession();
      if (session != null) {
        _applySession(session);
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.login(
        email: email,
        password: password,
      );
      _isDemoMode = false;
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zalogować. Sprawdź dane i spróbuj ponownie.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.registerWorkspace(
        name: name,
        email: email,
        password: password,
        workspaceName: workspaceName,
      );
      _isDemoMode = false;
      _needsChildOnboarding = true;
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się utworzyć konta i workspace.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> addWorkspaceChild({
    required String name,
    required DateTime dateOfBirth,
    String? school,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.addWorkspaceChild(
        name: name,
        dateOfBirth: dateOfBirth,
        school: school,
      );
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = 'Nie udało się dodać dziecka.';
      notifyListeners();
      return false;
    }
  }

  void completeChildOnboarding() {
    _needsChildOnboarding = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    bool? highConflictMode,
    bool? twoFactorEnabled,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.updateProfile(
        name: name,
        highConflictMode: highConflictMode,
        twoFactorEnabled: twoFactorEnabled,
      );
      _applySession(session);
      notifyListeners();
      return true;
    } catch (_) {
      _authError = 'Nie udało się zaktualizować profilu.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _authError = null;
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (error) {
      _authError = error.statusCode == 401
          ? 'Aktualne hasło jest nieprawidłowe.'
          : 'Nie udało się zmienić hasła.';
      notifyListeners();
      return false;
    } catch (_) {
      _authError = 'Nie udało się zmienić hasła.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendEmailInvite(String email) async {
    try {
      _authError = null;
      await _authRepository.sendEmailInvite(email: email);
      return true;
    } on ApiException catch (error) {
      _authError = error.message == 'cannot_invite_self'
          ? 'Nie możesz zaprosić samego siebie.'
          : 'Nie udało się wysłać zaproszenia.';
      notifyListeners();
      return false;
    } catch (_) {
      _authError = 'Nie udało się wysłać zaproszenia.';
      notifyListeners();
      return false;
    }
  }

  Future<List<EmailInvite>> getSentEmailInvites() {
    return _authRepository.getSentEmailInvites();
  }

  Future<bool> joinWorkspace({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.joinWorkspace(
        name: name,
        email: email,
        password: password,
        inviteCode: inviteCode,
      );
      _isDemoMode = false;
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się dołączyć do workspace.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> enterDemoRole(UserRole role) async {
    _authError = null;
    _isDemoMode = true;

    final workspace = _buildDemoWorkspace();
    _currentWorkspace = workspace;
    _currentUser = _buildDemoUser(role);
    _highConflictMode = role == UserRole.parentB;

    notifyListeners();
  }

  // ── Toggles ────────────────────────────────────────────────────────────────

  Future<void> toggleHighConflictMode() async {
    final next = !_highConflictMode;
    if (_isDemoMode) {
      _highConflictMode = next;
      notifyListeners();
      return;
    }

    _highConflictMode = next;
    notifyListeners();

    final ok = await updateProfile(highConflictMode: next);
    if (!ok) {
      _highConflictMode = !next;
      notifyListeners();
    }
  }

  void toggleAiCoach() {
    _aiCoachEnabled = !_aiCoachEnabled;
    notifyListeners();
  }

  void toggleAiShield() {
    _aiShieldEnabled = !_aiShieldEnabled;
    notifyListeners();
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleDarkMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setColorScheme(AppColorScheme scheme) {
    _colorScheme = scheme;
    notifyListeners();
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  void setNotifyMessages(bool v) {
    _notifyMessages = v;
    notifyListeners();
  }

  void setNotifyCalendar(bool v) {
    _notifyCalendar = v;
    notifyListeners();
  }

  void setNotifyFinance(bool v) {
    _notifyFinance = v;
    notifyListeners();
  }

  void setNotifySwaps(bool v) {
    _notifySwaps = v;
    notifyListeners();
  }

  void setRequirePinOnResume(bool v) {
    _requirePinOnResume = v;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    _language = locale.languageCode;
    notifyListeners();
  }

  void setCountryProfile(String countryCode) {
    _countryProfile = CountryProfiles.byCode(countryCode);
    _locale = Locale(_countryProfile.languageCode);
    _language = _countryProfile.languageCode;
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void logout() {
    _currentUser = null;
    _currentWorkspace = null;
    _authError = null;
    _isDemoMode = false;
    _needsChildOnboarding = false;
    unawaited(_authRepository.logout());
    notifyListeners();
  }

  void _applySession(AuthSession session) {
    _currentUser = session.user;
    _currentWorkspace = session.workspace;
    _highConflictMode = session.user.highConflictMode;
  }

  Workspace _buildDemoWorkspace() {
    final createdAt = DateTime(2026, 1, 12, 9, 30);
    return Workspace(
      id: 'workspace_demo_001',
      name: 'Rodzina Kowalskich — demo',
      inviteCode: 'DEMO-2026',
      members: [
        AppUser(
          id: 'user_demo_parent_a',
          name: 'Anna Kowalska',
          email: 'anna.demo@coparentes.app',
          role: UserRole.parentA,
          createdAt: createdAt,
        ),
        AppUser(
          id: 'user_demo_parent_b',
          name: 'Marek Kowalski',
          email: 'marek.demo@coparentes.app',
          role: UserRole.parentB,
          highConflictMode: true,
          createdAt: createdAt,
        ),
      ],
      children: [
        ChildProfile(
          id: 'child_001',
          name: 'Zosia Kowalska',
          dateOfBirth: DateTime(2016, 4, 18),
          school: 'Szkoła Podstawowa nr 15',
        ),
        ChildProfile(
          id: 'child_002',
          name: 'Tomek Kowalski',
          dateOfBirth: DateTime(2013, 9, 7),
          school: 'Szkoła Podstawowa nr 15',
        ),
      ],
      createdAt: createdAt,
    );
  }

  AppUser _buildDemoUser(UserRole role) {
    final createdAt = DateTime(2026, 1, 12, 9, 30);
    switch (role) {
      case UserRole.parentA:
        return AppUser(
          id: 'user_demo_parent_a',
          name: 'Anna Kowalska',
          email: 'anna.demo@coparentes.app',
          role: UserRole.parentA,
          createdAt: createdAt,
        );
      case UserRole.parentB:
        return AppUser(
          id: 'user_demo_parent_b',
          name: 'Marek Kowalski',
          email: 'marek.demo@coparentes.app',
          role: UserRole.parentB,
          highConflictMode: true,
          createdAt: createdAt,
        );
      case UserRole.child:
        return AppUser(
          id: 'user_demo_child',
          name: 'Zosia',
          email: 'zosia.demo@coparentes.app',
          role: UserRole.child,
          createdAt: createdAt,
        );
      case UserRole.observer:
        return AppUser(
          id: 'user_demo_observer',
          name: 'Dr Marta Nowak',
          email: 'marta.demo@coparentes.app',
          role: UserRole.observer,
          createdAt: createdAt,
        );
    }
  }

  String _roleToApi(UserRole role) {
    switch (role) {
      case UserRole.parentA:
        return 'parentA';
      case UserRole.parentB:
        return 'parentB';
      case UserRole.child:
        return 'child';
      case UserRole.observer:
        return 'observer';
    }
  }
}

// ─── Messaging Provider ───────────────────────────────────────────────────────

class MessagingProvider extends ChangeNotifier {
  final MessagingRepository _repository;

  MessagingProvider({required MessagingRepository repository})
      : _repository = repository;

  final List<MessageThread> _threads = [];
  bool _isLoading = false;
  String? _error;
  bool _snapshotSeeded = false;
  final Map<String, Set<String>> _knownMessageIds = {};
  String? _pendingNewMessageAlert;

  List<MessageThread> get threads => _threads;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingNewMessageAlert => _pendingNewMessageAlert;

  void clearPendingNotification() {
    _pendingNewMessageAlert = null;
  }

  Future<void> loadThreads({
    String? viewerUserId,
    bool notifyEnabled = false,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final threads = await _repository.getThreads();

      if (!_snapshotSeeded) {
        syncKnownMessageIds(threads, _knownMessageIds);
        _snapshotSeeded = true;
      } else if (notifyEnabled && viewerUserId != null) {
        final incoming = findNewIncomingMessage(
          threads,
          viewerUserId,
          _knownMessageIds,
        );
        if (incoming != null) {
          _pendingNewMessageAlert = formatMessageNotification(incoming);
        }
        syncKnownMessageIds(threads, _knownMessageIds);
      } else {
        syncKnownMessageIds(threads, _knownMessageIds);
      }

      _threads
        ..clear()
        ..addAll(threads);
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
    final updated = await _repository.markThreadRead(threadId);
    if (updated != null) {
      final index = _threads.indexWhere((thread) => thread.id == threadId);
      if (index >= 0) {
        _threads[index] = updated;
      }
      syncKnownMessageIds(_threads, _knownMessageIds);
      notifyListeners();
      return;
    }

    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) {
      return;
    }

    final thread = _threads[index];
    final readMessages = thread.messages
        .map(
          (message) => message.senderId == viewerUserId
              ? message
              : Message(
                  id: message.id,
                  threadId: message.threadId,
                  senderId: message.senderId,
                  senderName: message.senderName,
                  content: message.content,
                  tone: message.tone,
                  attachments: message.attachments,
                  sentAt: message.sentAt,
                  isDelivered: message.isDelivered,
                  isRead: true,
                  hash: message.hash,
                  isShielded: message.isShielded,
                ),
        )
        .toList();

    _threads[index] = MessageThread(
      id: thread.id,
      subject: thread.subject,
      category: thread.category,
      childId: thread.childId,
      lastActivity: thread.lastActivity,
      hasUnread: false,
      messages: readMessages,
    );
    syncKnownMessageIds(_threads, _knownMessageIds);
    notifyListeners();
  }

  void initializeSampleData() {
    _threads.clear();
    _error = null;
    _isLoading = false;

    final now = DateTime.now();
    _threads.addAll([
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
    ]);
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
    return findCategoryThreadFallback(_threads, category);
  }

  Future<MessageThread?> openCategoryChannel(String category) async {
    final existing = findCategoryThreadFallback(_threads, category);
    if (existing != null) {
      return existing;
    }

    try {
      final thread = await _repository.getOrCreateCategoryThread(category);
      final index = _threads.indexWhere((item) => item.id == thread.id);
      if (index >= 0) {
        _threads[index] = thread;
      } else {
        _threads.insert(0, thread);
      }
      notifyListeners();
      return thread;
    } catch (_) {
      _error = 'Nie udało się otworzyć rozmowy tematycznej.';
      notifyListeners();
      return null;
    }
  }

  Future<MessageThread?> createThread({
    required String subject,
    required String category,
    String? childId,
  }) async {
    try {
      final thread = await _repository.createThread(
        subject: subject,
        category: category,
        childId: childId,
      );
      _threads.insert(0, thread);
      notifyListeners();
      return thread;
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
  }) async {
    try {
      final updatedThread = await _repository.sendMessage(
        threadId: threadId,
        content: content,
        tone: tone,
      );
      final index = _threads.indexWhere((thread) => thread.id == threadId);
      if (index >= 0) {
        _threads[index] = updatedThread;
      } else {
        _threads.insert(0, updatedThread);
      }

      final lastMessage = updatedThread.messages.isNotEmpty
          ? updatedThread.messages.last
          : null;
      if (lastMessage != null &&
          (lastMessage.id.startsWith('local_msg_') || !lastMessage.isDelivered)) {
        _error =
            'Wiadomość zapisana tylko na tym urządzeniu. Użyj „Synchronizuj” u góry ekranu.';
      }

      notifyListeners();
      return updatedThread;
    } catch (error) {
      _error = 'Nie udało się wysłać wiadomości.';
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
}



