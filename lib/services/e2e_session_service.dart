import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../data/api/app_api_client.dart';
import '../data/repositories/user_keys_remote.dart';
import 'e2e_crypto_service.dart';
import 'e2e_key_storage_service.dart';

/// Fresh identity material for atomic password + key replacement.
class E2eReplacementKeyMaterial {
  const E2eReplacementKeyMaterial({
    required this.publicKey,
    required this.privateKeyEnvelope,
    required this.keyPairData,
  });

  final String publicKey;
  final String privateKeyEnvelope;
  final SimpleKeyPairData keyPairData;
}

/// Outcome of [E2eSessionService.fetchPublicKeysForUsers].
///
/// Callers (e.g. thread creation in F4.3) decide whether [missingKey] / [failed]
/// block the flow; this type only reports the full picture.
class FetchPublicKeysResult {
  const FetchPublicKeysResult({
    required this.resolved,
    required this.missingKey,
    required this.failed,
  });

  /// Successfully fetched and decoded public keys.
  final Map<String, SimplePublicKey> resolved;

  /// User ids for which the backend returned `publicKey: null` (no key yet).
  final List<String> missingKey;

  /// User ids that failed with a network / API / decode error.
  /// Values are the caught [Object] (typically [ApiException] or [FormatException]).
  final Map<String, Object> failed;

  bool get hasFailures => failed.isNotEmpty;
  bool get hasMissingKeys => missingKey.isNotEmpty;
  bool get isComplete => failed.isEmpty && missingKey.isEmpty;
}

/// Thrown when recovery-code unlock is attempted but the account has no
/// `recoveryKeyEnvelope` (pre-R2 account, or user never generated a code).
class RecoveryCodeNotSetUpException implements Exception {
  @override
  String toString() =>
      'RecoveryCodeNotSetUpException: no recoveryKeyEnvelope on this account';
}

/// Thrown when [E2eSessionService.buildThreadKeysPayload] cannot seal for every
/// participant (missing public keys and/or fetch/decode failures).
class IncompleteParticipantKeysException implements Exception {
  IncompleteParticipantKeysException({
    required this.missingKey,
    required this.failed,
  });

  final List<String> missingKey;
  final Map<String, Object> failed;

  @override
  String toString() =>
      'IncompleteParticipantKeysException(missingKey: $missingKey, '
      'failed: ${failed.keys.toList()})';
}

/// Orchestrates invisible E2E key setup / unlock around auth flows.
///
/// Failures are best-effort: they are logged and never block auth UX.
///
/// Ulepszenie UX: dla userów z ustawionym PinLockStore PIN-em, prompt o hasło
/// przy pierwszym wejściu do czatu mógłby być zastąpiony odblokowaniem przez PIN
/// zamiast pełnego hasła logowania — wymaga dodatkowego materiału kryptograficznego
/// (osobny klucz wrapujący envelope pod PIN-em), nie zaimplementowane w tej fazie.
class E2eSessionService {
  E2eSessionService({
    required AppApiClient apiClient,
    E2eCryptoService? crypto,
    E2eKeyStorageService? keyStorage,
    UserKeysRemote? userKeysRemote,
  })  : _apiClient = apiClient,
        _crypto = crypto ?? E2eCryptoService(),
        _keyStorage = keyStorage ?? E2eKeyStorageService(),
        _userKeys = userKeysRemote ?? UserKeysRemote(apiClient: apiClient);

  final AppApiClient _apiClient;
  final E2eCryptoService _crypto;
  final E2eKeyStorageService _keyStorage;
  final UserKeysRemote _userKeys;

  /// In-memory only — plaintext thread keys for this process session.
  final Map<String, Uint8List> _threadKeyCache = {};

  /// In-flight ThreadKey fetches (single-flight / cache-miss dedupe).
  final Map<String, Future<Uint8List>> _threadKeyFetches = {};

  /// threadId → child userIds already synced (or confirmed via 409) this process.
  final Map<String, Set<String>> _familySyncedChildIdsByThread = {};

