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

AuthSession _parentSession() {
  final user = AppUser(
    id: 'user_a',
    name: 'Anna Test',
    email: 'anna@test.coparentes.app',
    role: UserRole.parentA,
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

  Future<AppProvider> bootRegistered(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    final auth = _FakeAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      session: _parentSession(),
    );
    final ap = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    // Widget tests use fake async — advance microtasks/timers via pump.
    for (var i = 0; i < 50 && ap.isInitializing; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(ap.isInitializing, isFalse);
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

  Future<void> pumpCard(WidgetTester tester, AppProvider ap) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: ap,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OnboardingTourCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('step 1 visible without timer; dismiss clears', (tester) async {
    final ap = await bootRegistered(tester);
    expect(ap.onboardingTourStep, 1);

    await pumpCard(tester, ap);
    expect(find.text('Krok 1 z 3'), findsOneWidget);
    expect(find.text('Zabezpiecz rozmowy'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ap.onboardingTourStep, isNull);
    expect(find.text('Krok 1 z 3'), findsNothing);
  });

  testWidgets('steps 2 and 3 auto-advance after 3s', (tester) async {
    final ap = await bootRegistered(tester);
    await ap.setOnboardingTourStep(2);
    await pumpCard(tester, ap);
    expect(find.text('Krok 2 z 3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3, milliseconds: 120));
    expect(ap.onboardingTourStep, 3);
    await tester.pump();
    expect(find.text('Krok 3 z 3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3, milliseconds: 120));
    expect(ap.onboardingTourStep, isNull);
  });

  testWidgets('only one step card content at a time', (tester) async {
    final ap = await bootRegistered(tester);
    await pumpCard(tester, ap);
    expect(find.text('Zabezpiecz rozmowy'), findsOneWidget);
    expect(find.text('Zaproś drugiego rodzica'), findsNothing);

    await ap.setOnboardingTourStep(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Zabezpiecz rozmowy'), findsNothing);
    expect(find.text('Zaproś drugiego rodzica'), findsOneWidget);
  });

  testWidgets(
    'step 2 tap opens route; step 3 timer freezes until pop',
    (tester) async {
      final ap = await bootRegistered(tester);
      await ap.setOnboardingTourStep(2);

      // SettingsScreen emits pre-existing ListTile/Material ink assertions in tests.
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('ListTile background color')) {
          return;
        }
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: ap,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OnboardingTourCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Krok 2 z 3'), findsOneWidget);

      // Tap advances to step 3 then pushes Settings over the dashboard.
      await tester.tap(find.text('Zaproś drugiego rodzica'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ap.onboardingTourStep, 3);

      // Covered by Settings: 5s must not auto-dismiss step 3.
      await tester.pump(const Duration(seconds: 5));
      expect(ap.onboardingTourStep, 3);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(ap.onboardingTourStep, 3);

      await tester.pump(const Duration(seconds: 3, milliseconds: 120));
      expect(ap.onboardingTourStep, isNull);
    },
  );
}
