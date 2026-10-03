import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReplaceE2e extends E2eSessionService {
  _FakeReplaceE2e({this.throwApi})
      : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  final ApiException? throwApi;
  int replaceCalls = 0;
  String? lastPassword;

  @override
  Future<E2eReplacementKeyMaterial> replaceKeysAbandoningHistory(
    String currentPassword,
  ) async {
    replaceCalls += 1;
    lastPassword = currentPassword;
    if (throwApi != null) {
      throw throwApi!;
    }
    final crypto = E2eCryptoService();
    final keyPair = await (await crypto.generateKeyPair()).extract();
    final publicKey = await keyPair.extractPublicKey();
    final envelope = await crypto.createPrivateKeyEnvelope(
      keyPair: keyPair,
      password: currentPassword,
    );
    return E2eReplacementKeyMaterial(
      publicKey: crypto.encodePublicKey(publicKey),
      privateKeyEnvelope: envelope,
      keyPairData: keyPair,
    );
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

  Future<AppProvider> buildProvider(_FakeReplaceE2e e2e) async {
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
    return ap;
  }

  test('setupFreshE2eKeysAbandoningHistory success clears authError', () async {
    final e2e = _FakeReplaceE2e();
    final ap = await buildProvider(e2e);

    final ok = await ap.setupFreshE2eKeysAbandoningHistory('SecretPass9');
    expect(ok, isTrue);
    expect(e2e.replaceCalls, 1);
    expect(e2e.lastPassword, 'SecretPass9');
    expect(ap.authError, isNull);
  });

  test('setupFreshE2eKeysAbandoningHistory maps 401 to Polish message',
      () async {
    final e2e = _FakeReplaceE2e(
      throwApi: const ApiException(401, 'invalid_credentials'),
    );
    final ap = await buildProvider(e2e);

    final ok = await ap.setupFreshE2eKeysAbandoningHistory('WrongPass9');
    expect(ok, isFalse);
    expect(ap.authError, 'Nieprawidłowe aktualne hasło.');
  });
}
