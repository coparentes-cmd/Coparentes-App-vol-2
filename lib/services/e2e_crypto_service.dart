import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:cryptography/helpers.dart';

/// Thrown when [E2eCryptoService.decryptPrivateKeyEnvelope] sees an unknown
/// envelope version (`v` ≠ 1).
class UnsupportedEnvelopeVersionException implements Exception {
  UnsupportedEnvelopeVersionException(this.version);

  final Object? version;

  @override
  String toString() =>
      'UnsupportedEnvelopeVersionException: unsupported envelope version $version';
}

/// Thrown when GCM authentication fails while opening a private-key envelope
/// (almost always a wrong password).
class InvalidPasswordException implements Exception {
  @override
  String toString() =>
      'InvalidPasswordException: wrong password or corrupted private-key envelope';
}

/// Thrown when a sealed box cannot be opened (wrong recipient key or corruption).
class SealedBoxDecryptionException implements Exception {
  @override
  String toString() =>
      'SealedBoxDecryptionException: sealed box could not be decrypted';
}

/// Thrown when an E2E message cannot be decrypted with the thread key.
class MessageDecryptionException implements Exception {
  MessageDecryptionException([this.cause]);

  final Object? cause;

  @override
  String toString() =>
      'MessageDecryptionException: message could not be decrypted'
      '${cause == null ? '' : ' ($cause)'}';
}

/// Pure-Dart E2E crypto core (X25519 + Argon2id + AES-256-GCM + sealed boxes).
///
/// No UI / network dependencies — safe to unit-test in isolation.
class E2eCryptoService {
  E2eCryptoService({
    X25519? x25519,
    AesGcm? aesGcm,
    Hkdf? hkdf,
  })  : _x25519 = x25519 ?? X25519(),
        _aesGcm = aesGcm ?? AesGcm.with256bits(),
        _hkdf = hkdf ??
            Hkdf(
              hmac: Hmac.sha256(),
              outputLength: 32,
            );

  static const int defaultKdfMemoryKb = 19456;
  static const int defaultKdfIterations = 2;
  static const int defaultKdfParallelism = 1;
  static const int defaultKdfHashLength = 32;
  static const int saltLength = 16;
  static const int threadKeyLength = 32;
  static const int envelopeVersion = 1;
  static const int sealedBoxVersion = 1;
  static const String sealedBoxHkdfInfo = 'coparentes-e2e-threadkey-v1';

  final X25519 _x25519;
  final AesGcm _aesGcm;
  final Hkdf _hkdf;

  /// Generates a fresh X25519 key pair.
  Future<SimpleKeyPair> generateKeyPair() => _x25519.newKeyPair();

  /// Random 32-byte symmetric key for a new E2E thread (AES-256).
  Uint8List generateThreadKey() {
    final bytes = Uint8List(threadKeyLength);
    fillBytesWithSecureRandom(bytes);
    return bytes;
  }

  /// Derives a 32-byte wrapping key from [password] via Argon2id
  /// (default create-time parameters).
  Future<SecretKey> deriveKeyFromPassword({
    required String password,
    required List<int> salt,
  }) {
    final argon2 = DartArgon2id(
      parallelism: defaultKdfParallelism,
      memory: defaultKdfMemoryKb,
      iterations: defaultKdfIterations,
      hashLength: defaultKdfHashLength,
    );
    return argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  /// Wraps [keyPair]'s private key under [password] into an opaque JSON envelope.
  Future<String> createPrivateKeyEnvelope({
    required SimpleKeyPair keyPair,
    required String password,
  }) async {
    final salt = Uint8List(saltLength);
    fillBytesWithSecureRandom(salt);

    final wrappingKey = await deriveKeyFromPassword(
      password: password,
      salt: salt,
    );

    // Uwaga: surowe bajty klucza prywatnego nie są jawnie zerowane w pamięci po
    // użyciu - extractPrivateKeyBytes() zwraca niemutowalny SensitiveBytes
    // współdzielony z keyPair (nie Uint8List); ograniczenie modelu pamięci
    // Dart/GC, ten sam kompromis co przy poprzednim PoC.
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      privateKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
    );

    // ciphertext + GCM tag together (no nonce — nonce is a separate field).
    final ciphertextWithTag = secretBox.concatenation(nonce: false);

    final envelope = <String, Object>{
      'v': envelopeVersion,
      'kdf': <String, Object>{
        'algo': 'argon2id',
        'salt': base64Encode(salt),
        'memory': defaultKdfMemoryKb,
        'iterations': defaultKdfIterations,
        'parallelism': defaultKdfParallelism,
      },
      'cipher': <String, Object>{
        'algo': 'aes256gcm',
        'nonce': base64Encode(secretBox.nonce),
        'ciphertext': base64Encode(ciphertextWithTag),
      },
    };

    return jsonEncode(envelope);
  }

