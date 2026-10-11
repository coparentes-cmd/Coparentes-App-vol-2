import 'package:coparentes/services/message_attachment_service.dart';
import 'package:coparentes/widgets/message_compose_bar.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required TextEditingController controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposeBar(
            controller: controller,
            pendingAttachments: const <PendingMessageAttachment>[],
            onPickAttachment: () {},
            onRemoveAttachment: (_) {},
            onSend: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('emoji button toggles picker without crashing', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpBar(tester, controller: controller);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Emoji'), findsOneWidget);
    expect(find.byType(EmojiPicker), findsNothing);

    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPicker), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPicker), findsNothing);
    expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
  });

  testWidgets('selecting emoji inserts into controller', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpBar(tester, controller: controller);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();

    expect(find.byType(EmojiPicker), findsOneWidget);

    // Tap first emoji cell in the grid (package renders emoji as Text).
    final emojiCells = find.descendant(
      of: find.byType(EmojiPicker),
      matching: find.byType(Text),
    );
    expect(emojiCells, findsWidgets);

    String? tapped;
    for (final element in emojiCells.evaluate()) {
      final widget = element.widget;
      if (widget is! Text) continue;
      final value = widget.data;
      if (value == null || value.trim().isEmpty) continue;
      // Skip labels / category chrome; emoji glyphs are short.
      if (value.runes.length <= 4 && value.contains(RegExp(r'\p{Emoji}', unicode: true))) {
        tapped = value;
        await tester.tap(find.text(value).first);
        break;
      }
    }
    // Fallback: tap first non-empty short Text under picker.
    if (tapped == null) {
      for (final element in emojiCells.evaluate()) {
        final widget = element.widget;
        if (widget is! Text) continue;
        final value = widget.data;
        if (value == null || value.isEmpty || value.length > 8) continue;
        tapped = value;
        await tester.tap(find.text(value).first);
        break;
      }
    }

    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(controller.text, contains(tapped!));
  });
}
