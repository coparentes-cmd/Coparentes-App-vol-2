import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../providers/app_provider.dart';
import '../../../services/e2e_crypto_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/password_normalization.dart';

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
  static const _showAbandonOptionAfterFailures = 2;
  static const _lockoutDuration = Duration(seconds: 30);

  final _passwordController = TextEditingController();
  String? _error;
  bool _submitting = false;
  int _failedAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  bool get _isLockedOut => _lockoutSecondsRemaining > 0;

  bool get _showAbandonHistoryOption =>
      _failedAttempts >= _showAbandonOptionAfterFailures;

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

    final rawPassword = _passwordController.text;
    final normalizedPassword = normalizePassword(rawPassword);
    if (normalizedPassword.isEmpty && rawPassword.isEmpty) {
      setState(() => _error = 'Podaj hasło');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final app = context.read<AppProvider>();
      // Prefer normalized (matches login/register hashes + new envelopes).
      try {
        await app.unlockE2eWithPassword(
          normalizedPassword.isEmpty ? rawPassword : normalizedPassword,
        );
      } on InvalidPasswordException {
        // Legacy envelopes created from raw text after an unnormalized change-password.
        if (rawPassword != normalizedPassword && rawPassword.isNotEmpty) {
          await app.unlockE2eWithPassword(rawPassword);
        } else {
          rethrow;
        }
      }
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

  Future<void> _onAbandonHistoryTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Załóż nowe klucze czatu')),
        content: Text(
          dialogContext.tr(
            'Jeśli kontynuujesz, stracisz dostęp do historii tej rozmowy na tym urządzeniu. Druga strona rozmowy zachowa swoją kopię. Tej operacji nie można cofnąć.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Anuluj')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(dialogContext.tr('Załóż nowe klucze')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _promptCurrentPasswordAndReplaceKeys();
  }

  Future<void> _promptCurrentPasswordAndReplaceKeys() async {
    final passwordController = TextEditingController();
    String? dialogError;
    var submitting = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Potwierdź aktualne hasło')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      'Podaj hasło, którym logujesz się do aplikacji (nie stare hasło sprzed resetu).',
                    ),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    enabled: !submitting,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Aktualne hasło'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Anuluj')),
                ),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final normalized =
                              normalizePassword(passwordController.text);
                          if (normalized.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Podaj aktualne hasło.';
                            });
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            dialogError = null;
                          });
                          final app = context.read<AppProvider>();
                          final success =
                              await app.setupFreshE2eKeysAbandoningHistory(
                            normalized,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (success) {
                            Navigator.pop(dialogContext, true);
                            return;
                          }
                          setDialogState(() {
                            submitting = false;
                            dialogError = app.authError ??
                                'Nie udało się założyć nowych kluczy czatu.';
                          });
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Załóż nowe klucze')),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (ok != true || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Nowe klucze czatu założone. Możesz teraz korzystać z czatu.',
          ),
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
    Navigator.pop(context, true);
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
          if (_showAbandonHistoryOption) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _submitting ? null : _onAbandonHistoryTapped,
                child: Text(
                  context.tr(
                    'Nie pamiętasz starego hasła? Załóż nowe klucze czatu',
                  ),
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
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
