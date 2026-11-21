import 'package:coparentes/features/settings/widgets/action_tile.dart';
import 'package:coparentes/features/settings/widgets/info_tile.dart';
import 'package:coparentes/features/settings/widgets/ios_settings_accordion.dart';
import 'package:coparentes/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('InfoTile long/multiline values do not assert on phone width',
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
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              IosSettingsAccordion(
                title: 'Przestrzeń',
                icon: Icons.home_outlined,
                expanded: true,
                isDark: false,
                accent: AppTheme.primaryTeal,
                onToggle: () {},
                children: [
                  InfoTile(
                    icon: Icons.people_outline,
                    label: 'Członkowie',
                    value:
                        'Anna Kowalska (Rodzic A)\nJan Nowak (Rodzic B)\nBasia (Dziecko)',
                    isDark: false,
                  ),
                  InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Adres e-mail',
                    value: 'sim-push-1795276956@test.coparentes.app',
                    isDark: false,
                  ),
                  ActionTile(
                    icon: Icons.family_restroom_outlined,
                    label: 'Kod zaproszenia dla drugiego rodzica',
                    subtitle: 'ABC123XY · ważne do 31.12.2026',
                    color: AppTheme.primaryTeal,
                    isDark: false,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Członkowie'), findsOneWidget);
    expect(find.textContaining('Anna Kowalska'), findsOneWidget);
    expect(
      exceptions.where((e) => e.toString().contains('Trailing widget')),
      isEmpty,
      reason: 'Trailing width assert must not fire',
    );
    expect(
      exceptions.where((e) => e.toString().contains('ink splashes')),
      isEmpty,
      reason: 'ListTile Material assert must not fire',
    );
  });
}
