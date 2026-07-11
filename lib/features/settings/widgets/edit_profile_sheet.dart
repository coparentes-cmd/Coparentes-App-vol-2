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

import 'change_password_sheet.dart';
import 'email_invite_sheet.dart';
import 'section_header.dart';
import 'settings_card.dart';
import 'settings_divider.dart';
import 'info_tile.dart';
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

class EditProfileSheet extends StatefulWidget {
  final AppUser? user;
  final Color color;

  const EditProfileSheet({required this.user, required this.color});

  @override
  State<EditProfileSheet> createState() => EditProfileSheetState();
}

class EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
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
            'Edytuj profil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Imię i nazwisko',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: false,
            controller: TextEditingController(text: widget.user?.email ?? ''),
            decoration: const InputDecoration(
              labelText: 'Adres e-mail (tylko odczyt)',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      setState(() => _submitting = true);
                      final ok = await context.read<AppProvider>().updateProfile(
                            name: _nameController.text.trim(),
                          );
                      if (!context.mounted) return;
                      setState(() => _submitting = false);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Profil zaktualizowany ✓' : 'Nie udało się zapisać profilu.',
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
                  : const Text('Zapisz zmiany', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
