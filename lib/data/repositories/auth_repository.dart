import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../../models/models.dart';
import '../models/auth_session.dart';
import '../models/login_challenge.dart';
import '../models/user_consent.dart';
import '../serializers/api_serializers.dart';
import '../serializers/document_serializers.dart';
import '../local/secure_offline_codec.dart';

class ChildJoinProfileOption {
  final String id;
  final String name;
  final bool hasAccount;

  const ChildJoinProfileOption({
    required this.id,
    required this.name,
    required this.hasAccount,
  });
}

class ChildJoinPreview {
  final String workspaceName;
  final List<ChildJoinProfileOption> children;

  const ChildJoinPreview({
    required this.workspaceName,
    required this.children,
  });
}

class AuthRepository {
  static const _tokenKey = 'coparentes_auth_token';
  static const _trustedDeviceKey = 'coparentes_trusted_device_token';

  final AppApiClient _apiClient;
  final SharedPreferences _preferences;
  final OfflineStore _offlineStore;
  final FlutterSecureStorage? _secureStorage;

  AuthRepository({
    required AppApiClient apiClient,
    required SharedPreferences preferences,
    required OfflineStore offlineStore,
    FlutterSecureStorage? secureStorage,
  })  : _apiClient = apiClient,
        _preferences = preferences,
        _offlineStore = offlineStore,
        _secureStorage = kIsWeb
            ? null
            : (secureStorage ?? const FlutterSecureStorage());

  bool get _usesCookieAuth => kIsWeb;

  void _applyWebSessionToken(Map<String, dynamic> payload) {
    if (!_usesCookieAuth) {
      return;
    }
    final token = payload['token'] as String?;
    _apiClient.setToken(
      token != null && token.isNotEmpty ? token : null,
    );
  }

  Future<AuthSession?> restoreSession() async {
    final cachedPayload = _offlineStore.getSessionPayload();

    if (_usesCookieAuth) {
      final trustedToken = await _readTrustedDeviceToken();
      _apiClient.setTrustedDeviceToken(trustedToken);
      try {
        final payload = await _apiClient.getJson('/auth/session');
        _applyWebSessionToken(payload);
        await _offlineStore.saveSessionPayload(payload);
        return authSessionFromJson(payload);
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          await clearToken();
          await _offlineStore.clearSessionPayload();
          return null;
        }

        if (cachedPayload != null && kDebugMode) {
          _applyWebSessionToken(cachedPayload);
          return _sessionFromCachedPayload(cachedPayload);
        }
        return null;
      } catch (_) {
        if (cachedPayload != null && kDebugMode) {
          _applyWebSessionToken(cachedPayload);
          return _sessionFromCachedPayload(cachedPayload);
        }
        return null;
      }
    }

    var token = await _readToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    _apiClient.setToken(token);
    final trustedToken = await _readTrustedDeviceToken();
    _apiClient.setTrustedDeviceToken(trustedToken);
    try {
      final payload = await _apiClient.getJson('/auth/session');
      await _offlineStore.saveSessionPayload(payload);
      return authSessionFromJson(payload);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await clearToken();
        await _offlineStore.clearSessionPayload();
        return null;
      }

