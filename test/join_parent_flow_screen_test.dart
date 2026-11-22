import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/models/auth_session.dart';
import 'package:coparentes/data/models/user_consent.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/screens/auth/join_parent_flow_screen.dart';
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

class _JoinAuthRepository extends AuthRepository {
  _JoinAuthRepository({
    required super.apiClient,
    required super.preferences,
    required super.offlineStore,
    required this.session,
  });

  final AuthSession session;
  int joinCalls = 0;
  String? lastInviteCode;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> joinWorkspace({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    joinCalls++;
    lastInviteCode = inviteCode;
    return session;
  }
}

AuthSession _parentBSession() {
  final user = AppUser(
    id: 'user_b',
    name: 'Marek Test',
    email: 'marek@test.coparentes.app',
    role: UserRole.parentB,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return AuthSession(
    token: 'tok-b',
    user: user,
    workspace: Workspace(
      id: 'ws',
      name: 'Nasza przestrzeń',
      inviteCode: 'PARENTCODE',
      childInviteCode: 'CHILDCODE',
      members: [user],
      children: [
        ChildProfile(
          id: 'child1',
          name: 'Zosia',
          dateOfBirth: DateTime.utc(2016, 5, 1),
          inviteCode: 'CHILDCODE',
        ),
      ],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _JoinAuthRepository auth;
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    final prefs = await SharedPreferences.getInstance();
    final offline = OfflineStore(preferences: prefs);
    await offline.initialize();
    auth = _JoinAuthRepository(
      apiClient: AppApiClient(baseUrl: 'http://fake'),
      preferences: prefs,
      offlineStore: offline,
      session: _parentBSession(),
    );
    appProvider = AppProvider(
      authRepository: auth,
      consentRepository: _FakeConsentRepository(),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
      e2eSessionService: _SilentE2e(),
    );
    for (var i = 0; i < 50 && appProvider.isInitializing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  });

  testWidgets(
    'join flow: code → account → welcome calls joinWorkspace once',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(home: JoinParentFlowScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Wpisz kod'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'PARENTCODE');
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();

      expect(find.text('Twoje konto'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Marek Kowalski');
      await tester.enterText(fields.at(1), 'marek@test.coparentes.app');
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.tap(find.text('Akceptuj wszystkie'));
      await tester.pump();
      await tester.ensureVisible(find.text('Dołącz do przestrzeni'));
      await tester.tap(find.text('Dołącz do przestrzeni'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Zaczynamy').evaluate().isNotEmpty) break;
      }

      expect(auth.joinCalls, 1);
      expect(auth.lastInviteCode, 'PARENTCODE');
      expect(appProvider.currentUser?.role, UserRole.parentB);
      expect(
        find.text('Gotowe, jesteś we wspólnej przestrzeni'),
        findsOneWidget,
      );
      expect(find.textContaining('Zosia'), findsOneWidget);
      expect(find.text('Zaczynamy'), findsOneWidget);
    },
  );

  testWidgets('join flow: short code stays on step 0', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: appProvider,
        child: const MaterialApp(home: JoinParentFlowScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'ABC');
    await tester.tap(find.text('Dalej'));
    await tester.pump();

    expect(find.text('Wpisz kod'), findsOneWidget);
    expect(find.text('Twoje konto'), findsNothing);
    expect(auth.joinCalls, 0);
  });
}
