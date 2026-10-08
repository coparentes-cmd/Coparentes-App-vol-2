import 'package:coparentes/features/settings/widgets/email_invite_sheet.dart';
import 'package:coparentes/features/settings/widgets/parent_invite_actions_sheet.dart';
import 'package:coparentes/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parent invite sheet offers copy and send-email actions',
      (tester) async {
    ParentInviteAction? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await ParentInviteActionsSheet.show(
                  context,
                  inviteCode: 'TEST-CODE-123',
                  color: AppTheme.primaryTeal,
                );
              },
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
    // Test env locale is often en → overlay "Send code by email".
    expect(
      find.textContaining('kod e-mailem').evaluate().isNotEmpty ||
          find.textContaining('code by email').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('TEST-CODE-123'), findsOneWidget);

    await tester.tap(find.byKey(const Key('parent_invite_copy')));
    await tester.pumpAndSettle();
    expect(chosen, ParentInviteAction.copy);
  });

  testWidgets('parent invite sheet send-email action returns sendEmail',
      (tester) async {
    ParentInviteAction? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await ParentInviteActionsSheet.show(
                  context,
                  inviteCode: 'CODE-XYZ',
                  color: AppTheme.primaryTeal,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parent_invite_send_email')));
    await tester.pumpAndSettle();
    expect(chosen, ParentInviteAction.sendEmail);
  });

  testWidgets('email invite sheet keeps send button and copy action',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EmailInviteSheet(
              color: AppTheme.primaryTeal,
              inviteCode: 'INVITE-99',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('email_invite_copy_code')), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('email_invite_copy_code')));
    await tester.pumpAndSettle();
    // Copy path must not throw; send button remains available.
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