      if (cachedPayload != null && kDebugMode) {
        return _sessionFromCachedPayload(cachedPayload);
      }
      return null;
    } catch (_) {
      if (cachedPayload != null && kDebugMode) {
        return _sessionFromCachedPayload(cachedPayload);
      }
      return null;
    }
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final trustedToken = await _readTrustedDeviceToken();
    if (trustedToken != null) {
      _apiClient.setTrustedDeviceToken(trustedToken);
    }

    final payload = await _apiClient.postJson('/auth/login', {
      'email': email,
      'password': password,
    });

    if (payload['requiresOtp'] == true) {
      return LoginResponse(
        challenge: LoginChallenge.fromJson(payload),
      );
    }

    return LoginResponse(session: await _saveSession(payload));
  }

  Future<AuthSession> verifyLoginOtp({
    required String challengeId,
    required String code,
    bool trustDevice = false,
  }) async {
    final payload = await _apiClient.postJson('/auth/login/verify-otp', {
      'challengeId': challengeId,
      'code': code,
      'trustDevice': trustDevice,
    });

    final trustedToken = payload['trustedDeviceToken'] as String?;
    if (trustDevice && trustedToken != null && trustedToken.isNotEmpty) {
      await _writeTrustedDeviceToken(trustedToken);
      _apiClient.setTrustedDeviceToken(trustedToken);
    }

    return _saveSession(payload);
  }

  Future<LoginChallenge> resendLoginOtp({
    required String challengeId,
    required String maskedEmail,
  }) async {
    final payload = await _apiClient.postJson('/auth/login/resend-otp', {
      'challengeId': challengeId,
    });
    return LoginChallenge(
      challengeId: payload['challengeId'] as String,
      maskedEmail: payload['email'] as String? ?? maskedEmail,
      expiresAt: DateTime.parse(payload['expiresAt'] as String),
      resendAvailableAt: DateTime.parse(payload['resendAvailableAt'] as String),
    );
  }

  Future<AuthSession> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
    required Map<ConsentType, bool> consents,
  }) async {
    final payload = await _apiClient.postJson('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'workspaceName': workspaceName,
      'consents': consentSelectionsToApi(consents),
    });
    return _saveSession(payload);
  }

  Future<AuthSession> joinWorkspace({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final payload = await _apiClient.postJson('/auth/join', {
      'name': name,
      'email': email,
      'password': password,
      'inviteCode': inviteCode,
    });
    return _saveSession(payload);
  }

  Future<ChildJoinPreview?> getChildJoinPreview(String childInviteCode) async {
    try {
      final payload = await _apiClient.getJson(
        '/auth/join-preview?childInviteCode=${Uri.encodeQueryComponent(childInviteCode)}',
      );
      return ChildJoinPreview(
        workspaceName: payload['workspaceName'] as String,
        children: (payload['children'] as List<dynamic>)
            .map(
              (item) {
                final child = Map<String, dynamic>.from(item as Map);
                return ChildJoinProfileOption(
                  id: child['id'] as String,
                  name: child['name'] as String,
                  hasAccount: child['hasAccount'] as bool? ?? false,
                );
              },
            )
            .toList(),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<AuthSession> accessChildAccount({
    required String password,
    required String childInviteCode,
    required DateTime dateOfBirth,
    String? name,
  }) async {
    final payload = await _apiClient.postJson('/auth/child/access', {
      'password': password,
      'childInviteCode': childInviteCode,
      'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
      if (name != null && name.isNotEmpty) 'name': name,
    });
    return _saveSession(payload);
  }

  Future<AuthSession> addWorkspaceChild({
    required String name,
    required DateTime dateOfBirth,
    String? school,
  }) async {
    await _apiClient.postJson('/workspace/children', {
      'name': name,
      'dateOfBirth': dateOfBirth.toUtc().toIso8601String(),
      if (school != null && school.isNotEmpty) 'school': school,
    });
    return refreshSession();
  }

  Future<AuthSession> refreshSession() async {
    final payload = await _apiClient.getJson('/auth/session');
    return _saveSession(payload);
  }

  Future<AuthSession> updateProfile({
    String? name,
    bool? highConflictMode,
    bool? twoFactorEnabled,
  }) async {
    final payload = await _apiClient.patchJson('/auth/profile', {
      if (name != null) 'name': name,
      if (highConflictMode != null) 'highConflictMode': highConflictMode,
      if (twoFactorEnabled != null) 'twoFactorEnabled': twoFactorEnabled,
    });
    return _saveSession(payload);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.postJson('/auth/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<EmailInvite> sendEmailInvite({required String email}) async {
    final payload = await _apiClient.postJson('/invite/send', {
      'email': email.trim().toLowerCase(),
    });
    return emailInviteFromJson(
      Map<String, dynamic>.from(payload['invite'] as Map),
    );
  }

  Future<List<EmailInvite>> getSentEmailInvites() async {
    final payload = await _apiClient.getJson('/invite/sent');
    return (payload['invites'] as List<dynamic>)
        .map(
          (item) => emailInviteFromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> logout() async {
    try {
      await _apiClient.postEmpty('/auth/logout');
    } catch (_) {
      // Ignore backend logout failures and always clear local session.
    } finally {
      await clearToken();
      await _clearTrustedDeviceToken();
      await _offlineStore.clearSessionScopedData();
    }
  }

  Future<void> clearToken() async {
    _apiClient.setToken(null);
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: _tokenKey);
    }
    await _preferences.remove(_tokenKey);
  }

  Future<String?> _readToken() async {
    if (_secureStorage != null) {
      var token = await _secureStorage!.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        return token;
      }

      token = _preferences.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        await _secureStorage!.write(key: _tokenKey, value: token);
        await _preferences.remove(_tokenKey);
      }
      return token;
    }

    return null;
  }

  Future<void> _writeToken(String token) async {
    if (_secureStorage == null) {
      return;
    }
    await _secureStorage!.write(key: _tokenKey, value: token);
    await _preferences.remove(_tokenKey);
  }

  Future<String?> _readTrustedDeviceToken() async {
    if (_secureStorage != null) {
      return _secureStorage!.read(key: _trustedDeviceKey);
    }
    return _preferences.getString(_trustedDeviceKey);
  }

  Future<void> _writeTrustedDeviceToken(String token) async {
    if (_secureStorage != null) {
      await _secureStorage!.write(key: _trustedDeviceKey, value: token);
      await _preferences.remove(_trustedDeviceKey);
      return;
    }
    await _preferences.setString(_trustedDeviceKey, token);
  }

  Future<void> _clearTrustedDeviceToken() async {
    _apiClient.setTrustedDeviceToken(null);
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: _trustedDeviceKey);
    }
    await _preferences.remove(_trustedDeviceKey);
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> payload) async {
    final session = authSessionFromJson(payload);
    if (_usesCookieAuth) {
      _applyWebSessionToken(payload);
    } else {
      _apiClient.setToken(session.token);
      await _writeToken(session.token);
    }
    await _offlineStore.saveSessionPayload(payload);
    return session;
  }

  AuthSession _sessionFromCachedPayload(Map<String, dynamic> cachedPayload) {
    return authSessionFromJson({
      ...cachedPayload,
      'token': cachedPayload['token'] as String? ?? '',
    });
  }
}
