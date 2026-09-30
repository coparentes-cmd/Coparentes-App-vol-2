import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';

/// Full-screen form opened from a password-reset e-mail link.
class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final VoidCallback onDone;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.onDone,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validated = validateAndNormalizeNewPassword(
      rawNew: _newController.text,
      rawConfirm: _confirmController.text,
    );
    if (validated.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(validated.errorMessage!))),
      );
      return;
    }

    setState(() => _submitting = true);
    final ap = context.read<AppProvider>();
    final ok = await ap.confirmPasswordReset(
      token: widget.token,
      newPassword: validated.normalizedNew!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ap.authError ?? context.tr('Nie udało się zmienić hasła.'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Backend wiped sessions; clear any local session so _AppGate shows login.
    ap.logout();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.tr('Hasło zostało zmienione. Zaloguj się nowym hasłem.'),
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 6),
      ),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Ustaw nowe hasło'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Wybierz nowe hasło do konta Coparentes. Po zapisaniu zalogujesz się nim na ekranie logowania.',
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _newController,
                obscureText: true,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: context.tr('Nowe hasło'),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                enabled: !_submitting,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) {
                  if (!_submitting) {
                    _submit();
                  }
                },
                decoration: InputDecoration(
                  labelText: context.tr('Powtórz nowe hasło'),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: color),
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
                          context.tr('Ustaw nowe hasło'),
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : widget.onDone,
                  child: Text(context.tr('Wróć do logowania')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
