import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/data/repositories/calendar_repository.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:coparentes/providers/calendar_provider.dart';
import 'package:coparentes/screens/child/child_dashboard.dart';
import 'package:coparentes/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wspólne elementy UI panelu dziecka — bez personalizacji (powitanie).
class ChildDashboardSharedUi {
  final List<String> navLabels;
  final String? custodianLabel;
  final List<String> planEventTitles;
  final String calendarTitle;
  final bool calendarHasSwapTab;
  final String familyChatSnippet;
  final String listEmptyMessage;

  const ChildDashboardSharedUi({
    required this.navLabels,
    required this.custodianLabel,
    required this.planEventTitles,
    required this.calendarTitle,
    required this.calendarHasSwapTab,
    required this.familyChatSnippet,
    required this.listEmptyMessage,
  });

  @override
  bool operator ==(Object other) {
    return other is ChildDashboardSharedUi &&
        _listEquals(navLabels, other.navLabels) &&
        custodianLabel == other.custodianLabel &&
        _listEquals(planEventTitles, other.planEventTitles) &&
        calendarTitle == other.calendarTitle &&
        calendarHasSwapTab == other.calendarHasSwapTab &&
        familyChatSnippet == other.familyChatSnippet &&
        listEmptyMessage == other.listEmptyMessage;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(navLabels),
        custodianLabel,
        Object.hashAll(planEventTitles),
        calendarTitle,
        calendarHasSwapTab,
        familyChatSnippet,
        listEmptyMessage,
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const createdAt = '2026-01-12T09:30:00.000';
  final childCreatedAt = DateTime.parse(createdAt);

  final zosia = AppUser(
    id: 'user_child_zosia',
    name: 'Zosia',
    email: 'zosia.demo@coparentes.app',
    role: UserRole.child,
    createdAt: childCreatedAt,
  );

  final tomek = AppUser(
    id: 'user_child_tomek',
    name: 'Tomek',
    email: 'tomek.demo@coparentes.app',
    role: UserRole.child,
    createdAt: childCreatedAt,
  );

  setUpAll(() async {
    await initializeDateFormatting('pl_PL', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChildDashboard — spójność między profilami dziecka', () {
    testWidgets(
      'Zosia i Tomek widzą ten sam plan, nawigację, kalendarz i czat Rodzina',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final zosiaUi = await _captureChildDashboard(tester, zosia);
        await _disposeDashboard(tester);
        final tomekUi = await _captureChildDashboard(tester, tomek);
        await _disposeDashboard(tester);

        expect(zosiaUi.greeting, 'Cześć, Zosia! 👋');
        expect(tomekUi.greeting, 'Cześć, Tomek! 👋');

        expect(zosiaUi.shared, tomekUi.shared);
        expect(zosiaUi.shared.planEventTitles, contains('Trening piłki'));
        expect(zosiaUi.shared.custodianLabel, isNotNull);
        expect(zosiaUi.shared.calendarHasSwapTab, isFalse);
      },
    );
  });
}

class _CapturedChildUi {
  final String greeting;
  final ChildDashboardSharedUi shared;

  const _CapturedChildUi({
    required this.greeting,
    required this.shared,
  });
}

Future<_CapturedChildUi> _captureChildDashboard(
  WidgetTester tester,
  AppUser child,
) async {
  await _pumpChildDashboard(tester, child);

  final greetingFinder = find.textContaining('Cześć,');
  expect(greetingFinder, findsOneWidget);
  final greeting = tester.widget<Text>(greetingFinder).data!;

  const expectedNav = ['Dzisiaj', 'Kalendarz', 'Z dziećmi', 'Lista'];
  for (final label in expectedNav) {
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(label),
      ),
      findsOneWidget,
    );
  }

  expect(find.text('Plan na dziś'), findsOneWidget);
  expect(find.text('Jak się dzisiaj czujesz? 💭'), findsOneWidget);

  String? custodianLabel;
  final custodianFinder = find.textContaining('U ');
  if (custodianFinder.evaluate().isNotEmpty) {
    custodianLabel = tester.widget<Text>(custodianFinder.first).data;
  }

  expect(find.textContaining('Trening piłki'), findsWidgets);
  final planEventTitles = ['Trening piłki'];

  await tester.tap(_navTab('Kalendarz'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  final calendarTitle = find.text('Kalendarz opieki');
  expect(calendarTitle, findsOneWidget);
  final calendarHasSwapTab = find.text('Prośby').evaluate().isNotEmpty;

  await tester.tap(_navTab('Z dziećmi'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  final familyMessageFinder = find.textContaining('kolacji');
  expect(familyMessageFinder, findsWidgets);
  final familyChatSnippet =
      tester.widget<Text>(familyMessageFinder.first).data!;

  await tester.tap(_navTab('Lista'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  const listEmptyMessage = 'Moja lista jest pusta';
  expect(find.text(listEmptyMessage), findsOneWidget);
  expect(find.text('Nowa lista'), findsOneWidget);

  return _CapturedChildUi(
    greeting: greeting,
    shared: ChildDashboardSharedUi(
      navLabels: expectedNav,
      custodianLabel: custodianLabel,
      planEventTitles: planEventTitles,
      calendarTitle: 'Kalendarz opieki',
      calendarHasSwapTab: calendarHasSwapTab,
      familyChatSnippet: familyChatSnippet,
      listEmptyMessage: listEmptyMessage,
    ),
  );
}

Future<void> _disposeDashboard(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _navTab(String label) {
  return find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  );
}

Future<void> _pumpChildDashboard(WidgetTester tester, AppUser child) async {
  final preferences = await SharedPreferences.getInstance();
  final offlineStore = OfflineStore(preferences: preferences);
  final apiClient = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
  final calendarRepository = CalendarRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final messagingRepository = MessagingRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final authRepository = AuthRepository(
    apiClient: apiClient,
    preferences: preferences,
    offlineStore: offlineStore,
  );
  final consentRepository = ConsentRepository(apiClient: apiClient);

  final pinLockStore = PinLockStore(preferences: preferences);

  final appProvider = AppProvider(
    authRepository: authRepository,
    consentRepository: consentRepository,
    pinLockStore: pinLockStore,
  );
  final calendarProvider = CalendarProvider(repository: calendarRepository);
  final messagingProvider = MessagingProvider(repository: messagingRepository);

  calendarProvider.initializeSampleData();
  calendarProvider.seedTodayTestEvent(title: 'Trening piłki');
  messagingProvider.initializeChildSampleData();
  appProvider.configureChildTestSession(childUser: child);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ChangeNotifierProvider<CalendarProvider>.value(value: calendarProvider),
        ChangeNotifierProvider<MessagingProvider>.value(value: messagingProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.buildLight(AppTheme.primaryTeal),
        home: const ChildDashboard(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
