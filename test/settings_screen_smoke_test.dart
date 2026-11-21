import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/local/pin_lock_store.dart';
import 'package:coparentes/data/repositories/auth_repository.dart';
import 'package:coparentes/data/repositories/consent_repository.dart';
import 'package:coparentes/features/settings/settings_screen.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppProvider app;

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
    final api = AppApiClient(baseUrl: 'http://127.0.0.1:0/api');
    app = AppProvider(
      authRepository: AuthRepository(
        apiClient: api,
        preferences: prefs,
        offlineStore: offline,
      ),
      consentRepository: ConsentRepository(apiClient: api),
      pinLockStore: PinLockStore(preferences: prefs),
      preferences: prefs,
    );
    for (var i = 0; i < 40 && app.isInitializing; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await app.enterDemoRole(UserRole.parentA);
  });

  testWidgets('SettingsScreen opens on phone width without layout asserts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final exceptions = <Object>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      exceptions.add(details.exception);
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Profil'), findsWidgets);

    // Expand remaining accordion headers (profile starts open).
    for (final section in [
      'Przestrzeń',
      'Wygląd',
      'Powiadomienia',
      'Prywatność i zgody',
      'Aplikacja',
    ]) {
      final finder = find.text(section);
      if (finder.evaluate().isEmpty) continue;
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final bad = exceptions.where((e) {
      final s = e.toString();
      return s.contains('Trailing widget') ||
          s.contains('ink splashes') ||
          s.contains('RenderBox was not laid out') ||
          s.contains('Null check operator') ||
          s.contains('A RenderFlex overflowed');
    }).toList();
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
