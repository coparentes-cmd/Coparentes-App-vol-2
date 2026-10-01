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
  bool throwOnRecovery = false;

  @override
  Future<String> setupNewKeysWithRecoveryCode(String password) async {
    withRecoveryCalls += 1;
    lastPassword = password;
    if (throwOnRecovery) {
      throw Exception('recovery_setup_failed');
    }
    return sampleCode;
  }

  @override
  Future<void> setupNewKeys(String password) async {
    setupNewKeysCalls += 1;
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
  });

  final AuthSession registerSession;
  final AuthSession joinSession;

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

  Future<({AppProvider ap, _TrackingRecoveryE2e e2e})> boot() async {
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
    );
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      e2eSessionService: e2e,
    );
    await Future<void>.delayed(Duration.zero);
    while (ap.isInitializing) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return (ap: ap, e2e: e2e);
  }

  test(
    'registerWorkspace sets pendingRecoveryCode via setupNewKeysWithRecoveryCode',
    () async {
      final bootstrapped = await boot();
      final ap = bootstrapped.ap;
      final e2e = bootstrapped.e2e;

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
      expect(e2e.withRecoveryCalls, 1);
      expect(e2e.setupNewKeysCalls, 0);
      expect(e2e.lastPassword, 'Password123!');
      expect(ap.pendingRecoveryCode, _TrackingRecoveryE2e.sampleCode);
      expect(ap.showingRecoveryCodeScreen, isTrue);

      ap.clearPendingRecoveryCode();
      expect(ap.pendingRecoveryCode, isNull);
      expect(ap.showingRecoveryCodeScreen, isFalse);
    },
  );

  test(
    'joinWorkspace sets pendingRecoveryCode via setupNewKeysWithRecoveryCode',
    () async {
      final bootstrapped = await boot();
      final ap = bootstrapped.ap;
      final e2e = bootstrapped.e2e;

      final ok = await ap.joinWorkspace(
        name: 'Bartek Test',
        email: 'bartek@test.coparentes.app',
        password: 'JoinPass123!',
        inviteCode: 'INVITE99',
      );

      expect(ok, isTrue);
      expect(ap.currentUser?.role, UserRole.parentB);
      expect(e2e.withRecoveryCalls, 1);
      expect(e2e.setupNewKeysCalls, 0);
      expect(e2e.lastPassword, 'JoinPass123!');
      expect(ap.pendingRecoveryCode, _TrackingRecoveryE2e.sampleCode);
      expect(ap.showingRecoveryCodeScreen, isTrue);
    },
  );

  test(
    'registerWorkspace does not show recovery screen when setup fails',
    () async {
      final bootstrapped = await boot();
      final ap = bootstrapped.ap;
      final e2e = bootstrapped.e2e;
      e2e.throwOnRecovery = true;

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
      expect(e2e.withRecoveryCalls, 1);
      // Fallback setupNewKeys when no unlocked key.
      expect(e2e.setupNewKeysCalls, 1);
      expect(ap.pendingRecoveryCode, isNull);
      expect(ap.showingRecoveryCodeScreen, isFalse);
    },
  );
}
