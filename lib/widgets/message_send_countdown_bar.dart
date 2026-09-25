import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Same outer padding/height envelope as [MessageComposeBar] so swapping
/// them during the high-conflict send delay does not jump the layout.
class MessageSendCountdownBar extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback onCancel;

  /// Total length of the countdown window (for progress = remaining / total).
  final int totalSeconds;

  const MessageSendCountdownBar({
    super.key,
    required this.secondsRemaining,
    required this.onCancel,
    this.totalSeconds = 5,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final total = totalSeconds <= 0 ? 5 : totalSeconds;
    final progress = (secondsRemaining / total).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        bottomInset > 0 ? bottomInset + 8 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Wysyłanie za {sekundy}s...').replaceAll(
                  '{sekundy}',
                  '$secondsRemaining',
                ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppTheme.dividerColor,
              color: AppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                context.tr('Anuluj wysyłanie'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
