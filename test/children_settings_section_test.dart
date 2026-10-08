import 'package:coparentes/features/settings/widgets/children_settings_section.dart';
import 'package:coparentes/features/settings/widgets/delete_child_password_dialog.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChildProfile _child({
  required String id,
  required String name,
  String? inviteCode,
}) {
  return ChildProfile(
    id: id,
    name: name,
    dateOfBirth: DateTime.utc(2013, 7, 24),
    inviteCode: inviteCode,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dzieci expands to child names; child expands to actions',
      (tester) async {
    ChildProfile? edited;
    ChildProfile? deleted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChildrenSettingsSection(
              children: [
                _child(id: 'c1', name: 'basia', inviteCode: 'CHILDCODE1'),
              ],
              userRole: UserRole.parentA,
              roleColor: AppTheme.primaryTeal,
              isDark: false,
              onAddChild: () {},
              onCopyInvite: (_) {},
              onEdit: (c) => edited = c,
              onDelete: (c) => deleted = c,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('child_row_c1')), findsNothing);
    expect(find.byKey(const Key('child_copy_c1')), findsNothing);
    expect(find.byKey(const Key('child_edit_c1')), findsNothing);
    expect(find.byKey(const Key('child_delete_c1')), findsNothing);

    await tester.tap(find.byKey(const Key('children_section_header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('child_row_c1')), findsOneWidget);
    expect(find.byKey(const Key('child_copy_c1')), findsNothing);

    await tester.tap(find.byKey(const Key('child_row_c1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('child_copy_c1')), findsOneWidget);
    expect(find.byKey(const Key('child_edit_c1')), findsOneWidget);
    expect(find.byKey(const Key('child_delete_c1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('child_edit_c1')));
    await tester.pump();
    expect(edited?.id, 'c1');

    await tester.tap(find.byKey(const Key('child_delete_c1')));
    await tester.pump();
    expect(deleted?.id, 'c1');
  });

  testWidgets('delete dialog requires password before returning it',
      (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDeleteChildPasswordDialog(
                  context,
                  childName: 'basia',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('delete_child_password_field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_child_confirm_button')));
    await tester.pump();
    expect(result, isNull);
    expect(
      find.text('Wpisz hasło').evaluate().isNotEmpty ||
          find.text('Enter password').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const Key('delete_child_password_field')),
      'SecretPass1!',
    );
    await tester.tap(find.byKey(const Key('delete_child_confirm_button')));
    await tester.pumpAndSettle();
    expect(result, 'SecretPass1!');
  });
}
