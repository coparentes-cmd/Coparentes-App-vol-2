import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/layout_utils.dart';
import 'app_content_shell.dart';

/// Shared inset header for parent bottom-nav tabs — matches content width.
class ParentTabScaffold extends StatelessWidget {
  static const horizontalInset = AppSpace.screenHorizontal;
  static const topInset = 8.0;
  static const borderRadius = AppRadius.xl;
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

  @override
  Widget build(BuildContext context) {
    final color = headerColor ?? AppTheme.brandHeaderBlue;
    final topPadding = MediaQuery.paddingOf(context).top;
    final sideInset = parentTabHeaderHorizontalInset(context);
    final topGap = parentTabHeaderTopInset(context);
    final resolvedHeaderHeight =
        parentTabResolvedHeaderHeight(context, headerHeight);
    final resolvedTabBarHeight = parentTabResolvedTabBarHeight(context);
    final headerRadius = BorderRadius.circular(borderRadius);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      floatingActionButton: floatingActionButton,
      body: AppContentShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sideInset,
                topPadding + topGap,
                sideInset,
                0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: headerRadius,
                  boxShadow: AppShadows.headerGlow(color),
                ),
                child: Material(
                  color: color,
                  borderRadius: headerRadius,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: resolvedHeaderHeight,
                        child: header ??
                            AppBar(
                              primary: false,
                              automaticallyImplyLeading: false,
                              elevation: 0,
                              scrolledUnderElevation: 0,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              toolbarHeight: resolvedHeaderHeight,
                              title: Text(
                                title!,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              actions: actions,
                            ),
                      ),
                      if (tabBar != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: SizedBox(
                              height: resolvedTabBarHeight,
                              child: Material(
                                color: Colors.transparent,
                                child: tabBar!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Default header height when a screen has tabs under the title row.
double parentTabbedHeaderHeight() =>
    ParentTabScaffold.toolbarHeight + ParentTabScaffold.tabBarHeight;

/// Label (+ optional badge) for header [TabBar] pills.
///
/// Custom [Tab.child] widgets do not reliably pick up [TabBarTheme.labelColor]
/// on Flutter web, so selected state must set contrast colors explicitly
/// (dark blue on the white pill, light text when unselected).
class ParentHeaderTabLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final int badgeCount;

  const ParentHeaderTabLabel({
    super.key,
    required this.label,
    required this.selected,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.brandHeaderBlue
        : Colors.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
        if (badgeCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryTeal : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$badgeCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppTheme.primaryTeal,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact action on the parent tab header (rounded square, right side).
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
    final resolvedBg = backgroundColor ?? Colors.white.withValues(alpha: 0.16);
    final brandFill = backgroundColor == AppTheme.purpleColor ||
        backgroundColor == AppTheme.primaryTeal ||
        backgroundColor == AppTheme.coralColor;
    final iconColor =
        brandFill ? AppTheme.onBrandFill(backgroundColor!) : Colors.white;
    final glow = brandFill
        ? AppShadows.glow(backgroundColor!)
        : const <BoxShadow>[];

    // `prominent` kept for call-site compatibility; square actions are uniform.
    final _ = prominent;

    final button = Material(
      color: resolvedBg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Tooltip(
          message: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: glow,
            ),
            child: button,
          ),
        ),
      ),
    );
  }
}