  E2eKeyStorageService get keyStorage => _keyStorage;

  /// Whether an unlocked private key is already in process memory.
  Future<bool> hasUnlockedKey() async {
    try {
      await _keyStorage.useUnlockedKeyPair((_) async {});
      return true;
    } on NoUnlockedKeyException {
      return false;
    }
  }

  /// Generate + upload + unlock + cache (registration / first-time bootstrap).
  Future<void> setupNewKeys(String password) async {
    final material = await createReplacementKeyMaterial(password);

    await _apiClient.postJson('/user/keys', {
      'publicKey': material.publicKey,
      'privateKeyEnvelope': material.privateKeyEnvelope,
    });

    await applyReplacementKeyMaterial(material);
  }

  /// Like [setupNewKeys], plus a second envelope sealed with a Crockford recovery
  /// code (same X25519 private key). Returns the plaintext code for one-shot UI.
  ///
  /// Order: upload password envelope → unlock locally → upload recovery envelope.
  /// If recovery upload fails after keys are applied, the caller should not show
  /// the recovery screen (keys still work; code can be created later in Settings).
  Future<String> setupNewKeysWithRecoveryCode(String password) async {
    final keyPair = await _crypto.generateKeyPair();
    final keyPairData = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyEnvelope = await _crypto.createPrivateKeyEnvelope(
      keyPair: keyPair,
      password: password,
    );

    final publicKeyEncoded = _crypto.encodePublicKey(publicKey);
    await _apiClient.postJson('/user/keys', {
      'publicKey': publicKeyEncoded,
      'privateKeyEnvelope': privateKeyEnvelope,
    });

    await applyReplacementKeyMaterial(
      E2eReplacementKeyMaterial(
        publicKey: publicKeyEncoded,
        privateKeyEnvelope: privateKeyEnvelope,
        keyPairData: keyPairData,
      ),
    );

    final recoveryCode = _crypto.createRecoveryCode();
    // Same keyPair object → same private bytes as the password envelope.
    final recoveryEnvelope = await _crypto.createPrivateKeyEnvelope(
      keyPair: keyPair,
      password: recoveryCode,
    );

    await _apiClient.postJson('/user/recovery-key', {
      'recoveryKeyEnvelope': recoveryEnvelope,
      'recoveryCode': recoveryCode,
    });

    return recoveryCode;
  }

  /// Rotate to a fresh identity pair under [currentPassword], abandoning history
  /// sealed to the previous private key (post password-reset orphan recovery).
  ///
  /// Sends [currentPassword] so the backend can bcrypt-verify before overwrite.
  Future<E2eReplacementKeyMaterial> replaceKeysAbandoningHistory(
    String currentPassword,
  ) async {
    final material = await createReplacementKeyMaterial(currentPassword);
    await _apiClient.postJson('/user/keys', {
      'publicKey': material.publicKey,
      'privateKeyEnvelope': material.privateKeyEnvelope,
      'currentPassword': currentPassword,
    });
    await applyReplacementKeyMaterial(material);
    return material;
  }

  /// Fresh X25519 pair + envelope under [password] (no network).
  ///
  /// Used when the existing envelope cannot be unlocked (orphaned after
  /// forgot-password / admin hash reset) and password change must rotate
  /// identity keys atomically via `POST /auth/password`.
  Future<E2eReplacementKeyMaterial> createReplacementKeyMaterial(
    String password,
  ) async {
    final keyPair = await _crypto.generateKeyPair();
    final keyPairData = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();
    final envelope = await _crypto.createPrivateKeyEnvelope(
      keyPair: keyPair,
      password: password,
    );
    return E2eReplacementKeyMaterial(
      publicKey: _crypto.encodePublicKey(publicKey),
      privateKeyEnvelope: envelope,
      keyPairData: keyPairData,
    );
  }

