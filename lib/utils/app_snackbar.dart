import 'package:flutter/material.dart';

/// Margin that pins a floating [SnackBar] near the top of the screen.
EdgeInsets topSnackBarMargin(
  Size size,
  EdgeInsets padding, {
  double barHeight = 64,
}) {
  final top = padding.top + 12;
  final bottom = (size.height - top - barHeight).clamp(24.0, size.height);
  return EdgeInsets.fromLTRB(12, 0, 12, bottom);
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
        content: snackBar.content,
        backgroundColor: snackBar.backgroundColor,
        elevation: snackBar.elevation,
        margin: margin,
        padding: snackBar.padding,
        shape: snackBar.shape,
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
