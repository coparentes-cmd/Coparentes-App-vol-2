import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown by [E2eKeyStorageService.useUnlockedKeyPair] when no key is unlocked
/// in process memory for this session.
class NoUnlockedKeyException implements Exception {
  @override
  String toString() =>
      'NoUnlockedKeyException: no unlocked E2E key pair in session memory';
}

/// Session + durable storage for E2E key material.
///
/// - Unlocked (plaintext) private key: **process memory only** — gone on app kill.
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
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String encryptedEnvelopeStorageKey =
      'coparentes_e2e_private_key_envelope_v1';

  final FlutterSecureStorage _secureStorage;

  /// In-memory only — never written to disk / Keychain / Keystore.
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

  /// Clears in-memory unlocked key and durable envelope cache (logout).
  Future<void> clearAll() async {
    _unlockedKeyPair?.destroy();
    _unlockedKeyPair = null;
    await _secureStorage.delete(key: encryptedEnvelopeStorageKey);
  }
}
