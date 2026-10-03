import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/models/user_consent.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/features/parent/widgets/onboarding_tour_card.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<AuthSession> joinWorkspace({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    return session;
  }
}

class _SessionRestoreAuth extends AuthRepository {
  _SessionRestoreAuth({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    required this.session,
  });

  final AuthSession session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession> registerWorkspace({
    required String name,
    required String email,
    required String password,
    required String workspaceName,
    required Map<ConsentType, bool> consents,
  }) async =>
      session;
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

AuthSession _session({
  required String id,
  required UserRole role,
  String name = 'Anna Test',
  String email = 'anna@test.coparentes.app',
}) {
  final user = AppUser(
    id: id,
    name: name,
    email: email,
    role: role,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return AuthSession(
    token: 'tok',
    user: user,
    workspace: Workspace(
      id: 'ws',
      name: 'Rodzina',
      inviteCode: 'PARENTCODE',
      childInviteCode: 'CHILDCODE',
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

  Future<void> settleInit(WidgetTester tester, AppProvider ap) async {
    for (var i = 0; i < 80 && ap.isInitializing; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(ap.isInitializing, isFalse);
  }

  Future<AppProvider> bootRegistered(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final ap = AppProvider(
      authRepository: _FakeAuthRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        preferences: prefs,
        offlineStore: offline,
        session: _session(id: 'user_a', role: UserRole.parentA),
      ),
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    await settleInit(tester, ap);
    final ok = await ap.registerWorkspace(
      name: 'Anna Test',
      email: 'anna@test.coparentes.app',
      password: 'Password123!',
      workspaceName: 'Rodzina',
      consents: {for (final t in ConsentType.values) t: true},
    );
    expect(ok, isTrue);
    await tester.pump();
    return ap;
  }

  Future<AppProvider> bootRestored(
    WidgetTester tester, {
    required AuthSession session,
    Map<String, Object> prefsSeed = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsSeed);
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final ap = AppProvider(
      authRepository: _SessionRestoreAuth(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        preferences: prefs,
        offlineStore: offline,
        session: session,
      ),
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    await settleInit(tester, ap);
    return ap;
  }

  Future<void> pumpHost(WidgetTester tester, AppProvider ap) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ap,
        child: const MaterialApp(
          home: Scaffold(
            body: OnboardingTourCard(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void ignoreSettingsListTileNoise() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  testWidgets('step 1 dialog visible and does not auto-dismiss after 10s', (
    tester,
  ) async {
    final ap = await bootRegistered(tester);
    await pumpHost(tester, ap);

    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(find.text('Wygeneruj kod'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    expect(ap.onboardingTourStep, 1);
    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('system back does not dismiss step 1 or flicker a second dialog', (
    tester,
  ) async {
    final ap = await bootRegistered(tester);
    await pumpHost(tester, ap);
    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    // System / browser-style back (ModalRoute pop).
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pump();
    await tester.pump();

    expect(ap.onboardingTourStep, 1);
    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Wygeneruj kod'), findsOneWidget);

    // maybePop is "handled" (true) even when PopScope blocks; dialog must stay.
    final handledByMaybePop = await Navigator.of(
      tester.element(find.byType(Dialog)),
    ).maybePop();
    expect(handledByMaybePop, isTrue);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(ap.onboardingTourStep, 1);
  });

  testWidgets('X advances 1→2→3 then clears', (tester) async {
    final ap = await bootRegistered(tester);
    await pumpHost(tester, ap);
    expect(find.text('Krok 1 z 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_tour_close')));
    await tester.pump();
    await tester.pump();
    expect(ap.onboardingTourStep, 2);
    expect(find.text('Krok 2 z 3'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_tour_close')));
    await tester.pump();
    await tester.pump();
    expect(ap.onboardingTourStep, 3);
    expect(find.text('Krok 3 z 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_tour_close')));
    await tester.pump();
    await tester.pump();
    expect(ap.onboardingTourStep, isNull);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'step 2 action opens Settings; after pop step 3 dialog shows',
    (tester) async {
      final ap = await bootRegistered(tester);
      await ap.setOnboardingTourStep(2);
      ignoreSettingsListTileNoise();
      await pumpHost(tester, ap);
      expect(find.text('Krok 2 z 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_tour_action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ap.onboardingTourStep, 3);
      expect(find.byType(Dialog), findsNothing);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pump();
      await tester.pump();
      expect(ap.onboardingTourStep, 3);
      expect(find.text('Krok 3 z 3'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
    },
  );

  testWidgets('never two tour dialogs at once', (tester) async {
    final ap = await bootRegistered(tester);
    await pumpHost(tester, ap);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_tour_close')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Krok 2 z 3'), findsOneWidget);
  });

  testWidgets('joining parentB without step does not see dialog', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final ap = AppProvider(
      authRepository: _FakeAuthRepository(
        apiClient: AppApiClient(baseUrl: 'http://fake'),
        preferences: prefs,
        offlineStore: offline,
        session: _session(
          id: 'user_b',
          role: UserRole.parentB,
          name: 'Bartek',
          email: 'b@t.com',
        ),
      ),
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    await settleInit(tester, ap);
    final ok = await ap.joinWorkspace(
      name: 'Bartek',
      email: 'b@t.com',
      password: 'JoinPass123!',
      inviteCode: 'INVITE99',
    );
    expect(ok, isTrue);
    expect(ap.onboardingTourStep, isNull);
    await pumpHost(tester, ap);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('child does not see dialog even with stale step prefs', (
    tester,
  ) async {
    final ap = await bootRestored(
      tester,
      session: _session(id: 'user_c', role: UserRole.child, name: 'Ola'),
      prefsSeed: {
        AppProvider.onboardingTourPrefsKey('user_c'): 1,
      },
    );
    expect(ap.currentUser?.role, UserRole.child);
    expect(ap.onboardingTourStep, 1);
    await pumpHost(tester, ap);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('tour step survives provider recreate from prefs', (tester) async {
    final ap1 = await bootRegistered(tester);
    await ap1.setOnboardingTourStep(2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppProvider.onboardingTourPrefsKey('user_a')), 2);

    final ap2 = await bootRestored(
      tester,
      session: _session(id: 'user_a', role: UserRole.parentA),
      prefsSeed: {
        AppProvider.onboardingTourPrefsKey('user_a'): 2,
      },
    );
    expect(ap2.onboardingTourStep, 2);
    await pumpHost(tester, ap2);
    expect(find.text('Krok 2 z 3'), findsOneWidget);
  });
}
