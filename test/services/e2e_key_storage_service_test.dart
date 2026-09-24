import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> backingStore;
  late E2eKeyStorageService storage;

  setUp(() {
    backingStore = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(backingStore);
    storage = E2eKeyStorageService(secureStorage: const FlutterSecureStorage());
  });

  test('cacheEncryptedEnvelope + getCachedEncryptedEnvelope round-trip',
      () async {
    const envelope = '{"v":1,"kdf":{},"cipher":{}}';

    await storage.cacheEncryptedEnvelope(envelope);

    expect(await storage.getCachedEncryptedEnvelope(), envelope);
    expect(
      backingStore.containsKey(
        E2eKeyStorageService.encryptedEnvelopeStorageKey,
      ),
      isTrue,
    );
  });

  test('clearAll clears durable envelope and in-memory unlocked key', () async {
    final crypto = E2eCryptoService();
    final unlocked = await (await crypto.generateKeyPair()).extract();

    await storage.storeUnlockedKeyPair(unlocked);
    await storage.cacheEncryptedEnvelope('opaque-envelope-blob');

    await storage.useUnlockedKeyPair((key) async {
      expect(identical(key, unlocked), isTrue);
    });
    expect(await storage.getCachedEncryptedEnvelope(), 'opaque-envelope-blob');

    await storage.clearAll();

    await expectLater(
      () => storage.useUnlockedKeyPair((_) async => null),
      throwsA(isA<NoUnlockedKeyException>()),
    );
    expect(await storage.getCachedEncryptedEnvelope(), isNull);
    expect(backingStore, isEmpty);
  });

  test('unlocked key is not written to FlutterSecureStorage', () async {
    final crypto = E2eCryptoService();
    final unlocked = await (await crypto.generateKeyPair()).extract();

    await storage.storeUnlockedKeyPair(unlocked);

    expect(backingStore, isEmpty);
    await storage.useUnlockedKeyPair((key) async {
      expect(identical(key, unlocked), isTrue);
    });
  });

  test('useUnlockedKeyPair throws when nothing is unlocked', () async {
    await expectLater(
      () => storage.useUnlockedKeyPair((_) async => 'x'),
      throwsA(isA<NoUnlockedKeyException>()),
    );
  });
}