  Future<void> applyReplacementKeyMaterial(
    E2eReplacementKeyMaterial material,
  ) async {
    await _keyStorage.storeUnlockedKeyPair(material.keyPairData);
    await _keyStorage.persistUnlockedKeyToDevice(material.keyPairData);
    await _keyStorage.cacheEncryptedEnvelope(material.privateKeyEnvelope);
  }

  /// Unlock after login (swallows [InvalidPasswordException] — auth already succeeded).
  Future<void> unlockAfterAuthentication(String password) async {
    try {
      await unlockWithPassword(password);
    } on InvalidPasswordException {
      debugPrint(
        '[e2e] envelope decrypt failed after auth (InvalidPasswordException)',
      );
    }
  }

  /// Unlock for messaging / password-change UI.
  ///
  /// Restores a previously persisted device key when present and skips envelope
  /// fetch + Argon2 (web and mobile). Throws [InvalidPasswordException] when the
  /// password does not open the envelope (slow path only).
  Future<void> unlockWithPassword(String password) async {
    // Fast path: key already persisted on this device from a previous unlock.
    final restoredFromDevice = await _keyStorage.restoreUnlockedKeyFromDevice();
    if (restoredFromDevice) {
      return; // Skip envelope fetch + Argon2 entirely.
    }

    var envelope = await _keyStorage.getCachedEncryptedEnvelope();
    var fromServer = false;

    if (envelope == null || envelope.isEmpty) {
      final mine = await _fetchKeysMine();
      envelope = mine.privateKeyEnvelope;
      fromServer = true;
    }

    if (envelope == null || envelope.isEmpty) {
      // Legacy / pre-E2E account (or failed prior upload): create keys now.
      await setupNewKeys(password);
      return;
    }

    final keyPair = await _crypto.decryptPrivateKeyEnvelope(
      envelope: envelope,
      password: password,
    );
    await _keyStorage.storeUnlockedKeyPair(keyPair);
    await _keyStorage.persistUnlockedKeyToDevice(keyPair);
    if (fromServer) {
      await _keyStorage.cacheEncryptedEnvelope(envelope);
    }
  }

  /// Best-effort retry when logged-in user still has empty keys on server.
  Future<void> retrySetupIfMissing(String password) async {
    try {
      final mine = await _fetchKeysMine();
      if ((mine.publicKey == null || mine.publicKey!.isEmpty) &&
          (mine.privateKeyEnvelope == null ||
              mine.privateKeyEnvelope!.isEmpty)) {
        await setupNewKeys(password);
      }
    } catch (error) {
      debugPrint('[e2e] retrySetupIfMissing failed: $error');
    }
  }

