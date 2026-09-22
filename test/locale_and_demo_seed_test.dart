import 'package:coparentes/config/messaging_categories.dart';
import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/locale_store.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/calendar_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/data/repositories/finance_repository.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/l10n/locale_policy.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:coparentes/providers/calendar_provider.dart';
import 'package:coparentes/providers/finance_provider.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('missing stored locale stays Polish', () {
    expect(localeFromStoredCode(null).languageCode, 'pl');
    expect(localeFromStoredCode('').languageCode, 'pl');
    expect(dateFormattingLocale(const Locale('pl')), 'pl_PL');
  });

  test('stored de and fr are ignored', () async {
    SharedPreferences.setMockInitialValues({
      LocaleStore.storageKey: 'de',
    });
    final preferences = await SharedPreferences.getInstance();
    expect(LocaleStore(preferences: preferences).read().languageCode, 'pl');

    await preferences.setString(LocaleStore.storageKey, 'fr');
    expect(LocaleStore(preferences: preferences).read().languageCode, 'pl');
  });

  test('explicit English survives a new provider', () async {
    final first = await _app();
    first.setLocale(const Locale('en'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    final store = LocaleStore(preferences: preferences);
    expect(store.read().languageCode, 'en');

    final second = await _app(store: store, initialLocale: store.read());
    expect(second.language, 'en');
    expect(second.locale.languageCode, 'en');
    expect(dateFormattingLocale(second.locale), 'en_GB');
  });

  test('country change does not change the UI language', () async {
    final app = await _app();
    app.setCountryProfile('DE');
    expect(app.language, 'pl');
    expect(app.locale.languageCode, 'pl');
    expect(app.currencyCode, 'EUR');
    expect(app.countryProfile.languageCode, 'de');
  });

  test('English demo copy changes only the original seed ids', () async {
    final preferences = await SharedPreferences.getInstance();
    final offlineStore = OfflineStore(preferences: preferences);
    final apiClient = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
    final calendar = CalendarProvider(
      repository: CalendarRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );
    final finance = FinanceProvider(
      repository: FinanceRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );

    calendar.initializeSampleData();
    calendar.seedTodayTestEvent(title: 'Sesja lokalna');
    finance.initializeSampleData();

    calendar.localizeDemoSeed('en');
    finance.localizeDemoSeed('en');

    final breakfast = calendar.events.firstWhere((event) => event.id == 'evt_demo_1');
    final englishLesson =
        calendar.events.firstWhere((event) => event.id == 'evt_demo_2');
    final session =
        calendar.events.firstWhere((event) => event.title == 'Sesja lokalna');
    expect(breakfast.title, 'Breakfast');
    expect(breakfast.location, 'Home');
    expect(englishLesson.location, 'ul. Mokotowska 12');
    expect(session.title, 'Sesja lokalna');

    final textbooks = finance.expenses.firstWhere((expense) => expense.id == 'exp_002');
    expect(textbooks.title, 'School textbooks');
    expect(textbooks.category, 'Szkoła');

    calendar.localizeDemoSeed('pl');
    expect(
      calendar.events.firstWhere((event) => event.id == 'evt_demo_1').title,
      'Śniadanie',
    );
    expect(
      calendar.events.firstWhere((event) => event.title == 'Sesja lokalna').title,
      'Sesja lokalna',
    );
  });

  test('English demo messaging and swaps change only seed ids', () async {
    final preferences = await SharedPreferences.getInstance();
    final offlineStore = OfflineStore(preferences: preferences);
    final apiClient = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
    final calendar = CalendarProvider(
      repository: CalendarRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );
    final messaging = MessagingProvider(
      repository: MessagingRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );

    calendar.initializeSampleData();
    messaging.initializeSampleData();
    messaging.threads.add(
      MessageThread(
        id: 'thread_session_local',
        subject: 'Sesja lokalna',
        category: 'Wszystkie',
        lastActivity: DateTime(2026, 8, 10, 12),
        hasUnread: false,
        messages: [
          Message(
            id: 'msg_session_local',
            threadId: 'thread_session_local',
            senderId: 'user_demo_parent_a',
            senderName: 'Anna Kowalska',
            content: 'Treść sesji lokalnej',
            tone: MessageTone.neutral,
            attachments: const [],
            sentAt: DateTime(2026, 8, 10, 12),
            isDelivered: true,
            isRead: true,
            hash: 'sha256_msg_session_local',
          ),
        ],
      ),
    );

    calendar.localizeDemoSeed('en');
    messaging.localizeDemoSeed('en');

    final englishMsg = messaging.threads
        .expand((thread) => thread.messages)
        .firstWhere((message) => message.id == 'msg_demo_001');
    expect(
      englishMsg.content,
      'Can we move English from Tuesday to Wednesday at 17:00?',
    );

    final family = messaging.threads.firstWhere(
      (thread) => thread.id == 'thread_demo_family',
    );
    expect(family.subject, 'Rodzina');
    expect(family.category, 'Rodzina');
    expect(
      family.messages.single.content,
      'Remember dinner at 18:30!',
    );

    final custom = messaging.threads.firstWhere(
      (thread) => thread.id == 'thread_demo_001',
    );
    expect(custom.subject, 'English – schedule change');
    expect(custom.category, 'Szkoła');

    final session = messaging.threads.firstWhere(
      (thread) => thread.id == 'thread_session_local',
    );
    expect(session.subject, 'Sesja lokalna');
    expect(session.messages.single.content, 'Treść sesji lokalnej');

    final pendingSwap =
        calendar.swapRequests.firstWhere((swap) => swap.id == 'swap_001');
    expect(pendingSwap.reason, 'Business trip to Krakow');
    final acceptedSwap =
        calendar.swapRequests.firstWhere((swap) => swap.id == 'swap_002');
    expect(acceptedSwap.reason, 'Grandma’s birthday');
    expect(acceptedSwap.responseNote, 'Of course, no problem.');
  });

  test('EN display labels translate while expense category id stays Polish', () async {
    final preferences = await SharedPreferences.getInstance();
    final offlineStore = OfflineStore(preferences: preferences);
    final apiClient = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
    final finance = FinanceProvider(
      repository: FinanceRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );
    final messaging = MessagingProvider(
      repository: MessagingRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      ),
    );

    finance.initializeSampleData();
    messaging.initializeSampleData();
    finance.localizeDemoSeed('en');
    messaging.localizeDemoSeed('en');

    final textbooks =
        finance.expenses.firstWhere((expense) => expense.id == 'exp_002');
    expect(textbooks.category, 'Szkoła');
    expect(AppStrings.translate('en', textbooks.category), 'School');
    expect(AppStrings.translate('en', textbooks.statusLabel), 'Accepted');
    expect(AppStrings.translate('en', 'Rozliczone'), 'Settled');

    final family = messaging.threads.firstWhere(
      (thread) => thread.id == 'thread_demo_family',
    );
    expect(family.category, 'Rodzina');
    expect(AppStrings.translate('en', threadListTitle(family)), 'With kids');
    expect(
      messaging.threads
          .firstWhere((thread) => thread.id == 'thread_demo_001')
          .subject,
      'English – schedule change',
    );
  });

  test('demo workspace name follows the explicit language', () async {
    final app = await _app();
    await app.enterDemoRole(UserRole.parentA);
    expect(app.currentWorkspace?.name, 'Rodzina Kowalskich — demo');
    app.setLocale(const Locale('en'));
    expect(app.currentWorkspace?.name, 'Kowalski family — demo');
    expect(app.currentWorkspace?.id, 'workspace_demo_001');
  });
}

Future<AppProvider> _app({
  LocaleStore? store,
  Locale? initialLocale,
}) async {
  final preferences = await SharedPreferences.getInstance();
  final offlineStore = OfflineStore(preferences: preferences);
  final apiClient = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
  final localeStore = store ?? LocaleStore(preferences: preferences);
  final app = AppProvider(
    authRepository: AuthRepository(
      apiClient: apiClient,
      preferences: preferences,
      offlineStore: offlineStore,
    ),
    consentRepository: ConsentRepository(apiClient: apiClient),
    pinLockStore: PinLockStore(preferences: preferences),
    localeStore: localeStore,
    initialLocale: initialLocale ?? localeStore.read(),
  );
  for (var i = 0; i < 20 && app.isInitializing; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return app;
}
