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
import 'email_invite_sheet.dart';
import 'section_header.dart';
import 'settings_card.dart';
import 'settings_divider.dart';
import 'info_tile.dart';
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

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
          const Text(
            'Zmień hasło',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Aktualne hasło',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nowe hasło',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Powtórz nowe hasło',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      if (_newController.text.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nowe hasło musi mieć co najmniej 10 znaków.'),
                          ),
                        );
                        return;
                      }
                      if (_newController.text != _confirmController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hasła nie są identyczne.')),
                        );
                        return;
                      }

                      setState(() => _submitting = true);
                      final ap = context.read<AppProvider>();
                      final ok = await ap.changePassword(
                        currentPassword: _currentController.text,
                        newPassword: _newController.text,
                      );
                      if (!context.mounted) return;
                      setState(() => _submitting = false);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Hasło zostało zmienione ✓'
                                : (ap.authError ?? 'Nie udało się zmienić hasła.'),
                          ),
                          backgroundColor:
                              ok ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      );
                    },
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
                  : const Text('Zapisz hasło', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
