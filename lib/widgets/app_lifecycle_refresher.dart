import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/offline_sync_provider.dart';

class AppLifecycleRefresher extends StatefulWidget {
  final Widget child;

  const AppLifecycleRefresher({super.key, required this.child});

  @override
  State<AppLifecycleRefresher> createState() => _AppLifecycleRefresherState();
}

class _AppLifecycleRefresherState extends State<AppLifecycleRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }

    final appProvider = context.read<AppProvider>();
    if (appProvider.currentUser == null || appProvider.isDemoMode) {
      return;
    }

    context.read<OfflineSyncProvider>().pollFinanceNow();
    context.read<OfflineSyncProvider>().refreshStatus();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
