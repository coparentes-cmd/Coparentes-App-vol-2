import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/password_normalization.dart';

class ChangePasswordSheet extends StatefulWidget {
  final Color color;

  const ChangePasswordSheet({required this.color});

  @override
  State<ChangePasswordSheet> createState() => ChangePasswordSheetState();
}

class ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = normalizePassword(_currentController.text);
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
    final ok = await ap.changePassword(
      currentPassword: currentPassword,
      newPassword: validated.normalizedNew!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('Hasło zostało zmienione ✓')
              : (ap.authError ?? context.tr('Nie udało się zmienić hasła.')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            context.tr('Zmień hasło'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('Aktualne hasło'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('Nowe hasło'),
              prefixIcon: const Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('Powtórz nowe hasło'),
              prefixIcon: const Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: widget.color),
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
    );
  }
}
