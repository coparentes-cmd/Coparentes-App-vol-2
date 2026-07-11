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
import 'section_header.dart';
import 'settings_card.dart';
import 'settings_divider.dart';
import 'info_tile.dart';
import 'action_tile.dart';
import 'switch_tile.dart';
import 'setup_pin_sheet.dart';
import 'change_pin_sheet.dart';

class EmailInviteSheet extends StatefulWidget {
  final Color color;

  const EmailInviteSheet({required this.color});

  @override
  State<EmailInviteSheet> createState() => EmailInviteSheetState();
}

class EmailInviteSheetState extends State<EmailInviteSheet> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  List<EmailInvite> _invites = const [];
  bool _loadingInvites = true;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final invites = await context.read<AppProvider>().getSentEmailInvites();
      if (mounted) {
        setState(() {
          _invites = invites;
          _loadingInvites = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingInvites = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
            'Zaproś partnera e-mailem',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wyślemy link akceptacji na podany adres. Partner musi mieć konto Coparentes, aby zaakceptować zaproszenie.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail partnera',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) return;

                      setState(() => _submitting = true);
                      final ap = context.read<AppProvider>();
                      final ok = await ap.sendEmailInvite(email);
                      if (!context.mounted) return;
                      setState(() => _submitting = false);

                      if (ok) {
                        _emailController.clear();
                        await _loadInvites();
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Zaproszenie wysłane ✓'
                                : (ap.authError ?? 'Nie udało się wysłać zaproszenia.'),
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
                  : const Text('Wyślij zaproszenie',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ostatnie zaproszenia',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_loadingInvites)
            const Center(child: CircularProgressIndicator())
          else if (_invites.isEmpty)
            const Text(
              'Brak wysłanych zaproszeń.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            )
          else
            ..._invites.take(5).map(
                  (invite) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline, size: 20),
                    title: Text(invite.email, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      invite.status,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
