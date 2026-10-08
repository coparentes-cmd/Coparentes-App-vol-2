import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/country_profiles.dart';
import '../data/api/app_api_client.dart';
import '../data/local/locale_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/demo_copy.dart';
import '../l10n/locale_policy.dart';
import '../data/models/auth_session.dart';
import '../data/models/login_challenge.dart';
import '../data/local/pin_lock_store.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/consent_repository.dart';
import '../data/models/user_consent.dart';
import '../models/models.dart';
import '../services/e2e_crypto_service.dart';
import '../services/e2e_key_storage_service.dart';
import '../services/e2e_session_service.dart';
import '../utils/demo_time.dart';

export 'calendar_provider.dart';
export 'finance_provider.dart';
export 'messaging_provider.dart';

/// Outcome of [AppProvider.generateE2eRecoveryCode] (Settings / R3).
enum GenerateRecoveryCodeResult {
  /// Private key not in RAM — UI must unlock with password, then retry.
  needsUnlock,

  /// Code generated + uploaded; see [GenerateRecoveryCodeOutcome.code].
  success,

  /// Network / API / unexpected failure (see [AppProvider.authError]).
  error,
}

class GenerateRecoveryCodeOutcome {
  const GenerateRecoveryCodeOutcome._({
    required this.result,
    this.code,
  });

  factory GenerateRecoveryCodeOutcome.needsUnlock() =>
      const GenerateRecoveryCodeOutcome._(
        result: GenerateRecoveryCodeResult.needsUnlock,
      );

  factory GenerateRecoveryCodeOutcome.success(String code) =>
      GenerateRecoveryCodeOutcome._(
        result: GenerateRecoveryCodeResult.success,
        code: code,
      );

  factory GenerateRecoveryCodeOutcome.error() =>
      const GenerateRecoveryCodeOutcome._(
        result: GenerateRecoveryCodeResult.error,
      );

  final GenerateRecoveryCodeResult result;
  final String? code;
}

// ─── AppProvider ──────────────────────────────────────────────────────────────

class AppProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ConsentRepository _consentRepository;
  final PinLockStore _pinLockStore;
  final SharedPreferences _preferences;
  final LocaleStore? _localeStore;
  final E2eSessionService? _e2eSession;

  /// Called after E2E unlock/reset so MessagingProvider can drop decrypt caches.
  VoidCallback? onE2eSessionChanged;

  /// Held only while an OTP challenge is pending — cleared after unlock / cancel.
  String? _pendingE2ePassword;

  /// Login password kept in memory only while [AppUser.mustChangePassword] is true
  /// so the forced-change screen can pass it as currentPassword without re-prompting.
  String? _pendingLoginPassword;

  AppProvider({
    required AuthRepository authRepository,
    required ConsentRepository consentRepository,
    required PinLockStore pinLockStore,
    required SharedPreferences preferences,
    LocaleStore? localeStore,
    Locale? initialLocale,
    E2eSessionService? e2eSessionService,
  })  : _authRepository = authRepository,
        _consentRepository = consentRepository,
        _pinLockStore = pinLockStore,
        _preferences = preferences,
        _localeStore = localeStore,
        _e2eSession = e2eSessionService {
    if (initialLocale != null) {
      _locale = localeFromStoredCode(initialLocale.languageCode);
      _language = _locale.languageCode;
    }
    unawaited(bootstrap());
  }

  AppUser? _currentUser;
  Workspace? _currentWorkspace;
  bool _highConflictMode = false;
  bool _isInitializing = true;
  bool _isDemoMode = false;
  /// Post-registration dashboard tour step (1–3), or null when inactive.
  int? _onboardingTourStep;
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

  void _setDemoMode(bool enabled) {
    _isDemoMode = enabled;
    if (enabled) {
      DemoTime.activate();
    } else {
      DemoTime.deactivate();
    }
  }
  /// 1–3 while the parent post-registration tour is active; otherwise null.
  int? get onboardingTourStep => _onboardingTourStep;
  String? get authError => _authError;

  static String onboardingTourPrefsKey(String userId) =>
      'onboarding_tour_step_$userId';
  LoginChallenge? get pendingLoginChallenge => _pendingLoginChallenge;
  bool get needsOtpVerification => _pendingLoginChallenge != null;
  int? get otpAttemptsRemaining => _otpAttemptsRemaining;
  bool get otpLocked => _otpLocked;
  Locale get locale => _locale;
  CountryProfile get countryProfile => _countryProfile;
  /// Demo EN always shows EUR (label only; amounts unchanged).
  String get currencyCode =>
      (_isDemoMode && _language == 'en') ? 'EUR' : _countryProfile.currencyCode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Color get primaryColor => _colorScheme.primary;
  Color get primaryLight => _colorScheme.light;

  String _mapAuthError(Object error, {required String fallback}) {
    return AppStrings.translate(
      _language,
      _polishAuthError(error, fallback: fallback),
    );
  }

  String _polishAuthError(Object error, {required String fallback}) {
    if (error is ApiException) {
      switch (error.message) {
        case 'email_in_use':
          return 'Ten e-mail jest już zarejestrowany. Spróbuj się zalogować.';
        case 'invalid_request':
          return 'Sprawdź dane: hasło min. 8 znaków, imię i nazwa przestrzeni min. 2 znaki.';
        case 'required_consents_missing':
          return 'Zaakceptuj wszystkie wymagane zgody, aby dokończyć rejestrację.';
        case 'required_consent_locked':
          return 'Ta zgoda jest wymagana do korzystania z aplikacji.';
        case 'invalid_credentials':
          return 'Nieprawidłowy e-mail lub hasło.';
        case 'role_not_supported':
          return 'To konto nie jest już obsługiwane (rola obserwatora została wyłączona).';
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
          return 'Nie znaleziono profilu dziecka. Poproś rodzica o nowy kod zaproszenia.';
        case 'child_dob_mismatch':
          return 'Data urodzenia nie zgadza się. Sprawdź ją z rodzicem.';
        case 'ambiguous_child_profile':
          return 'Ten stary kod rodzinny pasuje do kilku dzieci. Poproś rodzica o osobny kod dla Ciebie.';
        case 'ambiguous_child_login':
          return 'Kilka kont pasuje do tych danych. Poproś rodzica o pomoc w Ustawieniach.';
        case 'child_name_required':
          return 'Podaj login (imię) — jest wymagany przy pierwszym dołączeniu.';
        case 'child_profile_taken':
          return 'To dziecko ma już konto. Zaloguj się loginem, hasłem i datą urodzenia.';
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
        // Forced change needs the temp password in memory — cold restore cannot
        // supply it, so clear the dead session and require a fresh login.
        if (session.user.mustChangePassword) {
          await _authRepository.logout();
        } else {
          _applySession(session);
        }
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
      // Login OTP / 2FA retired — backend must return a session.
      if (response.requiresOtp || response.session == null) {
        _pendingLoginChallenge = null;
        _pendingE2ePassword = null;
        _authError =
            'Logowanie dwuetapowe nie jest już obsługiwane. Spróbuj ponownie lub skontaktuj się z pomocą.';
        notifyListeners();
        return false;
      }
      _pendingLoginChallenge = null;
      _pendingE2ePassword = null;
      _setDemoMode(false);
      final session = response.session!;
      _applySession(session);
      _retainLoginPasswordIfMustChange(password);
      notifyListeners();
      return true;
    } catch (error) {
      _pendingE2ePassword = null;
      _pendingLoginPassword = null;
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
      final e2ePassword = _pendingE2ePassword;
      _pendingE2ePassword = null;
      _pendingLoginChallenge = null;
      _otpAttemptsRemaining = null;
      _otpLocked = false;
      _setDemoMode(false);
      _applySession(session);
      if (e2ePassword != null && e2ePassword.isNotEmpty) {
        _retainLoginPasswordIfMustChange(e2ePassword);
      } else {
        _pendingLoginPassword = null;
      }
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
    _pendingE2ePassword = null;
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
      _setDemoMode(false);
      _applySession(session);
      await setOnboardingTourStep(1);
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
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się dodać dziecka.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkspaceChild({
    required String childId,
    String? name,
    DateTime? dateOfBirth,
    String? school,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.updateWorkspaceChild(
        childId: childId,
        name: name,
        dateOfBirth: dateOfBirth,
        school: school,
        clearSchool: school == null,
      );
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zaktualizować profilu dziecka.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWorkspaceChild(String childId) async {
    try {
      _authError = null;
      final session = await _authRepository.deleteWorkspaceChild(childId);
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się usunąć profilu dziecka.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameWorkspace(String name) async {
    try {
      _authError = null;
      final session = await _authRepository.renameWorkspace(name);
      _applySession(session);
      notifyListeners();
      return true;
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się zmienić nazwy przestrzeni.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Persists post-registration tour step (1–3) or clears it when [step] is null.
  Future<void> setOnboardingTourStep(int? step) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      return;
    }
    final key = onboardingTourPrefsKey(userId);
    if (step == null || step < 1 || step > 3) {
      await _preferences.remove(key);
      _onboardingTourStep = null;
    } else {
      await _preferences.setInt(key, step);
      _onboardingTourStep = step;
    }
    notifyListeners();
  }

  void _loadOnboardingTourStep(String userId) {
    final value = _preferences.getInt(onboardingTourPrefsKey(userId));
    _onboardingTourStep =
        (value != null && value >= 1 && value <= 3) ? value : null;
  }

  /// Settings / R3: seal the unlocked E2E key under a new recovery code.
  ///
  /// Does not prompt for password. If locked → [GenerateRecoveryCodeResult.needsUnlock];
  /// caller unlocks via [unlockE2eWithPassword], then calls again.
  Future<GenerateRecoveryCodeOutcome> generateE2eRecoveryCode() async {
    final e2e = _e2eSession;
    if (e2e == null) {
      _authError = 'Szyfrowanie czatu jest niedostępne.';
      notifyListeners();
      return GenerateRecoveryCodeOutcome.error();
    }
    if (!await e2e.hasUnlockedKey()) {
      return GenerateRecoveryCodeOutcome.needsUnlock();
    }
    try {
      _authError = null;
      final code = await e2e.generateRecoveryCodeForExistingKey();
      return GenerateRecoveryCodeOutcome.success(code);
    } on NoUnlockedKeyException {
      return GenerateRecoveryCodeOutcome.needsUnlock();
    } catch (error) {
      _authError = _mapAuthError(
        error,
        fallback: 'Nie udało się wygenerować kodu odzyskiwania.',
      );
      notifyListeners();
      return GenerateRecoveryCodeOutcome.error();
    }
  }

  Future<bool> updateProfile({
    String? name,
    bool? highConflictMode,
    bool? twoFactorEnabled,
    ThemeMode? themeMode,
    AppColorScheme? colorScheme,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.updateProfile(
        name: name,
        highConflictMode: highConflictMode,
        twoFactorEnabled: twoFactorEnabled,
        themeMode: themeMode,
        colorScheme: colorScheme,
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
    /// Kept for call-site stability; client E2E rewrap is no longer used.
    bool replaceOrphanedE2eKeys = false,
  }) async {
    try {
      _authError = null;
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      // Drop any leftover local E2E material after password change.
      unawaited(_e2eSession?.clearAll());
      onE2eSessionChanged?.call();
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

  /// Orphaned E2E recovery: new X25519 pair under [currentPassword], uploaded
  /// via `POST /user/keys` (with bcrypt verify). Abandons history sealed to the
  /// previous private key. Does not change the account password.
  Future<bool> setupFreshE2eKeysAbandoningHistory(
    String currentPassword,
  ) async {
    final e2e = _e2eSession;
    if (e2e == null) {
      _authError = 'Sesja E2E niedostępna. Zaloguj się ponownie.';
      notifyListeners();
      return false;
    }
    if (currentPassword.isEmpty) {
      _authError = 'Podaj aktualne hasło.';
      notifyListeners();
      return false;
    }

    try {
      _authError = null;
      await e2e.replaceKeysAbandoningHistory(currentPassword);
      onE2eSessionChanged?.call();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.message == 'invalid_credentials') {
        _authError = 'Nieprawidłowe aktualne hasło.';
      } else {
        _authError =
            'Nie udało się założyć nowych kluczy czatu. Spróbuj ponownie.';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _authError =
          'Nie udało się założyć nowych kluczy czatu. Spróbuj ponownie.';
      notifyListeners();
      return false;
    }
  }

  /// Completes the post-forgot-password forced change using the in-memory
  /// login password as [currentPassword], then re-authenticates (backend
  /// invalidates sessions on password change).
  Future<bool> completeForcedPasswordChange({
    required String newPassword,
  }) async {
    final current = _pendingLoginPassword;
    final email = _currentUser?.email;
    if (current == null ||
        current.isEmpty ||
        email == null ||
        email.isEmpty) {
      _authError = 'Sesja wygasła. Zaloguj się ponownie.';
      notifyListeners();
      return false;
    }

    final changed = await changePassword(
      currentPassword: current,
      newPassword: newPassword,
      replaceOrphanedE2eKeys: true,
    );
    if (!changed) {
      return false;
    }

    _pendingLoginPassword = null;

    final loggedIn = await login(email: email, password: newPassword);
    if (!loggedIn) {
      logout();
      return false;
    }
    return true;
  }

  /// Soft-deletes the account on the server. Does **not** clear local session —
  /// caller must call [logout] after dismissing UI (same cleanup path as manual logout).
  Future<bool> deleteAccount({required String password}) async {
    try {
      _authError = null;
      await _authRepository.deleteAccount(password: password);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.message == 'invalid_password') {
        _authError = 'Nieprawidłowe hasło';
      } else {
        _authError =
            'Nie udało się usunąć konta, spróbuj ponownie później';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _authError =
          'Nie udało się usunąć konta, spróbuj ponownie później';
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
          _passwordResetMailHint(error.data) ??
              'Nie udało się wysłać e-maila z hasłem. Sprawdź folder Spam i spróbuj ponownie.',
        'email_send_failed' =>
          _passwordResetMailHint(error.data) ??
              'Nie udało się wysłać e-maila z hasłem. Sprawdź folder Spam i spróbuj ponownie.',
        'email_not_configured' =>
          'Wysyłka e-mail jest tymczasowo niedostępna. Spróbuj później lub skontaktuj się z supportem.',
        'email_send_timeout' =>
          'Serwer poczty nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
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

  /// Parent-initiated login-password reset for a child [AppUser] in this workspace.
  Future<bool> resetChildPassword(String childUserId) async {
    try {
      _authError = null;
      await _authRepository.resetChildPassword(childUserId: childUserId);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _authError = switch (error.message) {
        'child_not_found' =>
          'Nie znaleziono konta dziecka w tej przestrzeni.',
        'forbidden' =>
          'Tylko rodzice mogą resetować hasło logowania dziecka.',
        'otp_email_failed' || 'email_send_failed' =>
          _passwordResetMailHint(error.data) ??
              'Nie udało się wysłać e-maila z linkiem. Sprawdź folder Spam i spróbuj ponownie.',
        'email_not_configured' =>
          'Wysyłka e-mail jest tymczasowo niedostępna. Spróbuj później lub skontaktuj się z supportem.',
        'email_send_timeout' =>
          'Serwer poczty nie odpowiedział na czas. Spróbuj ponownie za chwilę.',
        'Too many requests, try again later' =>
          'Zbyt wiele prób. Spróbuj ponownie za chwilę.',
        'no_recovery_contact' =>
          'Brak adresu e-mail rodziców do wysyłki linku.',
        _ => error.statusCode == 429
            ? 'Zbyt wiele prób. Spróbuj ponownie za chwilę.'
            : error.statusCode == 503
                ? 'Nie udało się wysłać e-maila z linkiem. Spróbuj ponownie za chwilę.'
                : error.statusCode == 403
                    ? 'Tylko rodzice mogą resetować hasło logowania dziecka.'
                    : error.statusCode == 404
                        ? 'Nie znaleziono konta dziecka w tej przestrzeni.'
                        : 'Nie udało się zresetować hasła dziecka.',
      };
      notifyListeners();
      return false;
    } catch (_) {
      _authError = 'Nie udało się zresetować hasła dziecka.';
      notifyListeners();
      return false;
    }
  }

  /// Sets a new password from a one-time reset link. Does not log the user in.
  Future<bool> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      _authError = null;
      await _authRepository.confirmPasswordReset(
        token: token,
        newPassword: newPassword,
      );
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _authError = switch (error.message) {
        'invalid_or_expired_token' =>
          'Link wygasł lub został już użyty. Poproś o nowy w oknie logowania.',
        'Too many requests, try again later' =>
          'Zbyt wiele prób. Spróbuj ponownie za chwilę.',
        'invalid_request' => 'Podaj prawidłowe nowe hasło.',
        _ => 'Nie udało się zmienić hasła.',
      };
      notifyListeners();
      return false;
    } catch (_) {
      _authError = 'Nie udało się zmienić hasła.';
      notifyListeners();
      return false;
    }
  }

  static String? _passwordResetMailHint(Map<String, dynamic>? data) {
    final reason = data?['reason'] as String?;
    if (reason == null || reason.isEmpty) {
      return null;
    }
    final lower = reason.toLowerCase();
    if (lower.contains('domain is not verified') ||
        lower.contains('not verified')) {
      return 'Serwer poczty ma złą konfigurację nadawcy (domena niezweryfikowana w Resend). '
          'Ustaw RESEND_FROM_EMAIL na adres @getcoparentes.app po weryfikacji domeny.';
    }
    return null;
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
      _setDemoMode(false);
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
      _setDemoMode(false);
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

  Future<bool> loginChildAccount({
    required String login,
    required String password,
    required DateTime dateOfBirth,
  }) async {
    try {
      _authError = null;
      final session = await _authRepository.loginChildAccount(
        login: login,
        password: password,
        dateOfBirth: dateOfBirth,
      );
      _setDemoMode(false);
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
    _setDemoMode(true);
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
    _setDemoMode(true);
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

  // ── Theme ──────────────────────────────────────────────────────────────────

  Future<void> setThemeMode(ThemeMode mode) async {
    final previous = _themeMode;
    if (_isDemoMode) {
      _themeMode = mode;
      notifyListeners();
      return;
    }

    _themeMode = mode;
    notifyListeners();

    final ok = await updateProfile(themeMode: mode);
    if (!ok) {
      _themeMode = previous;
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode() async {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    final previous = _colorScheme;
    if (_isDemoMode) {
      _colorScheme = scheme;
      notifyListeners();
      return;
    }

    _colorScheme = scheme;
    notifyListeners();

    final ok = await updateProfile(colorScheme: scheme);
    if (!ok) {
      _colorScheme = previous;
      notifyListeners();
    }
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

  /// PIN-on-resume retired — kept as no-op for call-site stability.
  void lockOnBackground() {}

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
    final next = localeFromStoredCode(locale.languageCode);
    _locale = next;
    _language = next.languageCode;
    final store = _localeStore;
    if (store != null) {
      unawaited(store.writeExplicit(next));
    }
    applyDemoWorkspaceName(notify: false);
    notifyListeners();
  }

  /// Country changes currency and profile only. It does not switch the UI language.
  void setCountryProfile(String countryCode) {
    _countryProfile = CountryProfiles.byCode(countryCode);
    notifyListeners();
  }

  /// Renames only the original demo workspace. Production workspaces are ignored.
  void applyDemoWorkspaceName({bool notify = true}) {
    final current = _currentWorkspace;
    if (current == null || current.id != DemoCopy.workspaceDemoId) {
      return;
    }
    final name = DemoCopy.workspaceName(_language);
    if (current.name == name) {
      return;
    }
    _currentWorkspace = Workspace(
      id: current.id,
      name: name,
      inviteCode: current.inviteCode,
      childInviteCode: current.childInviteCode,
      inviteCodeExpiresAt: current.inviteCodeExpiresAt,
      members: current.members,
      children: current.children,
      createdAt: current.createdAt,
    );
    if (notify) {
      notifyListeners();
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void logout() {
    _currentUser = null;
    _currentWorkspace = null;
    _authError = null;
    _pendingE2ePassword = null;
    _pendingLoginPassword = null;
    _setDemoMode(false);
    _onboardingTourStep = null;
    _requirePinOnResume = false;
    _hasPinSet = false;
    _isPinLocked = false;
    unawaited(_e2eSession?.clearAll());
    onE2eSessionChanged?.call();
    unawaited(_authRepository.logout());
    notifyListeners();
  }

  void _applySession(AuthSession session) {
    _currentUser = session.user;
    _currentWorkspace = session.workspace;
    _highConflictMode = session.user.highConflictMode;
    _themeMode = session.user.themeMode;
    _colorScheme = session.user.colorScheme;
    _isPinLocked = false;
    _loadOnboardingTourStep(session.user.id);
    unawaited(_loadPinSettings());
  }

  void _retainLoginPasswordIfMustChange(String password) {
    if (_currentUser?.mustChangePassword == true && password.isNotEmpty) {
      _pendingLoginPassword = password;
    } else {
      _pendingLoginPassword = null;
    }
  }

  bool get hasE2eSession => _e2eSession != null;

  /// Parent A/B member ids in the current workspace (for E2E threadKeys).
  ///
  /// Family threads still use only these ids at create time — child keys are
  /// synced later via `/threads/:id/keys/family-sync`.
  List<String> get parentMemberIds {
    final workspace = _currentWorkspace;
    if (workspace == null) {
      return const [];
    }
    return workspace.members
        .where(
          (member) =>
              member.role == UserRole.parentA ||
              member.role == UserRole.parentB,
        )
        .map((member) => member.id)
        .toList();
  }

  /// Child *user* ids (`AppUser` with [UserRole.child]) — not [ChildProfile] ids.
  List<String> get childMemberIds {
    final workspace = _currentWorkspace;
    if (workspace == null) {
      return const [];
    }
    return workspace.members
        .where((member) => member.role == UserRole.child)
        .map((member) => member.id)
        .toList();
  }

  Future<bool> isE2eUnlocked() async => true;

  /// No-op: chat no longer requires client E2E unlock.
  Future<void> unlockE2eWithPassword(String password) async {}

  /// R4: restore the original E2E identity with a mailed recovery code, then
  /// rewrap under [currentPassword]. Propagates [RecoveryCodeNotSetUpException],
  /// [InvalidPasswordException] (wrong code), and [ApiException] (e.g. 401).
  Future<void> recoverE2eWithRecoveryCode({
    required String recoveryCode,
    required String currentPassword,
  }) async {
    final e2e = _e2eSession;
    if (e2e == null) {
      throw StateError('E2E session unavailable');
    }
    await e2e.recoverWithCode(recoveryCode, currentPassword);
    onE2eSessionChanged?.call();
  }

  Workspace _buildDemoWorkspace() {
    final createdAt = DateTime(2026, 1, 12, 9, 30);
    return Workspace(
      id: 'workspace_demo_001',
      name: DemoCopy.workspaceName(_language),
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

