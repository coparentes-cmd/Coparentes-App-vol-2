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

class _TrackingRecoveryE2e extends E2eSessionService {
  _TrackingRecoveryE2e()
      : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  static const sampleCode = 'ABCD-EFGH-IJKM-NPQR-STVW-XYZ0';

  int withRecoveryCalls = 0;
  int setupNewKeysCalls = 0;
  String? lastPassword;

  @override
  Future<String> setupNewKeysWithRecoveryCode(String password) async {
    withRecoveryCalls += 1;
    lastPassword = password;
    return sampleCode;
  }

  @override
  Future<void> setupNewKeys(String password) async {
    setupNewKeysCalls += 1;
    lastPassword = password;
  }

  @override
  Future<bool> hasUnlockedKey() async => false;
}

class _FakeConsentRepository extends ConsentRepository {
  _FakeConsentRepository()
      : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  @override
  Future<List<UserConsentRecord>> fetchConsents() async => const [];
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    required this.registerSession,
    required this.joinSession,
    required this.childSession,
  });

  final AuthSession registerSession;
  final AuthSession joinSession;
  final AuthSession childSession;

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
    return registerSession;
  }

  @override
  Future<AuthSession> joinWorkspace({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    return joinSession;
  }

  @override
  Future<AuthSession> accessChildAccount({
    required String password,
    required String childInviteCode,
    required DateTime dateOfBirth,
    String? name,
  }) async {
    return childSession;
  }
}

AuthSession _session({
  required String id,
  required UserRole role,
}) {
  final user = AppUser(
    id: id,
    name: 'Probe',
    email: '$id@test.coparentes.app',
    role: role,
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

  Future<({AppProvider ap, _TrackingRecoveryE2e e2e, SharedPreferences prefs})>
      boot() async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final e2e = _TrackingRecoveryE2e();
    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      registerSession: _session(id: 'user_a', role: UserRole.parentA),
      joinSession: _session(id: 'user_b', role: UserRole.parentB),
      childSession: _session(id: 'user_c', role: UserRole.child),
    );
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: e2e,
    );
    await Future<void>.delayed(Duration.zero);
    while (ap.isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return (ap: ap, e2e: e2e, prefs: prefs);
  }

  test(
    'registerWorkspace: no client E2E setup, tour step 1 persisted',
    () async {
      final bootstrapped = await boot();
      final ap = bootstrapped.ap;
      final e2e = bootstrapped.e2e;
      final prefs = bootstrapped.prefs;

      final ok = await ap.registerWorkspace(
        name: 'Anna Test',
        email: 'anna@test.coparentes.app',
        password: 'Password123!',
        workspaceName: 'Rodzina',
        consents: {
          for (final t in ConsentType.values) t: true,
        },
      );

      expect(ok, isTrue);
      expect(e2e.setupNewKeysCalls, 0);
      expect(e2e.withRecoveryCalls, 0);
      expect(ap.onboardingTourStep, 1);
      expect(
        prefs.getInt(AppProvider.onboardingTourPrefsKey('user_a')),
        1,
      );
    },
  );

  test('joinWorkspace: no client E2E setup, no tour step', () async {
    final bootstrapped = await boot();
    final ap = bootstrapped.ap;
    final e2e = bootstrapped.e2e;
    final prefs = bootstrapped.prefs;

    final ok = await ap.joinWorkspace(
      name: 'Bartek Test',
      email: 'bartek@test.coparentes.app',
      password: 'JoinPass123!',
      inviteCode: 'INVITE99',
    );

    expect(ok, isTrue);
    expect(ap.currentUser?.role, UserRole.parentB);
    expect(e2e.setupNewKeysCalls, 0);
    expect(e2e.withRecoveryCalls, 0);
    expect(ap.onboardingTourStep, isNull);
    expect(
      prefs.getInt(AppProvider.onboardingTourPrefsKey('user_b')),
      isNull,
    );
  });

  test(
    'accessChildAccount: no client E2E recovery keys, no tour step',
    () async {
      final bootstrapped = await boot();
      final ap = bootstrapped.ap;
      final e2e = bootstrapped.e2e;

      final ok = await ap.accessChildAccount(
        password: 'ChildPass123!',
        childInviteCode: 'CHILDCODE',
        dateOfBirth: DateTime.utc(2015, 5, 1),
        name: 'Ola',
      );

      expect(ok, isTrue);
      expect(e2e.withRecoveryCalls, 0);
      expect(e2e.setupNewKeysCalls, 0);
      expect(ap.onboardingTourStep, isNull);
    },
  );

  test('setOnboardingTourStep persists and clears', () async {
    final bootstrapped = await boot();
    final ap = bootstrapped.ap;
    final prefs = bootstrapped.prefs;

    await ap.registerWorkspace(
      name: 'Anna Test',
      email: 'anna@test.coparentes.app',
      password: 'Password123!',
      workspaceName: 'Rodzina',
      consents: {
        for (final t in ConsentType.values) t: true,
      },
    );

    await ap.setOnboardingTourStep(2);
    expect(ap.onboardingTourStep, 2);
    expect(prefs.getInt(AppProvider.onboardingTourPrefsKey('user_a')), 2);

    await ap.setOnboardingTourStep(3);
    expect(ap.onboardingTourStep, 3);

    await ap.setOnboardingTourStep(null);
    expect(ap.onboardingTourStep, isNull);
    expect(prefs.getInt(AppProvider.onboardingTourPrefsKey('user_a')), isNull);
  });

  test('tour step reloaded from SharedPreferences on session apply', () async {
    SharedPreferences.setMockInitialValues({
      AppProvider.onboardingTourPrefsKey('user_b'): 2,
    });
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final e2e = _TrackingRecoveryE2e();
    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      registerSession: _session(id: 'user_a', role: UserRole.parentA),
      joinSession: _session(id: 'user_b', role: UserRole.parentB),
      childSession: _session(id: 'user_c', role: UserRole.child),
    );
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: e2e,
    );
    await Future<void>.delayed(Duration.zero);
    while (ap.isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    final ok = await ap.joinWorkspace(
      name: 'Bartek',
      email: 'b@test.coparentes.app',
      password: 'JoinPass123!',
      inviteCode: 'INVITE99',
    );
    expect(ok, isTrue);
    expect(ap.onboardingTourStep, 2);
  });
}
