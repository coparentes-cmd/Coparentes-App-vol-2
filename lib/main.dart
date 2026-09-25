import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_environment.dart';
import 'data/api/app_api_client.dart';
import 'data/local/pin_lock_store.dart';
import 'data/local/offline_store.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/consent_repository.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/documents_repository.dart';
import 'data/repositories/export_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/messaging_repository.dart';
import 'models/models.dart';
import 'providers/app_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/documents_provider.dart';
import 'providers/exports_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/offline_sync_provider.dart';
import 'screens/auth/child_onboarding_sheet.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/child/child_dashboard.dart';
import 'screens/dashboard/parent_dashboard.dart';
import 'screens/observer/observer_dashboard.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lifecycle_refresher.dart';
import 'widgets/message_notification_listener.dart';
import 'widgets/offline_status_banner.dart';
import 'widgets/pin_lock_overlay.dart';
import 'data/local/locale_store.dart';
import 'services/e2e_session_service.dart';
import 'utils/app_browser_back.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installAppBrowserBackHandling();
  await initializeDateFormatting('pl_PL', null);
  await initializeDateFormatting('en_GB', null);
  final preferences = await SharedPreferences.getInstance();
  final localeStore = LocaleStore(preferences: preferences);
  final offlineStore = OfflineStore(preferences: preferences);
  await offlineStore.initialize();
  final pinLockStore = PinLockStore(preferences: preferences);
  final apiClient = AppApiClient(baseUrl: AppEnvironment.apiBaseUrl);
  final e2eSessionService = E2eSessionService(apiClient: apiClient);
  final messagingRepository = MessagingRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
    e2eSessionService: e2eSessionService,
  );
  final exportRepository = ExportRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final calendarRepository = CalendarRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final financeRepository = FinanceRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final documentsRepository = DocumentsRepository(
    apiClient: apiClient,
    offlineStore: offlineStore,
  );
  final consentRepository = ConsentRepository(apiClient: apiClient);

  runApp(
    CoparentesApp(
      authRepository: AuthRepository(
        apiClient: apiClient,
        preferences: preferences,
        offlineStore: offlineStore,
      ),
      consentRepository: consentRepository,
      messagingRepository: messagingRepository,
      exportRepository: exportRepository,
      calendarRepository: calendarRepository,
      financeRepository: financeRepository,
      documentsRepository: documentsRepository,
      offlineStore: offlineStore,
      pinLockStore: pinLockStore,
      apiClient: apiClient,
      localeStore: localeStore,
      e2eSessionService: e2eSessionService,
    ),
  );
}

class CoparentesApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ConsentRepository consentRepository;
  final MessagingRepository messagingRepository;
  final ExportRepository exportRepository;
  final CalendarRepository calendarRepository;
  final FinanceRepository financeRepository;
  final DocumentsRepository documentsRepository;
  final OfflineStore offlineStore;
  final PinLockStore pinLockStore;
  final AppApiClient apiClient;
  final LocaleStore localeStore;
  final E2eSessionService e2eSessionService;

  const CoparentesApp({
    super.key,
    required this.authRepository,
    required this.consentRepository,
    required this.messagingRepository,
    required this.exportRepository,
    required this.calendarRepository,
    required this.financeRepository,
    required this.documentsRepository,
    required this.offlineStore,
    required this.pinLockStore,
    required this.apiClient,
    required this.localeStore,
    required this.e2eSessionService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppProvider(
            authRepository: authRepository,
            consentRepository: consentRepository,
            pinLockStore: pinLockStore,
            localeStore: localeStore,
            initialLocale: localeStore.read(),
            e2eSessionService: e2eSessionService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MessagingProvider(
            repository: messagingRepository,
            e2eSessionService: e2eSessionService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CalendarProvider(repository: calendarRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => FinanceProvider(repository: financeRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => DocumentsProvider(repository: documentsRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ExportsProvider(repository: exportRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => OfflineSyncProvider(
            apiClient: apiClient,
            messagingRepository: messagingRepository,
            exportRepository: exportRepository,
            calendarRepository: calendarRepository,
            financeRepository: financeRepository,
            documentsRepository: documentsRepository,
            offlineStore: offlineStore,
            refreshMessaging: () async {
              final appProvider = context.read<AppProvider>();
              if (appProvider.isDemoMode) {
                return;
              }
              await context.read<MessagingProvider>().loadThreads(
                    viewerUserId: appProvider.currentUser?.id,
                    notifyEnabled: appProvider.notifyMessages &&
                        !appProvider.highConflictMode,
                    silent: true,
                  );
            },
            refreshFinance: () async {
              final appProvider = context.read<AppProvider>();
              if (appProvider.isDemoMode) {
                return;
              }
              await context.read<FinanceProvider>().load(silent: true);
            },
            refreshData: () async {
              final appProvider = context.read<AppProvider>();
              if (appProvider.isDemoMode) {
                return;
              }
              await context.read<ExportsProvider>().loadExports();
              await context.read<CalendarProvider>().load(silent: true);
              await context.read<FinanceProvider>().load(silent: true);
              await context.read<DocumentsProvider>().load(
                    viewerUserId: appProvider.currentUser?.id,
                  );
            },
          ),
        ),
      ],
      child: Consumer<AppProvider>(
        builder: (context, ap, _) {
          return MaterialApp(
            key: ValueKey('app-locale-${ap.locale.languageCode}'),
            title: 'Coparentes',
            debugShowCheckedModeBanner: false,
            themeMode: ap.themeMode,
            locale: ap.locale,
            supportedLocales: const [
              Locale('pl'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.buildLight(ap.colorScheme.primary),
            darkTheme: AppTheme.buildDark(ap.colorScheme.primary),
            builder: (context, child) {
              return _DemoLocaleSync(
                child: PinLockGate(
                  child: AppLifecycleRefresher(
                    child: MessageNotificationListener(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: child ?? const SizedBox.shrink(),
                          ),
                          const Align(
                            alignment: Alignment.topCenter,
                            child: OfflineStatusBanner(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            home: const _AppGate(),
          );
        },
      ),
    );
  }
}

class _DemoLocaleSync extends StatelessWidget {
  final Widget child;

  const _DemoLocaleSync({required this.child});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final languageCode = app.language;
    if (app.isDemoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CalendarProvider>().localizeDemoSeed(languageCode);
        context.read<FinanceProvider>().localizeDemoSeed(languageCode);
        context.read<MessagingProvider>().localizeDemoSeed(languageCode);
        context.read<AppProvider>().applyDemoWorkspaceName();
      });
    }
    return child;
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  String? _hydratedUserId;
  String? _onboardingPromptUserId;
  bool _e2eCacheBridgeWired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_e2eCacheBridgeWired) {
      return;
    }
    _e2eCacheBridgeWired = true;
    context.read<AppProvider>().onE2eSessionChanged =
        context.read<MessagingProvider>().clearDecryptCaches;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    if (appProvider.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = appProvider.currentUser;
    if (user == null) {
      _hydratedUserId = null;
      _onboardingPromptUserId = null;
      return const RoleSelectionScreen();
    }

    _hydrateSession(user.id);
    _maybeShowChildOnboarding(user.id, appProvider);

    switch (user.role) {
      case UserRole.child:
        return const ChildDashboard();
      case UserRole.observer:
        return const ObserverDashboard();
      case UserRole.parentA:
      case UserRole.parentB:
        return const ParentDashboard();
    }
  }

  void _hydrateSession(String userId) {
    if (_hydratedUserId == userId) {
      return;
    }

    _hydratedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final messagingProvider = context.read<MessagingProvider>();
      final exportsProvider = context.read<ExportsProvider>();
      final calendarProvider = context.read<CalendarProvider>();
      final financeProvider = context.read<FinanceProvider>();
      final documentsProvider = context.read<DocumentsProvider>();
      final offlineProvider = context.read<OfflineSyncProvider>();
      final isDemoMode = context.read<AppProvider>().isDemoMode;

      if (isDemoMode) {
        messagingProvider.clear();
        exportsProvider.clear();
        calendarProvider.clear();
        financeProvider.clear();
        documentsProvider.clear();

        // Seed messaging/finance/exports synchronously BEFORE any await so
        // IndexedStack panels (e.g. InlineCategoryChatPanel) never resolve
        // against an empty provider and stick on "Nie udało się otworzyć…".
        if (context.read<AppProvider>().currentUser?.role == UserRole.child) {
          messagingProvider.initializeChildSampleData();
        } else {
          messagingProvider.initializeSampleData();
        }
        financeProvider.initializeSampleData();
        exportsProvider.initializeSampleData();

        // Always re-seed demo calendar so the fixed day (10.08.2026) and
        // sample events are not replaced by a stale offline snapshot.
        calendarProvider.initializeSampleData();
        final languageCode = context.read<AppProvider>().language;
        calendarProvider.localizeDemoSeed(languageCode);
        financeProvider.localizeDemoSeed(languageCode);
        messagingProvider.localizeDemoSeed(languageCode);
        context.read<AppProvider>().applyDemoWorkspaceName();
      } else {
        final appProvider = context.read<AppProvider>();
        final role = appProvider.currentUser?.role;
        final isChild = role == UserRole.child;

        if (isChild) {
          await messagingProvider.loadThreads(
            viewerUserId: appProvider.currentUser?.id,
            notifyEnabled: appProvider.notifyMessages,
          );
          await calendarProvider.load();
        } else {
          await messagingProvider.loadThreads(
            viewerUserId: appProvider.currentUser?.id,
            notifyEnabled: appProvider.notifyMessages,
          );
          await exportsProvider.loadExports();
          await offlineProvider.refreshStatus();
          await calendarProvider.load();
          await financeProvider.load();
          await documentsProvider.load(viewerUserId: appProvider.currentUser?.id);
        }
      }
    });
  }

  void _maybeShowChildOnboarding(String userId, AppProvider appProvider) {
    final user = appProvider.currentUser;
    final workspace = appProvider.currentWorkspace;

    if (user == null ||
        user.role != UserRole.parentA ||
        !appProvider.needsChildOnboarding ||
        appProvider.isDemoMode ||
        _onboardingPromptUserId == userId) {
      return;
    }

    if (workspace != null && workspace.children.isNotEmpty) {
      appProvider.completeChildOnboarding();
      return;
    }

    _onboardingPromptUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await showChildOnboardingSheet(context);
      if (!mounted) {
        return;
      }

      if (context.read<AppProvider>().needsChildOnboarding) {
        context.read<AppProvider>().completeChildOnboarding();
      }
    });
  }
}
