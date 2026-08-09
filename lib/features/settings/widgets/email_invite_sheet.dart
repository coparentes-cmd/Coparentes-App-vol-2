import 'dart:async';

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

  /// Best-effort only — never block the UI on mailto (Safari/web can hang).
  void _tryOpenMailto({
    required String email,
    required String inviteCode,
    required String workspaceName,
  }) {
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
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication).timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      ).catchError((_) => false),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);

    var message = 'Nie udało się wysłać zaproszenia.';
    var success = false;
    final ap = context.read<AppProvider>();

    try {
      final result = await ap.sendEmailInvite(email).timeout(
            const Duration(seconds: 20),
          );

      if (result == null) {
        message = ap.authError ?? message;
        return;
      }

      final code = (result.inviteCode ?? ap.currentWorkspace?.inviteCode ?? '')
          .trim();
      final workspaceName = ap.currentWorkspace?.name ?? 'Coparentes';

      if (result.emailSent) {
        message = 'Wysłane ✓ Zaproszenie z kodem poszło na $email';
        success = true;
        _emailController.clear();
      } else if (code.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: code));
        // Never await mailto — on Safari/Flutter web it can hang forever.
        _tryOpenMailto(
          email: email,
          inviteCode: code,
          workspaceName: workspaceName,
        );
        message =
            'Wysłane ✓ Kod $code skopiowany — wklej go w e-mailu do partnera '
            '(lub wyślij z otwartego klienta poczty).';
        success = true;
        _emailController.clear();
      } else {
        message = 'Zaproszenie zapisane, ale brak kodu do wysłania.';
      }

      await _loadInvites();
    } on TimeoutException {
      message = 'Serwer nie odpowiedział na czas. Spróbuj ponownie.';
    } catch (_) {
      message = ap.authError ?? message;
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? AppTheme.successColor : AppTheme.errorColor,
        duration: const Duration(seconds: 5),
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
            'Wyślemy kod dołączenia na podany adres. Jeśli automatyczna wysyłka nie zadziała, kod trafi do schowka — wklej go w mailu.',
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
                    leading: Icon(
                      _inviteStatusIcon(invite.status),
                      size: 20,
                      color: _inviteStatusColor(invite.status),
                    ),
                    title: Text(
                      invite.email,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      _inviteStatusLabel(invite.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _inviteStatusColor(invite.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

String _inviteStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Wysłane — oczekuje na dołączenie';
    case 'ACCEPTED':
      return 'Zaakceptowane';
    case 'EXPIRED':
      return 'Wygasłe';
    default:
      return status;
  }
}

IconData _inviteStatusIcon(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return Icons.mark_email_read_outlined;
    case 'ACCEPTED':
      return Icons.check_circle_outline;
    case 'EXPIRED':
      return Icons.timer_off_outlined;
    default:
      return Icons.mail_outline;
  }
}

Color _inviteStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return AppTheme.successColor;
    case 'ACCEPTED':
      return AppTheme.primaryTeal;
    case 'EXPIRED':
      return AppTheme.warningColor;
    default:
      return AppTheme.textSecondary;
  }
}
