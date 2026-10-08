import 'dart:io';

import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/models/user_consent.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConsentRepository extends ConsentRepository {
  _FakeConsentRepository()
      : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  @override
  Future<List<UserConsentRecord>> fetchConsents() async => const [];
}

class _SilentE2e extends E2eSessionService {
  _SilentE2e() : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  @override
  Future<void> setupNewKeys(String password) async {}

  @override
  Future<String> setupNewKeysWithRecoveryCode(String password) async =>
      'AAAA-BBBB-CCCC-DDDD-EEEE-FFFF';

  @override
  Future<bool> hasUnlockedKey() async => true;
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    required this.session,
  });

  final AuthSession session;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
    required Map<ConsentType, bool> consents,
  }) async {
    return session;
  }
}

AuthSession _parentSession({String id = 'user_a'}) {
  final user = AppUser(
    id: id,
    name: 'anna test',
    email: 'anna@test.coparentes.app',
    role: UserRole.parentA,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return AuthSession(
    token: 'tok_$id',
    user: user,
    workspace: Workspace(
      id: 'ws_1',
      name: 'Family',
      members: [user],
      children: const [],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  Future<AppProvider> boot({AuthSession? session}) async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      session: session ?? _parentSession(),
    );
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    await Future<void>.delayed(Duration.zero);
    while (ap.isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return ap;
  }

  Map<ConsentType, bool> allConsents() => {
        for (final t in ConsentType.values) t: true,
      };

  test('registerWorkspace saves mama/tata from isMama', () async {
    final ap = await boot();

    final okMama = await ap.registerWorkspace(
      name: 'Anna',
      email: 'anna@test.coparentes.app',
      password: 'Password123!',
      workspaceName: 'Rodzina',
      consents: allConsents(),
      isMama: true,
    );
    expect(okMama, isTrue);
    expect(ap.parentFamilyRoleLabel(ap.currentUser), 'mama');
    expect(
      (await SharedPreferences.getInstance())
          .getString(AppProvider.parentFamilyRolePrefsKey('user_a')),
      'mama',
    );

    await ap.saveParentFamilyRole('tata');
    expect(ap.parentFamilyRoleLabel(ap.currentUser), 'tata');
  });

  test('registerWorkspace isMama:false persists tata', () async {
    final ap = await boot(session: _parentSession(id: 'user_tata'));

    final ok = await ap.registerWorkspace(
      name: 'Jan',
      email: 'jan@test.coparentes.app',
      password: 'Password123!',
      workspaceName: 'Rodzina',
      consents: allConsents(),
      isMama: false,
    );
    expect(ok, isTrue);
    expect(ap.parentFamilyRoleLabel(ap.currentUser), 'tata');
  });

  test('fallback without prefs: parentA→mama, parentB→tata', () async {
    final ap = await boot();
    final parentA = AppUser(
      id: 'other_a',
      name: 'A',
      email: 'a@test.coparentes.app',
      role: UserRole.parentA,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final parentB = AppUser(
      id: 'other_b',
      name: 'B',
      email: 'b@test.coparentes.app',
      role: UserRole.parentB,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(ap.parentFamilyRoleLabel(parentA), 'mama');
    expect(ap.parentFamilyRoleLabel(parentB), 'tata');
  });

  test('settings_screen: no Wygeneruj kod; uses parentFamilyRoleLabel', () {
    final src = File('lib/features/settings/settings_screen.dart').readAsStringSync();
    expect(src.contains('Wygeneruj kod odzyskiwania czatu'), isFalse);
    expect(src.contains('generate_recovery_code_flow'), isFalse);
    expect(src.contains('parentFamilyRoleLabel'), isTrue);
    expect(src.contains("_roleBadge(user?.role)"), isFalse);
  });
}
