import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

/// Full-screen, non-dismissible gate after registration: show E2E recovery code.
class RecoveryCodeDisplayScreen extends StatefulWidget {
  const RecoveryCodeDisplayScreen({
    super.key,
    required this.code,
    required this.onAcknowledged,
    this.isChildAccount = false,
  });

  final String code;
  final VoidCallback onAcknowledged;

  /// Child accounts: parents hold the mailed code; copy/checkbox differ.
  final bool isChildAccount;

  @override
  State<RecoveryCodeDisplayScreen> createState() =>
      _RecoveryCodeDisplayScreenState();
}

class _RecoveryCodeDisplayScreenState extends State<RecoveryCodeDisplayScreen> {
  bool _savedConfirmed = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Kod skopiowany do schowka'))),
    );
  }

  void _continue() {
    if (!_savedConfirmed) return;
    widget.onAcknowledged();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isChild = widget.isChildAccount;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Kod odzyskiwania czatu'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    isChild
                        ? 'Ten kod pozwoli odzyskać historię czatu, jeśli zapomnisz hasła. '
                            'Wysłaliśmy go mailem Twoim rodzicom - oni go przechowają.'
                        : 'Ten kod pozwoli odzyskać historię czatu, jeśli zapomnisz hasła. '
                            'Wysłaliśmy go też mailem. Zapisz go w bezpiecznym miejscu.',
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: SelectableText(
                    widget.code,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: Text(context.tr('Kopiuj')),
                  ),
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _savedConfirmed,
                  onChanged: (value) {
                    setState(() => _savedConfirmed = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.tr(
                      isChild
                          ? 'Rozumiem'
                          : 'Zapisałem kod w bezpiecznym miejscu',
                    ),
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savedConfirmed ? _continue : null,
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: Text(
                      context.tr('Dalej'),
                      style: TextStyle(
                        color: _savedConfirmed
                            ? Colors.white
                            : AppTheme.textHint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
