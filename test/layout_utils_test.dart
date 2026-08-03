import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/utils/layout_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(double width, Widget child) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('appBreakpointOf maps compact / medium / expanded by width', (
    tester,
  ) async {
    late AppBreakpoint bp;

    await tester.pumpWidget(
      wrap(
        390,
        Builder(
          builder: (context) {
            bp = appBreakpointOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(bp, AppBreakpoint.compact);

    await tester.pumpWidget(
      wrap(
        768,
        Builder(
          builder: (context) {
            bp = appBreakpointOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(bp, AppBreakpoint.medium);

    await tester.pumpWidget(
      wrap(
        1280,
        Builder(
          builder: (context) {
            bp = appBreakpointOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(bp, AppBreakpoint.expanded);
  });

  testWidgets('useTwoPaneLayout turns on at 900px', (tester) async {
    late bool twoPane;

    await tester.pumpWidget(
      wrap(
        899,
        Builder(
          builder: (context) {
            twoPane = useTwoPaneLayout(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(twoPane, isFalse);

    await tester.pumpWidget(
      wrap(
        900,
        Builder(
          builder: (context) {
            twoPane = useTwoPaneLayout(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(twoPane, isTrue);
  });

  testWidgets('contentMaxWidthFor and gridCrossAxisCountFor follow breakpoint', (
    tester,
  ) async {
    late double maxW;
    late int cols;

    await tester.pumpWidget(
      wrap(
        400,
        Builder(
          builder: (context) {
            maxW = contentMaxWidthFor(context);
            cols = gridCrossAxisCountFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(maxW, double.infinity);
    expect(cols, LayoutTokens.gridColsCompact);

    await tester.pumpWidget(
      wrap(
        800,
        Builder(
          builder: (context) {
            maxW = contentMaxWidthFor(context);
            cols = gridCrossAxisCountFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(maxW, LayoutTokens.contentMaxMedium);
    expect(cols, LayoutTokens.gridColsMedium);

    await tester.pumpWidget(
      wrap(
        1400,
        Builder(
          builder: (context) {
            maxW = contentMaxWidthFor(context);
            cols = gridCrossAxisCountFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(maxW, LayoutTokens.contentMaxExpanded);
    expect(cols, LayoutTokens.gridColsExpanded);
  });

  testWidgets('phone width 390 keeps compact stack chrome (no two-pane / rail)', (
    tester,
  ) async {
    late bool compact;
    late bool expanded;
    late bool twoPane;
    late double maxW;

    await tester.pumpWidget(
      wrap(
        390,
        Builder(
          builder: (context) {
            compact = isCompactBreakpoint(context);
            expanded = isExpandedBreakpoint(context);
            twoPane = useTwoPaneLayout(context);
            maxW = contentMaxWidthFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(compact, isTrue);
    expect(expanded, isFalse);
    expect(twoPane, isFalse);
    expect(maxW, double.infinity);
  });
}
