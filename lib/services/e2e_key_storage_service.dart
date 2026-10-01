import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/secure_storage_options.dart';

/// Thrown by [E2eKeyStorageService.useUnlockedKeyPair] when no key is unlocked
/// in process memory for this session.
class NoUnlockedKeyException implements Exception {
  @override
  String toString() =>
      'NoUnlockedKeyException: no unlocked E2E key pair in session memory';
}

/// Session + durable storage for E2E key material.
///
/// - Unlocked (plaintext) private key: held in process memory for the current
///   session, and also persisted via [persistUnlockedKeyToDevice] so relaunch /
///   page reload can skip Argon2. On mobile that is Keychain/Keystore; on web
///   [FlutterSecureStorage] maps to localStorage (not hardware-backed) — lower
///   local protection accepted for UX (no repeated password prompt).
/// - Password-wrapped envelope: [FlutterSecureStorage] (durable across launches).
///
/// Note on [SimpleKeyPairData.destroy]: package `cryptography` 2.9.0 does **not**
/// expose `overwriteWhenDestroyed` on [SimpleKeyPairData] / X25519 factories
/// (unlike [SecretKeyData]). `destroy()` only drops the internal reference
/// (`SensitiveBytes` defaults to `overwriteWhenDestroyed: false`) — it does not
/// zero private-key bytes. Same Dart/GC compromise as elsewhere; do not fake a
/// wipe that the public API cannot enable.
class E2eKeyStorageService {
  E2eKeyStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? buildSecureStorage();

  static const String encryptedEnvelopeStorageKey =
      'coparentes_e2e_private_key_envelope_v1';

  static const String unlockedKeySeedStorageKey =
      'coparentes_e2e_unlocked_key_seed_v1';
  static const String unlockedKeyPublicStorageKey =
      'coparentes_e2e_unlocked_key_public_v1';

  final FlutterSecureStorage _secureStorage;

  /// In-memory session holder — [storeUnlockedKeyPair] alone does not write to
  /// SecureStorage (see [persistUnlockedKeyToDevice]).
  SimpleKeyPairData? _unlockedKeyPair;

  /// Holds the decrypted key pair for the current app process lifetime.
  Future<void> storeUnlockedKeyPair(SimpleKeyPairData keyPair) async {
    _unlockedKeyPair?.destroy();
    // Keep the caller's instance (or its extract()); no copy — borrow API below
    // controls access. copy() would allocate another non-wipeable SensitiveBytes.
    _unlockedKeyPair = keyPair;
  }

  /// Runs [action] with the session's unlocked key (original reference, not a copy).
  ///
  /// Throws [NoUnlockedKeyException] if nothing is unlocked.
  Future<T> useUnlockedKeyPair<T>(
    Future<T> Function(SimpleKeyPairData keyPair) action,
  ) async {
    final keyPair = _unlockedKeyPair;
    if (keyPair == null) {
      throw NoUnlockedKeyException();
    }
    return action(keyPair);
  }

  /// Persists the UNLOCKED (plaintext) key to durable device storage.
  ///
  /// Same path on mobile and web: [FlutterSecureStorage] (Keychain/Keystore on
  /// native; localStorage-backed on web). Web lacks hardware-backed protection —
  /// accepted trade-off so reloads do not re-prompt for the password.
  Future<void> persistUnlockedKeyToDevice(SimpleKeyPairData keyPair) async {
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    await _secureStorage.write(
      key: unlockedKeySeedStorageKey,
      value: base64Encode(privateBytes),
    );
    await _secureStorage.write(
      key: unlockedKeyPublicStorageKey,
      value: base64Encode(publicKey.bytes),
    );
  }

  /// Restores a previously persisted key from device storage into session memory.
  ///
  /// Returns true if a key was found and restored, false otherwise.
  /// Works on web and mobile (same SecureStorage keys).
  Future<bool> restoreUnlockedKeyFromDevice() async {
    final seedB64 = await _secureStorage.read(key: unlockedKeySeedStorageKey);
    final publicB64 =
        await _secureStorage.read(key: unlockedKeyPublicStorageKey);
    if (seedB64 == null || publicB64 == null) return false;
    try {
      final keyPair = SimpleKeyPairData(
        base64Decode(seedB64),
        publicKey: SimplePublicKey(
          base64Decode(publicB64),
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
      );
      await storeUnlockedKeyPair(keyPair);
      return true;
    } catch (_) {
      // Corrupted/incompatible stored data — do not crash, just report "not found".
      await clearPersistedDeviceKey();
      return false;
    }
  }

  Future<void> clearPersistedDeviceKey() async {
    await _secureStorage.delete(key: unlockedKeySeedStorageKey);
    await _secureStorage.delete(key: unlockedKeyPublicStorageKey);
  }

  /// Persists the password-wrapped envelope (opaque to this layer).
  Future<void> cacheEncryptedEnvelope(String envelope) {
    return _secureStorage.write(
      key: encryptedEnvelopeStorageKey,
      value: envelope,
    );
  }

  /// Local durable copy of the server envelope, if any.
  Future<String?> getCachedEncryptedEnvelope() {
    return _secureStorage.read(key: encryptedEnvelopeStorageKey);
  }

  /// Clears in-memory unlocked key, durable envelope, and device key (logout).
  Future<void> clearAll() async {
    _unlockedKeyPair?.destroy();
    _unlockedKeyPair = null;
    await _secureStorage.delete(key: encryptedEnvelopeStorageKey);
    await clearPersistedDeviceKey();
  }
}
