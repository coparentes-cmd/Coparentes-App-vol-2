import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/models/login_challenge.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingE2eSession extends E2eSessionService {
  _TrackingE2eSession() : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  int unlockAfterAuthCalls = 0;

  @override
  Future<void> unlockAfterAuthentication(String password) async {
    unlockAfterAuthCalls += 1;
    // Would hang/Argon2 in production for wrong temp password — must not be called.
    await Future<void>.delayed(const Duration(hours: 1));
  }
}

class _CountingUnlockE2e extends E2eSessionService {
  _CountingUnlockE2e() : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  int unlockAfterAuthCalls = 0;

  @override
  Future<void> unlockAfterAuthentication(String password) async {
    unlockAfterAuthCalls += 1;
  }
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
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    return LoginResponse(session: session);
  }
}

AuthSession _session({required bool mustChangePassword}) {
  final user = AppUser(
    id: 'user_1',
    name: 'Probe',
    email: 'probe@test.coparentes.app',
    role: UserRole.parentA,
    mustChangePassword: mustChangePassword,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return AuthSession(
    token: 'tok',
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

  test(
    'login with mustChangePassword skips E2eSession.unlockAfterAuthentication',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final offline = OfflineStore(preferences: prefs);
      await offline.initialize();

      final e2e = _TrackingE2eSession();
      final auth = _FakeAuthRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        preferences: prefs,
        offlineStore: offline,
        session: _session(mustChangePassword: true),
      );

      final ap = AppProvider(
        authRepository: auth,
        consentRepository: ConsentRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
        ),
        pinLockStore: PinLockStore(preferences: prefs),
        e2eSessionService: e2e,
      );

      // Wait for constructor bootstrap (restoreSession → null).
      await Future<void>.delayed(Duration.zero);
      while (ap.isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final sw = Stopwatch()..start();
      final ok = await ap.login(
        email: 'probe@test.coparentes.app',
        password: 'TempPass12',
      );
      sw.stop();

      expect(ok, isTrue);
      expect(ap.currentUser?.mustChangePassword, isTrue);
      expect(e2e.unlockAfterAuthCalls, 0);
      // Must not wait on the fake E2E hour-long delay.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    },
  );

  test(
    'login without mustChangePassword still calls unlockAfterAuthentication',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final offline = OfflineStore(preferences: prefs);
      await offline.initialize();

      final tracking = _CountingUnlockE2e();
      final auth = _FakeAuthRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        preferences: prefs,
        offlineStore: offline,
        session: _session(mustChangePassword: false),
      );

      final ap = AppProvider(
        authRepository: auth,
        consentRepository: ConsentRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
        ),
        pinLockStore: PinLockStore(preferences: prefs),
        e2eSessionService: tracking,
      );

      await Future<void>.delayed(Duration.zero);
      while (ap.isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final ok = await ap.login(
        email: 'probe@test.coparentes.app',
        password: 'RealPass12',
      );

      expect(ok, isTrue);
      expect(tracking.unlockAfterAuthCalls, 1);
    },
  );
}
