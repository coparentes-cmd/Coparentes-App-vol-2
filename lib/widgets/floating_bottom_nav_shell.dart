import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Floating white capsule around an existing [BottomNavigationBar].
/// Keeps the bar widget type so tests and semantics stay stable.
class FloatingBottomNavShell extends StatelessWidget {
  final Widget child;

  const FloatingBottomNavShell({super.key, required this.child});

  /// Space to clear the floating nav capsule (scroll / compose).
  ///
  /// Reads the physical home-indicator inset from [View], not ambient
  /// [MediaQuery.viewPadding] — nested Scaffolds / extendBody often zero
  /// viewPadding.bottom, which left compose sitting under this capsule.
  static double contentBottomInset(BuildContext context) {
    final safe =
        MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    // Material 3 BottomNavigationBar (~80) + capsule bottom margin + gap
    // above the pill so compose / send are not flush with the bar shadow.
    return 80 + AppSpace.navMargin + safe + 28;
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
