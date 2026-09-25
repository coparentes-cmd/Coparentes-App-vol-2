import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Password confirmation step for account soft-delete.
class DeleteAccountSheet extends StatefulWidget {
  final Color color;

  const DeleteAccountSheet({required this.color});

  @override
  State<DeleteAccountSheet> createState() => DeleteAccountSheetState();
}

class DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final ap = context.read<AppProvider>();
    final ok = await ap.deleteAccount(password: password);

    if (!mounted) {
      return;
    }

    if (!ok) {
      setState(() {
        _submitting = false;
        _inlineError = ap.authError ??
            context.tr('Nie udało się usunąć konta, spróbuj ponownie później');
      });
      return;
    }

    final doneMessage = context.tr('Twoje konto zostało usunięte');
    Navigator.of(context).pop();
    // Same local cleanup as Settings → Wyloguj (E2E clearAll + token + offline).
    ap.logout();
    messenger.showSnackBar(
      SnackBar(
        content: Text(doneMessage),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _passwordController.text.isNotEmpty && !_submitting;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Potwierdź usunięcie konta'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Wpisz hasło, aby trwale usunąć konto.'),
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_submitting,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.tr('Hasło'),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _inlineError,
            ),
            onSubmitted: (_) {
              if (canSubmit) {
                _submit();
              }
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                disabledBackgroundColor:
                    AppTheme.errorColor.withValues(alpha: 0.4),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.tr('Usuń konto na zawsze'),
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(context.tr('Anuluj')),
            ),
          ),
        ],
      ),
    );
  }
}
