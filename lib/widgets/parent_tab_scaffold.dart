import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    final color =
        headerColor ??
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.primary;
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

/// Compact action on the green parent tab header (dark pill, right side).
class ParentHeaderActionButton extends StatelessWidget {
  static const Color buttonColor = Color(0xFF2C2C2C);

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const ParentHeaderActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
