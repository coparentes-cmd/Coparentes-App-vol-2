import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/password_normalization.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Asks for the parent's password before deleting a child profile.
/// Returns normalized password, or null if cancelled.
Future<String?> showDeleteChildPasswordDialog(
  BuildContext context, {
  required String childName,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _DeleteChildPasswordDialog(childName: childName),
  );
}

class _DeleteChildPasswordDialog extends StatefulWidget {
  final String childName;

  const _DeleteChildPasswordDialog({required this.childName});

  @override
  State<_DeleteChildPasswordDialog> createState() =>
      _DeleteChildPasswordDialogState();
}

class _DeleteChildPasswordDialogState extends State<_DeleteChildPasswordDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final password = normalizePassword(_controller.text);
    if (password.isEmpty) {
      // Avoid context.tr here — Provider.listen during onPressed asserts in tests.
      setState(() => _error = 'Wpisz hasło');
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Usuń profil dziecka')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usuniesz profil „${widget.childName}” i powiązane konto logowania, jeśli istnieje. Tej operacji nie da się cofnąć.',
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Wpisz hasło, aby potwierdzić usunięcie.'),
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('delete_child_password_field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr('Hasło'),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Anuluj')),
        ),
        ElevatedButton(
          key: const Key('delete_child_confirm_button'),
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
          ),
          child: Text(
            context.tr('Usuń'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
