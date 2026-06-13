import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../../models/models.dart';
import '../models/auth_session.dart';
import '../serializers/api_serializers.dart';
import '../serializers/document_serializers.dart';

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

  Future<AuthSession?> restoreSession() async {
    var token = await _readToken();
    final cachedPayload = _offlineStore.getSessionPayload();

    if (token == null || token.isEmpty) {
      if (cachedPayload == null) {
        return null;
      }

      final cachedToken = cachedPayload['token'] as String?;
      if (cachedToken != null && cachedToken.isNotEmpty) {
        _apiClient.setToken(cachedToken);
        await _writeToken(cachedToken);
        token = cachedToken;
      } else {
        return null;
      }
    }

    _apiClient.setToken(token);
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
        return authSessionFromJson(cachedPayload);
      }
      return null;
    } catch (_) {
      if (cachedPayload != null && kDebugMode) {
        return authSessionFromJson(cachedPayload);
      }
      return null;
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final payload = await _apiClient.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    return _saveSession(payload);
  }

  Future<AuthSession> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
  }) async {
    final payload = await _apiClient.postJson('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'workspaceName': workspaceName,
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

  Future<AuthSession> joinAsChild({
    required String name,
    required String email,
    required String password,
    required String childInviteCode,
    required String childProfileId,
  }) async {
    final payload = await _apiClient.postJson('/auth/join', {
      'name': name,
      'email': email,
      'password': password,
      'childInviteCode': childInviteCode,
      'childProfileId': childProfileId,
      'role': 'child',
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

    return _preferences.getString(_tokenKey);
  }

  Future<void> _writeToken(String token) async {
    if (_secureStorage != null) {
      await _secureStorage!.write(key: _tokenKey, value: token);
      await _preferences.remove(_tokenKey);
      return;
    }

    await _preferences.setString(_tokenKey, token);
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> payload) async {
    final session = authSessionFromJson(payload);
    _apiClient.setToken(session.token);
    await _writeToken(session.token);
    await _offlineStore.saveSessionPayload(payload);
    return session;
  }
}
