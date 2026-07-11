import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../config/country_profiles.dart';
import '../../../../config/legal_config.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../screens/auth/child_onboarding_sheet.dart';
import '../../../screens/settings/privacy_consents_section.dart';

import 'edit_profile_sheet.dart';
import 'change_password_sheet.dart';
import 'email_invite_sheet.dart';
import 'section_header.dart';
import 'settings_card.dart';
import 'settings_divider.dart';
import 'info_tile.dart';
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';

class ChangePinSheet extends StatefulWidget {
  final Color color;
  final bool hasExistingPin;

  const ChangePinSheet({
    required this.color,
    required this.hasExistingPin,
  });

  @override
  State<ChangePinSheet> createState() => ChangePinSheetState();
}

class ChangePinSheetState extends State<ChangePinSheet> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });

    final error = await context.read<AppProvider>().changePin(
          currentPin: widget.hasExistingPin
              ? _currentPinController.text.trim()
              : null,
          newPin: _newPinController.text.trim(),
          confirmPin: _confirmPinController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN został zmieniony ✓'),
        backgroundColor: AppTheme.successColor,
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
            widget.hasExistingPin ? 'Zmień PIN' : 'Ustaw PIN',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wpisz 4-cyfrowy PIN logowania',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.hasExistingPin) ...[
            TextFormField(
              controller: _currentPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Aktualny PIN',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _newPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nowy PIN',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Powtórz nowy PIN',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: widget.color),
              child: Text(
                _saving ? 'Zapisywanie…' : 'Zapisz PIN',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