  /// Rewrap the same unlocked key under [newPassword].
  ///
  /// Throws [NoUnlockedKeyException] if nothing is unlocked in memory.
  Future<String> rewrapEnvelopeForNewPassword(String newPassword) {
    return _keyStorage.useUnlockedKeyPair((keyPair) async {
      final envelope = await _crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: newPassword,
      );
      return envelope;
    });
  }

  /// Settings / R3: wrap the already-unlocked identity key under a new recovery
  /// code and upload it. Returns the plaintext code for one-shot UI display.
  ///
  /// Throws [NoUnlockedKeyException] if the private key is not in RAM.
  Future<String> generateRecoveryCodeForExistingKey() async {
    final recoveryCode = _crypto.createRecoveryCode();
    final envelope = await _keyStorage.useUnlockedKeyPair((keyPair) {
      return _crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: recoveryCode,
      );
    });
    await _apiClient.postJson('/user/recovery-key', {
      'recoveryKeyEnvelope': envelope,
      'recoveryCode': recoveryCode,
    });
    return recoveryCode;
  }

  /// R4: decrypt the original identity key with a mailed recovery code, then
  /// rewrap it under [currentPassword] (fixes an orphaned password envelope
  /// without rotating the X25519 public key / abandoning history).
  ///
  /// Throws [RecoveryCodeNotSetUpException] when the account has no recovery
  /// envelope. Throws [InvalidPasswordException] when the code is wrong.
  /// Backend may throw [ApiException] 401 when [currentPassword] is wrong.
  Future<void> recoverWithCode(String rawCode, String currentPassword) async {
    final normalizedCode = E2eCryptoService.normalizeRecoveryCodeInput(rawCode);

    final mine = await _fetchKeysMine();
    final recoveryEnvelope = mine.recoveryKeyEnvelope;
    if (recoveryEnvelope == null || recoveryEnvelope.isEmpty) {
      throw RecoveryCodeNotSetUpException();
    }

    final keyPair = await _crypto.decryptPrivateKeyEnvelope(
      envelope: recoveryEnvelope,
      password: normalizedCode,
    );

    final newPasswordEnvelope = await _crypto.createPrivateKeyEnvelope(
      keyPair: keyPair,
      password: currentPassword,
    );

    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = _crypto.encodePublicKey(publicKey);

    await _apiClient.postJson('/user/keys', {
      'publicKey': encodedPublicKey,
      'privateKeyEnvelope': newPasswordEnvelope,
      'currentPassword': currentPassword,
    });

    await applyReplacementKeyMaterial(
      E2eReplacementKeyMaterial(
        publicKey: encodedPublicKey,
        privateKeyEnvelope: newPasswordEnvelope,
        keyPairData: keyPair,
      ),
    );
  }

  Future<void> cacheEnvelope(String envelope) {
    return _keyStorage.cacheEncryptedEnvelope(envelope);
  }

  Future<void> clearAll() async {
    _clearThreadKeyCache();
    _familySyncedChildIdsByThread.clear();
    await _keyStorage.clearAll();
  }

  /// Best-effort: seal this family's ThreadKey for [childUserId] and POST
  /// `/threads/{threadId}/keys/family-sync`. No-ops when the child has no
  /// publicKey yet, or when this session already synced that child for
  /// [threadId]. Treats HTTP 409 `already_exists` as success.
  Future<void> syncFamilyThreadKeyIfNeeded({
    required String threadId,
    required String childUserId,
  }) async {
    final already =
        _familySyncedChildIdsByThread[threadId] ?? const <String>{};
    if (already.contains(childUserId)) {
      return;
    }

    final keys = await fetchPublicKeysForUsers([childUserId]);
    final childPublicKey = keys.resolved[childUserId];
    if (childPublicKey == null) {
      // missingKey or failed — child has no usable E2E public key yet.
      return;
    }

    // Same path as encrypt/decrypt: process cache or GET /threads/:id/keys/mine
    // then openSealedBox with the unlocked identity key.
    final threadKeyBytes = await _threadKeyBytesFor(threadId);

    final encryptedKey = await _crypto.sealForRecipient(
      plaintext: threadKeyBytes,
      recipientPublicKey: childPublicKey,
    );

    try {
      await _apiClient.postJson('/threads/$threadId/keys/family-sync', {
        'userId': childUserId,
        'encryptedKey': encryptedKey,
      });
    } on ApiException catch (error) {
      if (error.statusCode == 409 || error.message == 'already_exists') {
        // Backend: key already present — success for our purposes.
      } else {
        rethrow;
      }
    }

    _familySyncedChildIdsByThread
        .putIfAbsent(threadId, () => <String>{})
        .add(childUserId);
  }

  /// Encrypts [plaintext] for an existing thread (AES-GCM under the ThreadKey).
  ///
  /// Throws [NoUnlockedKeyException] if the private key is not unlocked.
  Future<({String ciphertext, String nonce})> encryptMessageForThread({
    required String threadId,
    required String plaintext,
  }) async {
    final threadKey = await _threadKeyBytesFor(threadId);
    return _crypto.encryptWithThreadKey(
      threadKeyBytes: threadKey,
      plaintext: utf8.encode(plaintext),
    );
  }

  /// Decrypts an E2E message ciphertext for [threadId].
  ///
  /// Throws [NoUnlockedKeyException] or [MessageDecryptionException].
  Future<String> decryptMessageFromThread({
    required String threadId,
    required String ciphertext,
    required String nonce,
  }) async {
    final threadKey = await _threadKeyBytesFor(threadId);
    try {
      final bytes = await _crypto.decryptWithThreadKey(
        threadKeyBytes: threadKey,
        ciphertext: ciphertext,
        nonce: nonce,
      );
      return utf8.decode(bytes);
    } on SecretBoxAuthenticationError catch (error) {
      throw MessageDecryptionException(error);
    } on ArgumentError catch (error) {
      throw MessageDecryptionException(error);
    } on FormatException catch (error) {
      throw MessageDecryptionException(error);
    }
  }

  Future<Uint8List> _threadKeyBytesFor(String threadId) async {
    final cached = _threadKeyCache[threadId];
    if (cached != null) {
      return cached;
    }

    return _threadKeyFetches.putIfAbsent(threadId, () async {
      try {
        final payload =
            await _apiClient.getJson('/threads/$threadId/keys/mine');
        final encryptedKey = payload['encryptedKey'] as String?;
        if (encryptedKey == null || encryptedKey.isEmpty) {
          throw MessageDecryptionException('thread_key_not_found');
        }

        final opened = await _keyStorage.useUnlockedKeyPair((keyPair) {
          return _crypto.openSealedBox(
            sealedBox: encryptedKey,
            recipientKeyPair: keyPair,
          );
        });

        final bytes =
            opened is Uint8List ? opened : Uint8List.fromList(opened);
        _threadKeyCache[threadId] = bytes;
        return bytes;
      } catch (_) {
        // Allow a later call to retry instead of replaying a failed Future.
        _threadKeyFetches.remove(threadId);
        rethrow;
      }
    });
  }

  void _clearThreadKeyCache() {
    for (final bytes in _threadKeyCache.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _threadKeyCache.clear();
    _threadKeyFetches.clear();
  }

  /// Builds `{ userId, encryptedKey }` entries for POST /threads (and channels).
  ///
  /// [participantUserIds] must match backend rules: currently parentA+parentB
  /// only (family child keys are synced later via `/keys/family-sync`).
  ///
  /// Throws [IncompleteParticipantKeysException] when any participant is missing
  /// a usable public key.
  Future<List<Map<String, String>>> buildThreadKeysPayload({
    required List<String> participantUserIds,
  }) async {
    final uniqueIds = participantUserIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      throw IncompleteParticipantKeysException(
        missingKey: const [],
        failed: const {},
      );
    }

    final threadKey = _crypto.generateThreadKey();
    try {
      final keys = await fetchPublicKeysForUsers(uniqueIds);
      if (!keys.isComplete) {
        debugPrint(
          '[e2e] buildThreadKeysPayload incomplete: '
          'missingKey=${keys.missingKey} failed=${keys.failed.keys.toList()}',
        );
        throw IncompleteParticipantKeysException(
          missingKey: List<String>.from(keys.missingKey),
          failed: Map<String, Object>.from(keys.failed),
        );
      }

      final payload = <Map<String, String>>[];
      for (final userId in uniqueIds) {
        final publicKey = keys.resolved[userId];
        if (publicKey == null) {
          throw IncompleteParticipantKeysException(
            missingKey: [userId],
            failed: const {},
          );
        }
        final encryptedKey = await _crypto.sealForRecipient(
          plaintext: threadKey,
          recipientPublicKey: publicKey,
        );
        payload.add({
          'userId': userId,
          'encryptedKey': encryptedKey,
        });
      }
      return payload;
    } finally {
      threadKey.fillRange(0, threadKey.length, 0);
    }
  }

  /// Fetches and decodes X25519 public keys for [userIds] in parallel.
  ///
  /// Each user is handled independently: a network / API / decode failure for
  /// one id does not discard successes for the others.
  ///
  /// Approach: [Future.wait] over per-user futures that **never throw** — each
  /// future catches its own errors and returns a small outcome record. That is
  /// clearer in Dart than `eagerError: false` (which still surfaces the first
  /// error as the wait result and leaves other outcomes harder to collect).
  ///
  /// Example:
  /// ```dart
  /// final keys = await e2e.fetchPublicKeysForUsers(memberIds);
  /// // keys.resolved[userId] → SimplePublicKey for sealing ThreadKey
  /// // keys.missingKey → users who have not uploaded a public key yet
  /// // keys.failed[userId] → network / decode error for that user
  /// if (!keys.isComplete) {
  ///   // F4.3: decide UX (block thread create, show which users, retry, …)
  /// }
  /// ```
  Future<FetchPublicKeysResult> fetchPublicKeysForUsers(
    List<String> userIds,
  ) async {
    final uniqueIds = userIds.toSet().toList();

    final outcomes = await Future.wait(
      uniqueIds.map(_fetchOnePublicKeyOutcome),
    );

    final resolved = <String, SimplePublicKey>{};
    final missingKey = <String>[];
    final failed = <String, Object>{};

    for (final outcome in outcomes) {
      switch (outcome.status) {
        case _PublicKeyFetchStatus.resolved:
          resolved[outcome.userId] = outcome.publicKey!;
        case _PublicKeyFetchStatus.missing:
          missingKey.add(outcome.userId);
        case _PublicKeyFetchStatus.failed:
          failed[outcome.userId] = outcome.error!;
      }
    }

    return FetchPublicKeysResult(
      resolved: resolved,
      missingKey: missingKey,
      failed: failed,
    );
  }

  Future<_PublicKeyFetchOutcome> _fetchOnePublicKeyOutcome(String userId) async {
    try {
      final publicKeyB64 = await _userKeys.fetchPublicKey(userId);
      if (publicKeyB64 == null) {
        debugPrint(
          '[e2e] fetchPublicKeysForUsers: skipping userId=$userId '
          '(no publicKey yet)',
        );
        return _PublicKeyFetchOutcome.missing(userId);
      }
      try {
        final publicKey = _crypto.decodePublicKey(publicKeyB64);
        return _PublicKeyFetchOutcome.resolved(userId, publicKey);
      } catch (error) {
        debugPrint(
          '[e2e] fetchPublicKeysForUsers: decode failed for userId=$userId: '
          '$error',
        );
        return _PublicKeyFetchOutcome.failed(userId, error);
      }
    } catch (error) {
      debugPrint(
        '[e2e] fetchPublicKeysForUsers: fetch failed for userId=$userId: '
        '$error',
      );
      return _PublicKeyFetchOutcome.failed(userId, error);
    }
  }

  Future<
      ({
        String? publicKey,
        String? privateKeyEnvelope,
        String? recoveryKeyEnvelope,
      })> _fetchKeysMine() async {
    final payload = await _apiClient.getJson('/user/keys/mine');
    return (
      publicKey: payload['publicKey'] as String?,
      privateKeyEnvelope: payload['privateKeyEnvelope'] as String?,
      recoveryKeyEnvelope: payload['recoveryKeyEnvelope'] as String?,
    );
  }
}

enum _PublicKeyFetchStatus { resolved, missing, failed }

class _PublicKeyFetchOutcome {
  const _PublicKeyFetchOutcome._({
    required this.userId,
    required this.status,
    this.publicKey,
    this.error,
  });

  factory _PublicKeyFetchOutcome.resolved(
    String userId,
    SimplePublicKey publicKey,
  ) {
    return _PublicKeyFetchOutcome._(
      userId: userId,
      status: _PublicKeyFetchStatus.resolved,
      publicKey: publicKey,
    );
  }

  factory _PublicKeyFetchOutcome.missing(String userId) {
    return _PublicKeyFetchOutcome._(
      userId: userId,
      status: _PublicKeyFetchStatus.missing,
    );
  }

  factory _PublicKeyFetchOutcome.failed(String userId, Object error) {
    return _PublicKeyFetchOutcome._(
      userId: userId,
      status: _PublicKeyFetchStatus.failed,
      error: error,
    );
  }

  final String userId;
  final _PublicKeyFetchStatus status;
  final SimplePublicKey? publicKey;
  final Object? error;
}
