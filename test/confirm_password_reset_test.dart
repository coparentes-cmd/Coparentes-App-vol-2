import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/utils/reset_password_url.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    this.onConfirm,
  });

  final Future<void> Function({
    required String token,
    required String newPassword,
  })? onConfirm;

  String? lastToken;
  String? lastPassword;
  int confirmCalls = 0;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    confirmCalls += 1;
    lastToken = token;
    lastPassword = newPassword;
    if (onConfirm != null) {
      await onConfirm!(token: token, newPassword: newPassword);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  test('readResetPasswordTokenFromUrl returns null outside web', () {
    // VM / widget tests: kIsWeb is false.
    expect(readResetPasswordTokenFromUrl(), isNull);
  });

  Future<AppProvider> bootProvider(
    _FakeAuthRepository auth,
    SharedPreferences prefs,
  ) async {
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: ConsentRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
      ),
      pinLockStore: PinLockStore(preferences: prefs),
    );
    await Future<void>.delayed(Duration.zero);
    while (ap.isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return ap;
  }

  test('confirmPasswordReset success clears authError and returns true',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();

    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
    );
    final ap = await bootProvider(auth, prefs);

    final ok = await ap.confirmPasswordReset(
      token: 'fresh-token',
      newPassword: 'BrandNew9!',
    );

    expect(ok, isTrue);
    expect(ap.authError, isNull);
    expect(auth.confirmCalls, 1);
    expect(auth.lastToken, 'fresh-token');
    expect(auth.lastPassword, 'BrandNew9!');
    expect(ap.currentUser, isNull);
  });

  test(
      'confirmPasswordReset maps invalid_or_expired_token to Polish message',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();

    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      onConfirm: ({required token, required newPassword}) async {
        throw const ApiException(400, 'invalid_or_expired_token');
      },
    );
    final ap = await bootProvider(auth, prefs);

    final ok = await ap.confirmPasswordReset(
      token: 'stale-token',
      newPassword: 'BrandNew9!',
    );

    expect(ok, isFalse);
    expect(
      ap.authError,
      'Link wygasł lub został już użyty. Poproś o nowy w oknie logowania.',
    );
  });
}
