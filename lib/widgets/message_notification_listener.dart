import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class MessageNotificationListener extends StatefulWidget {
  final Widget child;

  const MessageNotificationListener({super.key, required this.child});

  @override
  State<MessageNotificationListener> createState() =>
      _MessageNotificationListenerState();
}

class _MessageNotificationListenerState extends State<MessageNotificationListener> {
  String? _lastShownAlert;

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<MessagingProvider>().pendingNewMessageAlert;

    if (alert == null && _lastShownAlert != null) {
      _lastShownAlert = null;
    }

    if (alert != null && alert != _lastShownAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final messaging = context.read<MessagingProvider>();
        if (messaging.pendingNewMessageAlert != alert) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nowa wiadomość: $alert',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryTeal,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          ),
        );

        messaging.clearPendingNotification();
        setState(() => _lastShownAlert = alert);
      });
    }

    return widget.child;
  }
}
