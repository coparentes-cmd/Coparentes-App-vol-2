import 'package:flutter/material.dart';

/// Margin that pins a floating [SnackBar] near the top of the screen.
EdgeInsets topSnackBarMargin(
  Size size,
  EdgeInsets padding, {
  double barHeight = 64,
  double viewInsetsBottom = 0,
}) {
  final top = padding.top + 12;
  // Subtract keyboard inset — otherwise Flutter asserts "presented off screen"
  // during login when the soft keyboard is open.
  final usableHeight =
      (size.height - viewInsetsBottom).clamp(120.0, size.height);
  final bottom =
      (usableHeight - top - barHeight).clamp(24.0, usableHeight);
  final side = size.width < 360 ? 8.0 : 12.0;
  return EdgeInsets.fromLTRB(side, 0, side, bottom);
}

/// Shows a floating snack bar at the top of the screen (all app messages).
extension AppTopSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showTopSnackBar(
    SnackBar snackBar,
  ) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final margin = topSnackBarMargin(
      media.size,
      media.padding,
      viewInsetsBottom: media.viewInsets.bottom,
    );

    hideCurrentSnackBar();
    return showSnackBar(
      SnackBar(
        content: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.35),
          child: snackBar.content,
        ),
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        // Fixed avoids off-screen asserts when keyboard + floating margin fight.
        margin: keyboardOpen ? null : margin,
        padding: snackBar.padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: snackBar.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: keyboardOpen
            ? SnackBarBehavior.fixed
            : SnackBarBehavior.floating,
        action: snackBar.action,
        actionOverflowThreshold: snackBar.actionOverflowThreshold,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: snackBar.closeIconColor,
        duration: snackBar.duration ?? const Duration(seconds: 4),
        onVisible: snackBar.onVisible,
        dismissDirection:
            keyboardOpen ? DismissDirection.down : DismissDirection.up,
        clipBehavior: snackBar.clipBehavior,
      ),
    );
  }
}
