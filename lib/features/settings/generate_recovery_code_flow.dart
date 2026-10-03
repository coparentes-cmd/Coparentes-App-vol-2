import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../services/e2e_crypto_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';
import 'widgets/recovery_code_sheet.dart';

/// Shared Settings / onboarding-tour flow: unlock if needed, generate code,
/// show [RecoveryCodeSheet]. Returns true when a code sheet was shown and closed.
Future<bool> runGenerateRecoveryCodeFlow(
  BuildContext context, {
  required Color color,
}) async {
  final ap = context.read<AppProvider>();

  var outcome = await ap.generateE2eRecoveryCode();

  if (!context.mounted) return false;

  if (outcome.result == GenerateRecoveryCodeResult.needsUnlock) {
    final unlocked = await promptPasswordAndUnlockE2e(context);
    if (!context.mounted) return false;
    if (!unlocked) return false;
    outcome = await ap.generateE2eRecoveryCode();
    if (!context.mounted) return false;
  }

  switch (outcome.result) {
    case GenerateRecoveryCodeResult.needsUnlock:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Odblokuj szyfrowanie czatu, żeby wygenerować kod.'),
          ),
        ),
      );
      return false;
    case GenerateRecoveryCodeResult.error:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ap.authError ??
                context.tr('Nie udało się wygenerować kodu odzyskiwania.'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return false;
    case GenerateRecoveryCodeResult.success:
      final code = outcome.code;
      if (code == null || code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Nie udało się wygenerować kodu odzyskiwania.'),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return false;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => RecoveryCodeSheet(code: code, color: color),
      );
      return true;
  }
}

/// Returns true if E2E was unlocked successfully.
Future<bool> promptPasswordAndUnlockE2e(BuildContext context) async {
  final passwordController = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var submitting = false;
      String? dialogError;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(context.tr('Odblokuj szyfrowanie czatu')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Podaj aktualne hasło, żeby wygenerować kod odzyskiwania.',
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
                    errorText:
                        dialogError == null ? null : context.tr(dialogError!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext, false),
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
                        try {
                          await app.unlockE2eWithPassword(normalized);
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, true);
                        } on InvalidPasswordException {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            submitting = false;
                            dialogError = 'Nieprawidłowe hasło';
                            passwordController.clear();
                          });
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            submitting = false;
                            dialogError =
                                'Nie udało się odblokować wiadomości. Spróbuj ponownie.';
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Odblokuj')),
              ),
            ],
          );
        },
      );
    },
  );
  passwordController.dispose();
  return ok == true;
}
