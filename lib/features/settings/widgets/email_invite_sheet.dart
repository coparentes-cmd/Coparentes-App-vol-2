import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../theme/app_theme.dart';

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

  Future<bool> _openMailtoFallback({
    required String email,
    required String inviteCode,
    required String workspaceName,
  }) async {
    final subject = Uri.encodeComponent('Zaproszenie do Coparentes');
    final body = Uri.encodeComponent(
      'Cześć!\n\n'
      'Zapraszam Cię do wspólnej przestrzeni „$workspaceName” w Coparentes.\n\n'
      'Kod dołączenia: $inviteCode\n\n'
      '1. Otwórz https://getcoparentes.app\n'
      '2. Wybierz zakładkę Dołączanie\n'
      '3. Wpisz kod i załóż konto\n\n'
      'Do zobaczenia w aplikacji!',
    );
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    return launchUrl(uri);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return;
    }

    setState(() => _submitting = true);
    final ap = context.read<AppProvider>();
    final result = await ap.sendEmailInvite(email);
    if (!mounted) {
      return;
    }

    var ok = result != null;
    var message = ap.authError ?? 'Nie udało się wysłać zaproszenia.';
    var successColor = false;

    if (result != null) {
      final code = result.inviteCode ??
          ap.currentWorkspace?.inviteCode ??
          '';
      final workspaceName =
          ap.currentWorkspace?.name ?? 'Coparentes';

      if (result.emailSent) {
        message = 'Zaproszenie z kodem wysłane na $email ✓';
        successColor = true;
        _emailController.clear();
        await _loadInvites();
      } else if (code.isNotEmpty) {
        final launched = await _openMailtoFallback(
          email: email,
          inviteCode: code,
          workspaceName: workspaceName,
        );
        await Clipboard.setData(ClipboardData(text: code));
        if (!mounted) {
          return;
        }
        if (launched) {
          message =
              'Otworzono e-mail z kodem $code. Wyślij wiadomość z klienta poczty.';
          successColor = true;
          _emailController.clear();
          await _loadInvites();
        } else {
          message =
              'Serwer e-mail niedostępny. Kod $code skopiowany do schowka — wyślij go partnerowi.';
          successColor = true;
          ok = true;
          _emailController.clear();
          await _loadInvites();
        }
      } else {
        message = 'Zaproszenie zapisane, ale nie udało się wysłać e-maila.';
        ok = false;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            successColor || ok ? AppTheme.successColor : AppTheme.errorColor,
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
          const Text(
            'Zaproś partnera e-mailem',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wyślemy kod dołączenia na podany adres. Partner wybiera Dołączanie w aplikacji i wpisuje kod.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!_submitting) {
                _submit();
              }
            },
            decoration: const InputDecoration(
              labelText: 'E-mail partnera',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
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
                  : const Text(
                      'Wyślij zaproszenie',
                      style: TextStyle(color: Colors.white),
                    ),
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
                    title:
                        Text(invite.email, style: const TextStyle(fontSize: 14)),
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
