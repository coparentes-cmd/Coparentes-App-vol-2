import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';

/// Full-screen, non-dismissible gate after login with a temporary password.
class MustChangePasswordScreen extends StatefulWidget {
  const MustChangePasswordScreen({super.key});

  @override
  State<MustChangePasswordScreen> createState() =>
      _MustChangePasswordScreenState();
}

class _MustChangePasswordScreenState extends State<MustChangePasswordScreen> {
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
    final ok = await ap.completeForcedPasswordChange(
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
    }
    // On success AppProvider re-logins with mustChangePassword: false →
    // `_AppGate` rebuilds to the normal dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

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
                  context.tr('Ustaw nowe hasło'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Zalogowano tymczasowym hasłem. Ustaw nowe hasło, aby kontynuować.',
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
                            context.tr('Zapisz hasło'),
                            style: const TextStyle(color: Colors.white),
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
