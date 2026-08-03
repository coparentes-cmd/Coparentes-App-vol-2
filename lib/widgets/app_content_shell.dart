import 'package:flutter/material.dart';

import '../utils/layout_utils.dart';

/// Centers and caps main app content width on medium/expanded viewports.
class AppContentShell extends StatelessWidget {
  final Widget child;

  const AppContentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxWidth = contentMaxWidthFor(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
