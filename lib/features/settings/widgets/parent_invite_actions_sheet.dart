import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:coparentes/l10n/app_strings.dart';

enum ParentInviteAction { copy, sendEmail }

/// Choice sheet after tapping parent invite code: copy or send by e-mail.
class ParentInviteActionsSheet extends StatelessWidget {
  final String inviteCode;
  final Color color;

  const ParentInviteActionsSheet({
    super.key,
    required this.inviteCode,
    required this.color,
  });

  static Future<ParentInviteAction?> show(
    BuildContext context, {
    required String inviteCode,
    required Color color,
  }) {
    return showModalBottomSheet<ParentInviteAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ParentInviteActionsSheet(
        inviteCode: inviteCode,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Kod zaproszenia dla drugiego rodzica'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                inviteCode,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('parent_invite_copy'),
                  onPressed: () =>
                      Navigator.of(context).pop(ParentInviteAction.copy),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(
                    context.tr('Skopiuj'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('parent_invite_send_email'),
                  onPressed: () =>
                      Navigator.of(context).pop(ParentInviteAction.sendEmail),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    context.tr('Wyślij kod e-mailem'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> copyParentInviteCode(
  BuildContext context, {
  required String inviteCode,
  required Color color,
}) async {
  await Clipboard.setData(ClipboardData(text: inviteCode));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Kod zaproszenia skopiowany: $inviteCode'),
      backgroundColor: color,
    ),
  );
}
