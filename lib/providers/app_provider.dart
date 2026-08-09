import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;

import '../config/country_profiles.dart';
import '../data/api/app_api_client.dart';
import '../data/models/auth_session.dart';
import '../data/models/login_challenge.dart';
import '../data/local/pin_lock_store.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/consent_repository.dart';
import '../data/models/user_consent.dart';
import '../models/models.dart';

export 'calendar_provider.dart';
export 'finance_provider.dart';
export 'messaging_provider.dart';

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
  final ConsentRepository _consentRepository;
  final PinLockStore _pinLockStore;

  AppProvider({
    required AuthRepository authRepository,
    required ConsentRepository consentRepository,
    required PinLockStore pinLockStore,
  })  : _authRepository = authRepository,
        _consentRepository = consentRepository,
        _pinLockStore = pinLockStore {
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
  LoginChallenge? _pendingLoginChallenge;
  int? _otpAttemptsRemaining;
  bool _otpLocked = false;
  List<UserConsentRecord>? _userConsents;
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
  bool _requirePinOnResume = false;
  bool _hasPinSet = false;
  bool _isPinLocked = false;

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
  bool get hasPinSet => _hasPinSet;
  bool get isPinLocked => _isPinLocked;
  String get language => _language;
  bool get isInitializing => _isInitializing;
  bool get isDemoMode => _isDemoMode;
  bool get needsChildOnboarding => _needsChildOnboarding;
  String? get authError => _authError;
  LoginChallenge? get pendingLoginChallenge => _pendingLoginChallenge;
  bool get needsOtpVerification => _pendingLoginChallenge != null;
  int? get otpAttemptsRemaining => _otpAttemptsRemaining;
  bool get otpLocked => _otpLocked;
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
        case 'required_consents_missing':
          return 'Zaakceptuj wszystkie wymagane zgody, aby dokończyć rejestrację.';
        case 'required_consent_locked':
          return 'Ta zgoda jest wymagana do korzystania z aplikacji.';
        case 'invalid_credentials':
          return 'Nieprawidłowy e-mail lub hasło.';
        case 'invalid_otp':
          return 'Nieprawidłowy kod weryfikacyjny.';
        case 'otp_expired':
          return 'Kod wygasł. Poproś o nowy kod.';
        case 'otp_locked':
          return 'Zbyt wiele prób. Poproś o nowy kod.';
        case 'otp_email_failed':
          return 'Nie udało się wysłać kodu e-mail. Sprawdź konfigurację poczty lub wyłącz 2FA w Ustawieniach.';
        case 'resend_cooldown':
          return 'Poczekaj chwilę przed ponownym wysłaniem kodu.';
        case 'not_found':
          return 'Nie znaleziono API backendu. W Netlify ustaw COPARENTES_API_BASE_URL z końcówką /api.';
        case 'internal_server_error':
          return 'Błąd serwera podczas zapisu konta. Spróbuj ponownie za chwilę.';
        case 'invalid_invite':
          return 'Nieprawidłowy kod zaproszenia.';
        case 'invite_expired':
          return 'Kod zaproszenia wygasł. Poproś drugiego rodzica o nowy kod w Ustawieniach.';
        case 'parent_already_joined':
          return 'Drugi rodzic dołączył już do tej rodziny.';
        case 'child_not_found':
          return 'Nie znaleziono profilu dziecka dla tej daty urodzenia.';
        case 'ambiguous_child_profile':
          return 'Kilka profili ma tę samą datę urodzenia. Poproś rodzica o pomoc.';
        case 'child_name_required':
          return 'Podaj imię — jest wymagane przy pierwszym logowaniu.';
        case 'child_profile_taken':
          return 'Ten profil ma już konto. Zaloguj się hasłem.';
        case 'invalid_date_of_birth':
          return 'Podaj poprawną datę urodzenia.';
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
      final response = await _authRepository.login(
        email: email,
        password: password,
      );
      if (response.requiresOtp) {
        _pendingLoginChallenge = response.challenge;
        _isDemoMode = false;
        notifyListeners();
        return true;
      }
      _pendingLoginChallenge = null;
      _isDemoMode = false;
      _applySession(response.session!);
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

  Future<bool> verifyLoginOtp({
    required String code,
    bool trustDevice = false,
  }) async {
    final challenge = _pendingLoginChallenge;
    if (challenge == null) {
      return false;
    }

    try {
      _authError = null;
      final session = await _authRepository.verifyLoginOtp(
        challengeId: challenge.challengeId,
        code: code,
        trustDevice: trustDevice,
      );
      _pendingLoginChallenge = null;
      _otpAttemptsRemaining = null;
      _otpLocked = false;
      _isDemoMode = false;
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      if (error is ApiException && error.message == 'invalid_otp') {
        _otpAttemptsRemaining = error.data?['attemptsRemaining'] as int?;
        _otpLocked = error.data?['locked'] == true;
      }
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zweryfikować kodu.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendLoginOtp() async {
    final challenge = _pendingLoginChallenge;
    if (challenge == null) {
      return false;
    }

    try {
      _authError = null;
      _pendingLoginChallenge = await _authRepository.resendLoginOtp(
        challengeId: challenge.challengeId,
        maskedEmail: challenge.maskedEmail,
      );
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się wysłać kodu ponownie.',
      );
      notifyListeners();
      return false;
    }
  }

  void clearLoginChallenge() {
    _pendingLoginChallenge = null;
    _otpAttemptsRemaining = null;
    _otpLocked = false;
    _authError = null;
    notifyListeners();
  }

  Future<bool> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
    required Map<ConsentType, bool> consents,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.registerWorkspace(
        name: name,
        email: email,
        password: password,
        workspaceName: workspaceName,
        consents: consents,
      );
      _isDemoMode = false;
      _needsChildOnboarding = true;
      _applySession(session);
      await loadUserConsents();
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

  List<UserConsentRecord>? get userConsents => _userConsents;

  Future<bool> loadUserConsents() async {
    if (_currentUser == null || _isDemoMode) {
      _userConsents = null;
      notifyListeners();
      return false;
    }

    try {
      _authError = null;
      _userConsents = await _consentRepository.fetchConsents();
      notifyListeners();
      return true;
    } catch (_) {
      _authError = 'Nie udało się pobrać zgód.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserConsent({
    required ConsentType type,
    required bool granted,
  }) async {
    if (_currentUser == null || _isDemoMode) {
      return false;
    }

    try {
      _authError = null;
      final updated = await _consentRepository.updateConsent(
        type: type,
        granted: granted,
      );

      final current = List<UserConsentRecord>.from(_userConsents ?? []);
      final index = current.indexWhere((item) => item.type == type);
      if (index >= 0) {
        current[index] = updated;
      } else {
        current.add(updated);
      }
      _userConsents = current;
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zaktualizować zgody.',
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

  /// Sends a one-time temporary password to [email] (if the account exists).
  Future<bool> requestPasswordReset(String email) async {
    try {
      _authError = null;
      await _authRepository.requestPasswordReset(email: email);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _authError = switch (error.message) {
        'otp_email_failed' =>
          'Nie udało się wysłać e-maila z hasłem. Spróbuj ponownie za chwilę.',
        'Too many requests, try again later' =>
          'Zbyt wiele prób. Spróbuj ponownie za chwilę.',
        'invalid_request' => 'Podaj prawidłowy adres e-mail.',
        _ => 'Nie udało się zresetować hasła.',
      };
      notifyListeners();
      return false;
    } catch (_) {
      _authError = 'Nie udało się zresetować hasła.';
      notifyListeners();
      return false;
    }
  }

  Future<EmailInviteSendResult?> sendEmailInvite(String email) async {
    try {
      _authError = null;
      final result = await _authRepository.sendEmailInvite(email: email);
      notifyListeners();
      return result;
    } on ApiException catch (error) {
      _authError = switch (error.message) {
        'cannot_invite_self' => 'Nie możesz zaprosić samego siebie.',
        'Too many requests, try again later' =>
          'Zbyt wiele prób. Spróbuj ponownie za chwilę.',
        'forbidden' => 'Tylko rodzic może wysłać zaproszenie.',
        _ => 'Nie udało się wysłać zaproszenia.',
      };
      notifyListeners();
      return null;
    } catch (_) {
      _authError = 'Nie udało się wysłać zaproszenia.';
      notifyListeners();
      return null;
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

  Future<ChildJoinPreview?> getChildJoinPreview(String childInviteCode) {
    return _authRepository.getChildJoinPreview(childInviteCode);
  }

  Future<bool> accessChildAccount({
    required String password,
    required String childInviteCode,
    required DateTime dateOfBirth,
    String? name,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.accessChildAccount(
        password: password,
        childInviteCode: childInviteCode,
        dateOfBirth: dateOfBirth,
        name: name,
      );
      _isDemoMode = false;
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zalogować jako dziecko.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> enterDemoRole(UserRole role) async {
    _authError = null;
    _pendingLoginChallenge = null;
    _otpAttemptsRemaining = null;
    _otpLocked = false;
    _isDemoMode = true;
    _isPinLocked = false;
    _isInitializing = false;

    final workspace = _buildDemoWorkspace();
    _currentWorkspace = workspace;
    _currentUser = _buildDemoUser(role);
    _highConflictMode = role == UserRole.parentB;

    notifyListeners();
  }

  /// Ustawia sesję dziecka w testach widget — wspólny workspace, inny profil użytkownika.
  @visibleForTesting
  void configureChildTestSession({
    required AppUser childUser,
    Workspace? workspace,
  }) {
    _authError = null;
    _isDemoMode = true;
    _isInitializing = false;
    _currentUser = childUser;
    _currentWorkspace = workspace ?? _buildDemoWorkspace();
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

  Future<void> _loadPinSettings() async {
    final userId = _currentUser?.id;
    if (userId == null) {
      _requirePinOnResume = false;
      _hasPinSet = false;
      _isPinLocked = false;
      return;
    }

    _hasPinSet = await _pinLockStore.hasPin(userId);
    _requirePinOnResume = await _pinLockStore.isRequirePinOnResume(userId);
    if (!_hasPinSet) {
      _requirePinOnResume = false;
    }
    notifyListeners();
  }

  Future<bool> setRequirePinOnResumeEnabled(bool enabled) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      return false;
    }

    if (enabled && !_hasPinSet) {
      return false;
    }

    await _pinLockStore.setRequirePinOnResume(userId, enabled);
    _requirePinOnResume = enabled;
    notifyListeners();
    return true;
  }

  Future<String?> setupPin({
    required String newPin,
    required String confirmPin,
    bool enableOnResume = false,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      return 'Brak aktywnej sesji';
    }

    final validationError = _validatePinPair(newPin, confirmPin);
    if (validationError != null) {
      return validationError;
    }

    await _pinLockStore.savePin(userId, newPin);
    _hasPinSet = true;
    if (enableOnResume) {
      await _pinLockStore.setRequirePinOnResume(userId, true);
      _requirePinOnResume = true;
    }
    notifyListeners();
    return null;
  }

  Future<String?> changePin({
    required String? currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      return 'Brak aktywnej sesji';
    }

    final validationError = _validatePinPair(newPin, confirmPin);
    if (validationError != null) {
      return validationError;
    }

    if (_hasPinSet) {
      if (currentPin == null || currentPin.isEmpty) {
        return 'Podaj aktualny PIN';
      }
      if (!PinLockStore.isValidPin(currentPin)) {
        return 'Aktualny PIN musi mieć 4 cyfry';
      }
    }

    final changed = await _pinLockStore.changePin(
      userId,
      currentPin: _hasPinSet ? currentPin : null,
      newPin: newPin,
    );
    if (!changed) {
      return 'Aktualny PIN jest nieprawidłowy';
    }

    _hasPinSet = true;
    notifyListeners();
    return null;
  }

  Future<bool> verifyPinAndUnlock(String pin) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      return false;
    }

    final ok = await _pinLockStore.verifyPin(userId, pin);
    if (ok) {
      _isPinLocked = false;
      notifyListeners();
    }
    return ok;
  }

  void lockOnBackground() {
    if (_currentUser == null ||
        _isDemoMode ||
        !_requirePinOnResume ||
        !_hasPinSet) {
      return;
    }
    _isPinLocked = true;
    notifyListeners();
  }

  String? _validatePinPair(String newPin, String confirmPin) {
    if (!PinLockStore.isValidPin(newPin)) {
      return 'PIN musi mieć dokładnie 4 cyfry';
    }
    if (newPin != confirmPin) {
      return 'PIN-y nie są identyczne';
    }
    return null;
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
    _requirePinOnResume = false;
    _hasPinSet = false;
    _isPinLocked = false;
    unawaited(_authRepository.logout());
    notifyListeners();
  }

  void _applySession(AuthSession session) {
    _currentUser = session.user;
    _currentWorkspace = session.workspace;
    _highConflictMode = session.user.highConflictMode;
    _isPinLocked = false;
    unawaited(_loadPinSettings());
  }

  Workspace _buildDemoWorkspace() {
    final createdAt = DateTime(2026, 1, 12, 9, 30);
    return Workspace(
      id: 'workspace_demo_001',
      name: 'Rodzina Kowalskich — demo',
      inviteCode: 'DEMO-2026',
      childInviteCode: 'DZIECIKOWAL2026',
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