  /// Opens a private-key envelope with [password].
  ///
  /// KDF parameters are read from the envelope (not from create-time defaults)
  /// so older envelopes remain decryptable after parameter changes.
  Future<SimpleKeyPairData> decryptPrivateKeyEnvelope({
    required String envelope,
    required String password,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(envelope);
    } on FormatException {
      throw const FormatException('private-key envelope must be a JSON object');
    }
    if (decoded is! Map) {
      throw const FormatException('private-key envelope must be a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);

    final version = map['v'];
    if (version != envelopeVersion) {
      throw UnsupportedEnvelopeVersionException(version);
    }

    final kdf = Map<String, dynamic>.from(map['kdf'] as Map);
    final cipher = Map<String, dynamic>.from(map['cipher'] as Map);

    final salt = base64Decode(kdf['salt'] as String);
    final memory = kdf['memory'] as int;
    final iterations = kdf['iterations'] as int;
    final parallelism = kdf['parallelism'] as int;

    final argon2 = DartArgon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: defaultKdfHashLength,
    );
    final wrappingKey = await argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final nonce = base64Decode(cipher['nonce'] as String);
    final ciphertextWithTag = base64Decode(cipher['ciphertext'] as String);
    final macLength = _aesGcm.macAlgorithm.macLength;
    if (ciphertextWithTag.length <= macLength) {
      throw InvalidPasswordException();
    }

    final cipherText = ciphertextWithTag.sublist(
      0,
      ciphertextWithTag.length - macLength,
    );
    final macBytes = ciphertextWithTag.sublist(
      ciphertextWithTag.length - macLength,
    );

    final List<int> privateKeyBytes;
    try {
      privateKeyBytes = await _aesGcm.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: wrappingKey,
      );
    } on SecretBoxAuthenticationError {
      throw InvalidPasswordException();
    }

    // DartAesGcm.decrypt returns Uint8List; wipe local plaintext after seed copy.
    // (If a future impl returned non-mutable List<int>: no wipe possible —
    // same Dart/GC compromise as the Node PoC / createPrivateKeyEnvelope path.)
    try {
      final restored = await _x25519.newKeyPairFromSeed(privateKeyBytes);
      return restored.extract();
    } finally {
      if (privateKeyBytes is Uint8List) {
        privateKeyBytes.fillRange(0, privateKeyBytes.length, 0);
      }
    }
  }

  /// Encodes an X25519 public key as standard base64.
  String encodePublicKey(SimplePublicKey publicKey) =>
      base64Encode(publicKey.bytes);

  /// Decodes a standard-base64 X25519 public key.
  SimplePublicKey decodePublicKey(String encoded) {
    return SimplePublicKey(
      base64Decode(encoded),
      type: KeyPairType.x25519,
    );
  }

