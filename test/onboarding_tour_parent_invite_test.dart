import 'dart:io';

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
import 'package:coparentes/theme/app_theme.dart';
import 'package:flutter/material.dart';
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

AuthSession _parentSession() {
  final user = AppUser(
    id: 'user_a',
    name: 'anna test',
    email: 'anna@test.coparentes.app',
    role: UserRole.parentA,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return AuthSession(
    token: 'tok',
    user: user,
    workspace: Workspace(
      id: 'ws',
      name: 'test',
      inviteCode: 'DSIMPWKFEIF3S2HDW_0H8Q',
      inviteCodeExpiresAt: DateTime.utc(2026, 10, 9, 19, 10),
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
    'registerWorkspace starts tour at step 2 (krok 1 = invite parent)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final offline = OfflineStore(preferences: prefs);
      await offline.initialize();
      final ap = AppProvider(
        authRepository: _FakeAuthRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
          preferences: prefs,
          offlineStore: offline,
          session: _parentSession(),
        ),
        consentRepository: _FakeConsentRepository(),
        pinLockStore: PinLockStore(preferences: prefs),
        preferences: prefs,
        e2eSessionService: _SilentE2e(),
      );
      await Future<void>.delayed(Duration.zero);
      while (ap.isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final ok = await ap.registerWorkspace(
        name: 'anna',
        email: 'anna@test.coparentes.app',
        password: 'Password123!',
        workspaceName: 'test',
        consents: {for (final t in ConsentType.values) t: true},
      );
      expect(ok, isTrue);
      expect(ap.onboardingTourStep, 2);
      expect(ap.currentWorkspace?.inviteCode, 'DSIMPWKFEIF3S2HDW_0H8Q');
    },
  );

  testWidgets(
    'presentParentInviteFromTour opens Skopiuj / Wyślij kod e-mailem sheet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => presentParentInviteFromTour(
                  context,
                  inviteCode: 'DSIMPWKFEIF3S2HDW_0H8Q',
                  color: AppTheme.primaryTeal,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('parent_invite_copy')), findsOneWidget);
      expect(find.byKey(const Key('parent_invite_send_email')), findsOneWidget);
      expect(find.text('DSIMPWKFEIF3S2HDW_0H8Q'), findsOneWidget);
    },
  );

  test('onboarding tour card wires krok 2 to showChildOnboardingSheet', () {
    // Source contract: step 3 CTA must open the sheet, not Settings addChild.
    final src = File(
      'lib/features/parent/widgets/onboarding_tour_card.dart',
    ).readAsStringSync();
    expect(src.contains('showChildOnboardingSheet(context)'), isTrue);
    expect(
      src.contains('focus: SettingsFocus.addChild'),
      isFalse,
    );
    expect(src.contains('presentParentInviteFromTour'), isTrue);
  });
}
