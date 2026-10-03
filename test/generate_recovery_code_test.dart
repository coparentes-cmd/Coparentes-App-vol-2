import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingApiClient extends AppApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://fake');

  final posts = <({String path, Map<String, dynamic> body})>[];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    posts.add((path: path, body: Map<String, dynamic>.from(body)));
    return {'success': true};
  }
}

class _FakeRecoveryE2e extends E2eSessionService {
  _FakeRecoveryE2e({
    required this.unlocked,
    this.throwOther = false,
  }) : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  bool unlocked;
  bool throwOther;
  int generateCalls = 0;
  static const sampleCode = 'WXYZ-ABCD-EFGH-IJKM-NPQR-STV0';

  @override
  Future<bool> hasUnlockedKey() async => unlocked;

  @override
  Future<String> generateRecoveryCodeForExistingKey() async {
    generateCalls += 1;
    if (throwOther) throw Exception('network');
    return sampleCode;
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

  group('E2eSessionService.generateRecoveryCodeForExistingKey', () {
    const argonTimeout = Timeout(Duration(minutes: 2));

    test(
      'success: posts /user/recovery-key and returns code',
      () async {
        final api = _RecordingApiClient();
        final e2e = E2eSessionService(apiClient: api);
        final crypto = E2eCryptoService();
        final keyPair = await crypto.generateKeyPair();
        final data = await keyPair.extract();
        await e2e.keyStorage.storeUnlockedKeyPair(data);

        final code = await e2e.generateRecoveryCodeForExistingKey();

        expect(
          code,
          matches(
            RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){5}$'),
          ),
        );
        expect(api.posts.length, 1);
        expect(api.posts.single.path, '/user/recovery-key');
        expect(api.posts.single.body['recoveryCode'], code);
        expect(
          (api.posts.single.body['recoveryKeyEnvelope'] as String).isNotEmpty,
          isTrue,
        );
      },
      timeout: argonTimeout,
    );

    test('throws NoUnlockedKeyException when key not unlocked', () async {
      final e2e = E2eSessionService(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
      );
      expect(
        e2e.generateRecoveryCodeForExistingKey(),
        throwsA(isA<NoUnlockedKeyException>()),
      );
    });
  });

  group('AppProvider.generateE2eRecoveryCode', () {
    Future<({AppProvider ap, _FakeRecoveryE2e e2e})> boot(
      _FakeRecoveryE2e e2e,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final offline = OfflineStore(preferences: prefs);
      await offline.initialize();
      final ap = AppProvider(
        authRepository: AuthRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
          preferences: prefs,
          offlineStore: offline,
        ),
        consentRepository: ConsentRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
        ),
        pinLockStore: PinLockStore(preferences: prefs),
        preferences: prefs,
        e2eSessionService: e2e,
      );
      await Future<void>.delayed(Duration.zero);
      while (ap.isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return (ap: ap, e2e: e2e);
    }

    test('needsUnlock when key not in memory', () async {
      final bootstrapped =
          await boot(_FakeRecoveryE2e(unlocked: false));
      final outcome = await bootstrapped.ap.generateE2eRecoveryCode();
      expect(outcome.result, GenerateRecoveryCodeResult.needsUnlock);
      expect(bootstrapped.e2e.generateCalls, 0);
    });

    test('success returns plaintext code', () async {
      final bootstrapped = await boot(_FakeRecoveryE2e(unlocked: true));
      final outcome = await bootstrapped.ap.generateE2eRecoveryCode();
      expect(outcome.result, GenerateRecoveryCodeResult.success);
      expect(outcome.code, _FakeRecoveryE2e.sampleCode);
      expect(bootstrapped.e2e.generateCalls, 1);
    });

    test('error maps failure to authError', () async {
      final bootstrapped = await boot(
        _FakeRecoveryE2e(unlocked: true, throwOther: true),
      );
      final outcome = await bootstrapped.ap.generateE2eRecoveryCode();
      expect(outcome.result, GenerateRecoveryCodeResult.error);
      expect(bootstrapped.ap.authError, isNotNull);
    });
  });
}
