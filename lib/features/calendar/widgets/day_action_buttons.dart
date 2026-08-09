import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class DayActionButtons extends StatelessWidget {
  final VoidCallback onRequestSwap;

  const DayActionButtons({
    super.key,
    required this.onRequestSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Zmiany w zatwierdzonym grafiku wymagają akceptacji drugiego rodzica.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRequestSwap,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Zmiana opieki'),
        ),
      ],
    );
  }
}
