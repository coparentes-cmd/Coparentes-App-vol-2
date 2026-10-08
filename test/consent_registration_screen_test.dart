import 'dart:async';

import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/models/user_consent.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/screens/auth/consent_registration_screen.dart';
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

class _CountingAuthRepository extends AuthRepository {
  _CountingAuthRepository({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    required this.session,
  });

  final AuthSession session;
  int registerCalls = 0;
  Completer<AuthSession>? hold;

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
    registerCalls++;
    if (hold != null) {
      return hold!.future;
    }
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

const _draft = RegistrationDraft(
  name: 'Anna Kowalska',
  email: 'anna@test.coparentes.app',
  password: 'Password123!',
  workspaceName: 'Rodzina Kowalska',
  isMama: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingAuthRepository auth;
  late AppProvider appProvider;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    auth = _CountingAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      session: _parentSession(),
    );
    appProvider = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
  });

  Future<void> settleInit(WidgetTester tester) async {
    for (var i = 0; i < 50 && appProvider.isInitializing; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(appProvider.isInitializing, isFalse);
  }

  Future<void> pumpConsent(WidgetTester tester) async {
    await settleInit(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: appProvider,
        child: const MaterialApp(
          home: ConsentRegistrationScreen(draft: _draft),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> grantRequiredConsents(WidgetTester tester) async {
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);
    // Required trio are the first three ConsentRows.
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(switches.at(i));
      await tester.tap(switches.at(i));
      await tester.pump();
    }
  }

  testWidgets(
    'before Utwórz: zero registerWorkspace and empty SharedPreferences',
    (tester) async {
      await settleInit(tester);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ConsentRegistrationScreen(
                            draft: _draft,
                          ),
                        ),
                      );
                    },
                    child: const Text('open-consents'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open-consents'));
      await tester.pumpAndSettle();

      expect(find.text('Utwórz'), findsOneWidget);
      expect(auth.registerCalls, 0);
      expect(prefs.getKeys(), isEmpty);
      expect(appProvider.currentUser, isNull);
    },
  );

  testWidgets('Utwórz disabled until required consents granted', (tester) async {
    await pumpConsent(tester);

    expect(find.text('Zaznacz wymagane zgody'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('consent_create_button')),
    );
    expect(button.onPressed, isNull);

    await grantRequiredConsents(tester);

    expect(find.text('Zaznacz wymagane zgody'), findsNothing);
    final enabled = tester.widget<ElevatedButton>(
      find.byKey(const Key('consent_create_button')),
    );
    expect(enabled.onPressed, isNotNull);
    expect(auth.registerCalls, 0);
  });

  testWidgets(
    'Utwórz calls registerWorkspace exactly once on double tap',
    (tester) async {
      auth.hold = Completer<AuthSession>();
      await pumpConsent(tester);
      await grantRequiredConsents(tester);

      await tester.tap(find.byKey(const Key('consent_create_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('consent_create_button')));
      await tester.pump();

      expect(auth.registerCalls, 1);

      auth.hold!.complete(_parentSession());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(auth.registerCalls, 1);
    },
  );

  testWidgets('Anuluj does not call API and does not persist', (tester) async {
    await settleInit(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: appProvider,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConsentRegistrationScreen(
                          draft: _draft,
                        ),
                      ),
                    );
                  },
                  child: const Text('open-consents'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open-consents'));
    await tester.pumpAndSettle();

    await grantRequiredConsents(tester);
    await tester.tap(find.byKey(const Key('consent_cancel_button')));
    await tester.pumpAndSettle();

    expect(find.text('open-consents'), findsOneWidget);
    expect(auth.registerCalls, 0);
    expect(prefs.getKeys(), isEmpty);
    expect(appProvider.currentUser, isNull);
  });
}
