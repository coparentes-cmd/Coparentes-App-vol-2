import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureOfflineCodec {
  static const _keyStorageKey = 'coparentes_offline_aes_key_v1';
  static const _encryptedPrefix = 'enc:';

  final FlutterSecureStorage? _secureStorage;
  encrypt.Key? _cachedKey;

  SecureOfflineCodec({FlutterSecureStorage? secureStorage})
      : _secureStorage = kIsWeb
            ? null
            : (secureStorage ?? const FlutterSecureStorage());

  bool get isEnabled => _secureStorage != null;

  Future<void> initialize() async {
    if (!isEnabled) {
      return;
    }
    _cachedKey = await _loadOrCreateKey();
  }

  String? encryptString(String plaintext) {
    if (!isEnabled || _cachedKey == null) {
      return null;
    }

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_cachedKey!));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '$_encryptedPrefix${iv.base64}:${encrypted.base64}';
  }

  String? decryptString(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (!raw.startsWith(_encryptedPrefix)) {
      return raw;
    }
    if (!isEnabled || _cachedKey == null) {
      return null;
    }

    final payload = raw.substring(_encryptedPrefix.length);
    final separator = payload.indexOf(':');
    if (separator <= 0) {
      return null;
    }

    final iv = encrypt.IV.fromBase64(payload.substring(0, separator));
    final encrypted = encrypt.Encrypted.fromBase64(payload.substring(separator + 1));
    final encrypter = encrypt.Encrypter(encrypt.AES(_cachedKey!));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future<encrypt.Key> _loadOrCreateKey() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    final storage = _secureStorage!;
    var encoded = await storage.read(key: _keyStorageKey);
    if (encoded == null || encoded.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      encoded = base64Encode(bytes);
      await storage.write(key: _keyStorageKey, value: encoded);
    }

    _cachedKey = encrypt.Key(base64Decode(encoded));
    return _cachedKey!;
  }
}

Map<String, dynamic> sanitizeSessionPayloadForCache(
  Map<String, dynamic> payload,
) {
  final copy = Map<String, dynamic>.from(payload);
  copy.remove('token');

  if (kIsWeb) {
    final workspace = copy['workspace'];
    if (workspace is Map) {
      copy['workspace'] = {'id': workspace['id']};
    }
    copy.remove('user');
  }

  return copy;
}
