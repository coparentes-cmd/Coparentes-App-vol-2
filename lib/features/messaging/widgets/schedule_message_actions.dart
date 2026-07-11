import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class ScheduleMessageActions extends StatelessWidget {
  final bool alignEnd;
  final bool isLoading;
  final bool autofocus;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const ScheduleMessageActions({
    super.key,
    required this.alignEnd,
    required this.isLoading,
    this.autofocus = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return EnterAcceptScope(
      onAccept: onAccept,
      enabled: !isLoading,
      autofocus: autofocus,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: isLoading ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Odrzuć'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isLoading ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Akceptuj'),
            ),
          ],
        ),
      ),
    );
  }
}