  /// Encrypts message plaintext with a 32-byte thread key (AES-256-GCM).
  Future<({String ciphertext, String nonce})> encryptWithThreadKey({
    required List<int> threadKeyBytes,
    required List<int> plaintext,
  }) async {
    final secretKey = SecretKey(threadKeyBytes);
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    final ciphertextWithTag = secretBox.concatenation(nonce: false);
    return (
      ciphertext: base64Encode(ciphertextWithTag),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Decrypts a message produced by [encryptWithThreadKey].
  ///
  /// Throws [SecretBoxAuthenticationError] / [ArgumentError] on bad data.
  Future<List<int>> decryptWithThreadKey({
    required List<int> threadKeyBytes,
    required String ciphertext,
    required String nonce,
  }) async {
    final secretKey = SecretKey(threadKeyBytes);
    final ciphertextWithTag = base64Decode(ciphertext);
    final nonceBytes = base64Decode(nonce);
    final macLength = _aesGcm.macAlgorithm.macLength;
    if (ciphertextWithTag.length <= macLength) {
      throw ArgumentError('ciphertext too short');
    }
    final cipherText = ciphertextWithTag.sublist(
      0,
      ciphertextWithTag.length - macLength,
    );
    final macBytes = ciphertextWithTag.sublist(
      ciphertextWithTag.length - macLength,
    );
    return _aesGcm.decrypt(
      SecretBox(
        cipherText,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      ),
      secretKey: secretKey,
    );
  }

  /// Seals [plaintext] for [recipientPublicKey] (ephemeral X25519 + HKDF + AES-GCM).
  ///
  /// Analogous to libsodium `crypto_box_seal`: only the recipient's private key
  /// can open the box. Returns opaque JSON string.
  Future<String> sealForRecipient({
    required List<int> plaintext,
    required SimplePublicKey recipientPublicKey,
  }) async {
    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: recipientPublicKey,
    );

    final wrappingKey = await _deriveSealedBoxKey(sharedSecret);

    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: wrappingKey,
      nonce: nonce,
    );
    final ciphertextWithTag = secretBox.concatenation(nonce: false);

    final sealed = <String, Object>{
      'v': sealedBoxVersion,
      'ephemeralPublicKey': encodePublicKey(ephemeralPublicKey),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(ciphertextWithTag),
    };

    // Best-effort: drop ephemeral private material from this object.
    if (ephemeralKeyPair is SimpleKeyPairData) {
      ephemeralKeyPair.destroy();
    }

    return jsonEncode(sealed);
  }

  /// Opens a sealed box produced by [sealForRecipient].
  Future<List<int>> openSealedBox({
    required String sealedBox,
    required SimpleKeyPairData recipientKeyPair,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(sealedBox);
    } on FormatException {
      throw SealedBoxDecryptionException();
    }
    if (decoded is! Map) {
      throw SealedBoxDecryptionException();
    }
    final map = Map<String, dynamic>.from(decoded);

    final version = map['v'];
    if (version != sealedBoxVersion) {
      throw UnsupportedEnvelopeVersionException(version);
    }

    final ephemeralPublicKey = decodePublicKey(
      map['ephemeralPublicKey'] as String,
    );
    final nonce = base64Decode(map['nonce'] as String);
    final ciphertextWithTag = base64Decode(map['ciphertext'] as String);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: ephemeralPublicKey,
    );
    final wrappingKey = await _deriveSealedBoxKey(sharedSecret);

    final macLength = _aesGcm.macAlgorithm.macLength;
    if (ciphertextWithTag.length <= macLength) {
      throw SealedBoxDecryptionException();
    }

    final cipherText = ciphertextWithTag.sublist(
      0,
      ciphertextWithTag.length - macLength,
    );
    final macBytes = ciphertextWithTag.sublist(
      ciphertextWithTag.length - macLength,
    );

    try {
      return await _aesGcm.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: wrappingKey,
      );
    } on SecretBoxAuthenticationError {
      // Wrong recipient key or tampered ciphertext/tag.
      throw SealedBoxDecryptionException();
    } on ArgumentError {
      // Malformed inputs from cryptography (e.g. wrong MAC/nonce/key length).
      throw SealedBoxDecryptionException();
    }
  }

  Future<SecretKey> _deriveSealedBoxKey(SecretKey sharedSecret) {
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const <int>[],
      info: utf8.encode(sealedBoxHkdfInfo),
    );
  }
}
