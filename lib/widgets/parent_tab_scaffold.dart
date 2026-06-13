import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/layout_utils.dart';

/// Shared inset header for parent bottom-nav tabs — matches content width (16px).
class ParentTabScaffold extends StatelessWidget {
  static const horizontalInset = 16.0;
  static const topInset = 8.0;
  static const borderRadius = 14.0;
  static const toolbarHeight = kToolbarHeight;
  static const tabBarHeight = 48.0;

  final Widget? header;
  final double headerHeight;
  final String? title;
  final List<Widget>? actions;
  final TabBar? tabBar;
  final Color? headerColor;
  final Widget body;
  final Widget? floatingActionButton;

  const ParentTabScaffold({
    super.key,
    this.header,
    this.headerHeight = toolbarHeight,
    this.title,
    this.actions,
    this.tabBar,
    this.headerColor,
    required this.body,
    this.floatingActionButton,
  }) : assert(header != null || title != null);

  double get _totalHeaderHeight =>
      headerHeight + (tabBar != null ? tabBarHeight : 0);

  @override
  Widget build(BuildContext context) {
    final color = headerColor ?? AppTheme.brandHeaderBlue;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      floatingActionButton: floatingActionButton,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalInset,
              topPadding + topInset,
              horizontalInset,
              0,
            ),
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: header ??
                        AppBar(
                          primary: false,
                          automaticallyImplyLeading: false,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          title: Text(title!),
                          actions: actions,
                        ),
                  ),
                  if (tabBar != null)
                    Material(
                      color: Colors.transparent,
                      child: tabBar!,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Default header height when a screen has tabs under the title row.
double parentTabbedHeaderHeight() =>
    ParentTabScaffold.toolbarHeight + ParentTabScaffold.tabBarHeight;

/// Compact action on the green parent tab header (pill, right side).
class ParentHeaderActionButton extends StatelessWidget {
  static const Color buttonColor = Color(0xFF2C2C2C);

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final bool prominent;

  const ParentHeaderActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? buttonColor;
    final compact = isCompactPhoneLayout(context);
    final iconOnly = useIconOnlyHeaderActions(context, label: label);

    final horizontalPadding = iconOnly
        ? 8.0
        : compact
            ? (prominent ? 10.0 : 8.0)
            : (prominent ? 16.0 : 12.0);
    final verticalPadding = iconOnly
        ? 7.0
        : compact
            ? (prominent ? 6.0 : 5.0)
            : (prominent ? 11.0 : 8.0);
    final iconSize = iconOnly
        ? 16.0
        : compact
            ? (prominent ? 16.0 : 14.0)
            : (prominent ? 20.0 : 16.0);
    final fontSize = compact
        ? (prominent ? 11.0 : 11.0)
        : (prominent ? 14.0 : 12.0);

    final buttonStyle = TextButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          iconOnly ? 18 : (prominent ? (compact ? 18 : 24) : (compact ? 16 : 20)),
        ),
      ),
    );

    final button = iconOnly
        ? TextButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Icon(icon, size: iconSize),
          )
        : TextButton.icon(
            onPressed: onPressed,
            style: buttonStyle,
            icon: Icon(icon, size: iconSize),
            label: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(right: compact ? 4 : 8),
      child: Center(
        child: iconOnly
            ? Tooltip(message: label, child: button)
            : button,
      ),
    );
  }
}
