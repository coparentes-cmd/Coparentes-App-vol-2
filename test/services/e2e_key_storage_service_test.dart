import 'dart:convert';

import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:coparentes/utils/secure_storage_options.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
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
    storage = E2eKeyStorageService(secureStorage: buildSecureStorage());
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

  test('storeUnlockedKeyPair does not write to FlutterSecureStorage', () async {
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

  // Unit tests run on the VM (kIsWeb == false). Persist/restore are
  // platform-agnostic — same SecureStorage path web and mobile use in production.
  test('persist + restore round-trip restores usable unlocked key', () async {
    expect(kIsWeb, isFalse,
        reason: 'VM unit tests; persist/restore must still succeed here.');

    final crypto = E2eCryptoService();
    final original = await (await crypto.generateKeyPair()).extract();
    final originalSeed = await original.extractPrivateKeyBytes();
    final originalPublic = (await original.extractPublicKey()).bytes;

    await storage.persistUnlockedKeyToDevice(original);

    expect(
      backingStore.containsKey(E2eKeyStorageService.unlockedKeySeedStorageKey),
      isTrue,
    );
    expect(
      backingStore.containsKey(E2eKeyStorageService.unlockedKeyPublicStorageKey),
      isTrue,
    );

    // Fresh service instance (empty RAM) reading the same durable store.
    final restoredStorage =
        E2eKeyStorageService(secureStorage: buildSecureStorage());
    final ok = await restoredStorage.restoreUnlockedKeyFromDevice();
    expect(ok, isTrue);

    await restoredStorage.useUnlockedKeyPair((key) async {
      expect(await key.extractPrivateKeyBytes(), originalSeed);
      expect((await key.extractPublicKey()).bytes, originalPublic);
      expect(key.type, KeyPairType.x25519);
    });
  });

  test('restoreUnlockedKeyFromDevice returns false when nothing persisted',
      () async {
    final ok = await storage.restoreUnlockedKeyFromDevice();
    expect(ok, isFalse);
    await expectLater(
      () => storage.useUnlockedKeyPair((_) async => null),
      throwsA(isA<NoUnlockedKeyException>()),
    );
  });

  test('restoreUnlockedKeyFromDevice clears corrupted data and returns false',
      () async {
    backingStore[E2eKeyStorageService.unlockedKeySeedStorageKey] =
        '!!!not-valid-base64!!!';
    backingStore[E2eKeyStorageService.unlockedKeyPublicStorageKey] =
        base64Encode(List<int>.filled(32, 1));

    final ok = await storage.restoreUnlockedKeyFromDevice();
    expect(ok, isFalse);
    expect(
      backingStore.containsKey(E2eKeyStorageService.unlockedKeySeedStorageKey),
      isFalse,
    );
    expect(
      backingStore.containsKey(E2eKeyStorageService.unlockedKeyPublicStorageKey),
      isFalse,
    );
    await expectLater(
      () => storage.useUnlockedKeyPair((_) async => null),
      throwsA(isA<NoUnlockedKeyException>()),
    );
  });

  test('clearAll also clears persisted device key', () async {
    final crypto = E2eCryptoService();
    final unlocked = await (await crypto.generateKeyPair()).extract();

    await storage.persistUnlockedKeyToDevice(unlocked);
    await storage.storeUnlockedKeyPair(unlocked);
    await storage.cacheEncryptedEnvelope('envelope');

    await storage.clearAll();

    expect(backingStore, isEmpty);
    expect(await storage.restoreUnlockedKeyFromDevice(), isFalse);
  });
}
