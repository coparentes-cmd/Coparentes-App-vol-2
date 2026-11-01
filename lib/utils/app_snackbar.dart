import 'package:flutter/material.dart';

/// Margin that pins a floating [SnackBar] near the top of the screen.
EdgeInsets topSnackBarMargin(
  Size size,
  EdgeInsets padding, {
  double barHeight = 64,
}) {
  final top = padding.top + 12;
  final bottom = (size.height - top - barHeight).clamp(24.0, size.height);
  // Keep side insets inside the layout width so long error text cannot clip
  // off the phone screen when the viewport meta was missing / scale was off.
  final side = size.width < 360 ? 8.0 : 12.0;
  return EdgeInsets.fromLTRB(side, 0, side, bottom);
}

/// Shows a floating snack bar at the top of the screen (all app messages).
extension AppTopSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showTopSnackBar(
    SnackBar snackBar,
  ) {
    final media = MediaQuery.of(context);
    final margin = topSnackBarMargin(media.size, media.padding);

    hideCurrentSnackBar();
    return showSnackBar(
      SnackBar(
        content: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.35),
          child: snackBar.content,
        ),
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        margin: margin,
        padding: snackBar.padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: snackBar.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        action: snackBar.action,
        actionOverflowThreshold: snackBar.actionOverflowThreshold,
        showCloseIcon: snackBar.showCloseIcon,
        closeIconColor: snackBar.closeIconColor,
        duration: snackBar.duration,
        onVisible: snackBar.onVisible,
        dismissDirection: DismissDirection.up,
        clipBehavior: snackBar.clipBehavior,
      ),
    );
  }
}
