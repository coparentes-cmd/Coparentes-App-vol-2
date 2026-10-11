import 'package:flutter/material.dart';

import 'analytics_service.dart';

/// Logs named [Route]s to GA4 when analytics is enabled.
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({AnalyticsService? analytics})
      : _analytics = analytics ?? AnalyticsService.instance;

  final AnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _log(newRoute);
    }
  }

  void _log(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) {
      return;
    }
    _analytics.logScreen(name);
  }
}
