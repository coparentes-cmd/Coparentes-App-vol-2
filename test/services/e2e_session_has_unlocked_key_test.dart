import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:coparentes/utils/secure_storage_options.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts [restoreUnlockedKeyFromDevice] so RAM-hit path can assert no restore.
class _CountingRestoreStorage extends E2eKeyStorageService {
  _CountingRestoreStorage({required super.secureStorage});

  int restoreCalls = 0;

  @override
  Future<bool> restoreUnlockedKeyFromDevice() async {
    restoreCalls++;
    return super.restoreUnlockedKeyFromDevice();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> backingStore;
  late E2eCryptoService crypto;
  late AppApiClient api;

  setUp(() {
    backingStore = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(backingStore);
    crypto = E2eCryptoService();
    api = AppApiClient(baseUrl: 'http://fake.local/api');
  });

  test(
    'hasUnlockedKey: empty RAM + durable key → true and key usable in RAM',
    () async {
      final original = await (await crypto.generateKeyPair()).extract();
      final originalSeed = await original.extractPrivateKeyBytes();
      final originalPublic = (await original.extractPublicKey()).bytes;

      final persistStorage =
          E2eKeyStorageService(secureStorage: buildSecureStorage());
      await persistStorage.persistUnlockedKeyToDevice(original);

      // Fresh session: empty RAM, same durable store.
      final sessionStorage =
          E2eKeyStorageService(secureStorage: buildSecureStorage());
      await expectLater(
        () => sessionStorage.useUnlockedKeyPair((_) async {}),
        throwsA(isA<NoUnlockedKeyException>()),
      );

      final e2e = E2eSessionService(
        apiClient: api,
        crypto: crypto,
        keyStorage: sessionStorage,
      );

      expect(await e2e.hasUnlockedKey(), isTrue);

      await sessionStorage.useUnlockedKeyPair((key) async {
        expect(await key.extractPrivateKeyBytes(), originalSeed);
        expect((await key.extractPublicKey()).bytes, originalPublic);
        expect(key.type, KeyPairType.x25519);
      });
    },
  );

  test(
    'hasUnlockedKey: empty RAM + nothing durable → false, no throw',
    () async {
      final storage = E2eKeyStorageService(secureStorage: buildSecureStorage());
      final e2e = E2eSessionService(
        apiClient: api,
        crypto: crypto,
        keyStorage: storage,
      );

      expect(await e2e.hasUnlockedKey(), isFalse);

      await expectLater(
        () => storage.useUnlockedKeyPair((_) async {}),
        throwsA(isA<NoUnlockedKeyException>()),
      );
    },
  );

  test(
    'hasUnlockedKey: key already in RAM → true without restore',
    () async {
      final unlocked = await (await crypto.generateKeyPair()).extract();
      final storage =
          _CountingRestoreStorage(secureStorage: buildSecureStorage());
      await storage.storeUnlockedKeyPair(unlocked);

      final e2e = E2eSessionService(
        apiClient: api,
        crypto: crypto,
        keyStorage: storage,
      );

      expect(await e2e.hasUnlockedKey(), isTrue);
      expect(storage.restoreCalls, 0);

      await storage.useUnlockedKeyPair((key) async {
        expect(identical(key, unlocked), isTrue);
      });
    },
  );
}
