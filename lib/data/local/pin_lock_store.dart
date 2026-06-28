import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLockStore {
  static String _requireKey(String userId) => 'pin_require_resume_$userId';
  static String _hashKey(String userId) => 'pin_hash_$userId';
  static String _saltKey(String userId) => 'pin_salt_$userId';

  final SharedPreferences _preferences;
  final FlutterSecureStorage? _secureStorage;

  PinLockStore({
    required SharedPreferences preferences,
    FlutterSecureStorage? secureStorage,
  })  : _preferences = preferences,
        _secureStorage = kIsWeb
            ? null
            : (secureStorage ?? const FlutterSecureStorage());

  Future<bool> isRequirePinOnResume(String userId) async {
    return _preferences.getBool(_requireKey(userId)) ?? false;
  }

  Future<void> setRequirePinOnResume(String userId, bool value) async {
    await _preferences.setBool(_requireKey(userId), value);
  }

  Future<bool> hasPin(String userId) async {
    final hash = await _readSecret(_hashKey(userId));
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> verifyPin(String userId, String pin) async {
    final hash = await _readSecret(_hashKey(userId));
    final salt = await _readSecret(_saltKey(userId));
    if (hash == null || salt == null) {
      return false;
    }
    return _hashPin(pin, salt) == hash;
  }

  Future<void> savePin(String userId, String pin) async {
    final salt = _generateSalt();
    await _writeSecret(_hashKey(userId), _hashPin(pin, salt));
    await _writeSecret(_saltKey(userId), salt);
  }

  Future<bool> changePin(
    String userId, {
    required String? currentPin,
    required String newPin,
  }) async {
    final hasExisting = await hasPin(userId);
    if (hasExisting) {
      if (currentPin == null || !await verifyPin(userId, currentPin)) {
        return false;
      }
    }
    await savePin(userId, newPin);
    return true;
  }

  Future<void> clearPin(String userId) async {
    await _deleteSecret(_hashKey(userId));
    await _deleteSecret(_saltKey(userId));
    await _preferences.remove(_requireKey(userId));
  }

  static bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<String?> _readSecret(String key) async {
    if (_secureStorage != null) {
      return _secureStorage!.read(key: key);
    }
    return _preferences.getString(key);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (_secureStorage != null) {
      await _secureStorage!.write(key: key, value: value);
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(key, value);
  }

  Future<void> _deleteSecret(String key) async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: key);
    }
    await _preferences.remove(key);
  }
}
