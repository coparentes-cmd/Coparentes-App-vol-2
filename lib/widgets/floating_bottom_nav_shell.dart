import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Floating white capsule around an existing [BottomNavigationBar].
/// Keeps the bar widget type so tests and semantics stay stable.
class FloatingBottomNavShell extends StatelessWidget {
  final Widget child;

  const FloatingBottomNavShell({super.key, required this.child});

  /// Approximate bar height used for scroll bottom padding under a floating nav.
  static double contentBottomInset(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    // Icon + label + vertical padding inside the bar ≈ 64, plus outer margin.
    return 64 + AppSpace.navMargin + safe;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.navMargin,
        0,
        AppSpace.navMargin,
        AppSpace.navMargin + safeBottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.nav,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Material(
            color: Colors.white,
            child: child,
          ),
        ),
      ),
    );
  }
}
