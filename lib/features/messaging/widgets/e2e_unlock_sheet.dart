import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../providers/app_provider.dart';
import '../../../services/e2e_crypto_service.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet: ask for login password to unlock messages after process restart.
///
/// Returns `true` if unlocked, `false` if cancelled.
Future<bool> showE2eUnlockSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const _E2eUnlockSheet(),
  );
  return result == true;
}

class _E2eUnlockSheet extends StatefulWidget {
  const _E2eUnlockSheet();

  @override
  State<_E2eUnlockSheet> createState() => _E2eUnlockSheetState();
}

class _E2eUnlockSheetState extends State<_E2eUnlockSheet> {
  static const _maxFailedAttempts = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  final _passwordController = TextEditingController();
  String? _error;
  bool _submitting = false;
  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  bool get _isLockedOut => _lockoutSecondsRemaining > 0;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  void _startLockout() {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSecondsRemaining = _lockoutDuration.inSeconds;
      _failedAttempts = 0;
      _error =
          'Zbyt wiele nieudanych prób. Spróbuj ponownie za $_lockoutSecondsRemaining s.';
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSecondsRemaining = 0;
          _error = null;
        });
        return;
      }
      setState(() {
        _lockoutSecondsRemaining -= 1;
        _error =
            'Zbyt wiele nieudanych prób. Spróbuj ponownie za $_lockoutSecondsRemaining s.';
      });
    });
  }

  Future<void> _submit() async {
    if (_isLockedOut || _submitting) {
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Podaj hasło');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<AppProvider>().unlockE2eWithPassword(password);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on InvalidPasswordException {
      if (!mounted) {
        return;
      }
      final nextFailures = _failedAttempts + 1;
      setState(() {
        _submitting = false;
        _failedAttempts = nextFailures;
        _error = 'Nieprawidłowe hasło';
        _passwordController.clear();
      });
      if (nextFailures >= _maxFailedAttempts) {
        _startLockout();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = 'Nie udało się odblokować wiadomości. Spróbuj ponownie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppProvider>().primaryColor;
    final canSubmit = !_submitting && !_isLockedOut;

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
            context.tr('Podaj hasło, aby odblokować wiadomości'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Po restarcie aplikacji potrzebujemy hasła, żeby pokazać treść rozmów.',
            ),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: canSubmit,
            autofocus: true,
            onSubmitted: (_) => canSubmit ? _submit() : null,
            decoration: InputDecoration(
              labelText: context.tr('Hasło'),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isLockedOut
                          ? 'Odblokuj ($_lockoutSecondsRemaining s)'
                          : context.tr('Odblokuj'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context, false),
            child: Text(context.tr('Anuluj')),
          ),
        ],
      ),
    );
  }
}
