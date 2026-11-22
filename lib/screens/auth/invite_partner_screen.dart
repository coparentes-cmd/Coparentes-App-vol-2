import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_config.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';
import 'post_register_add_child_screen.dart';

/// Mobile-only: after register, invite second parent (same invite code as Settings).
class InvitePartnerScreen extends StatefulWidget {
  const InvitePartnerScreen({super.key});

  @override
  State<InvitePartnerScreen> createState() => _InvitePartnerScreenState();
}

class _InvitePartnerScreenState extends State<InvitePartnerScreen> {
  bool _sharedOrCopied = false;

  String? get _code =>
      context.read<AppProvider>().currentWorkspace?.inviteCode;

  String _shareBody(String code) {
    return 'Zapraszam Cię do Coparentes, żebyśmy mieli wspólny kalendarz i czat '
        'w sprawach dziecka. Kod: $code. W aplikacji lub w przeglądarce na '
        '${LegalConfig.websiteUrl.replaceFirst(RegExp(r'^https?://'), '')} '
        'wybierz „Dołączanie”, a potem „Dorosły”.';
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _sharedOrCopied = true);
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(content: Text(context.tr('Skopiowano'))),
    );
  }

  Future<void> _send() async {
    final code = _code;
    if (code == null || code.isEmpty) {
      return;
    }
    final bodyText = _shareBody(code);
    await Clipboard.setData(ClipboardData(text: bodyText));
    final subject = Uri.encodeComponent('Zaproszenie do Coparentes');
    final body = Uri.encodeComponent(bodyText);
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication)
          .timeout(const Duration(seconds: 2), onTimeout: () => false)
          .catchError((_) => false),
    );
    if (!mounted) return;
    setState(() => _sharedOrCopied = true);
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Tekst z kodem skopiowany. Otwórz e-mail lub wklej go w wiadomości.',
          ),
        ),
      ),
    );
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const PostRegisterAddChildScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<AppProvider>().currentWorkspace?.inviteCode;
    final hasCode = code != null && code.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _continue();
        }
      },
      child: Scaffold(
        body: BrandBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(width: 140, height: 46),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('Zaproś drugiego rodzica'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Wspólny kalendarz i czat działają, gdy oboje jesteście w przestrzeni.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 28),
                  BrandCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        if (!hasCode) ...[
                          Text(
                            context.tr(
                              'Nie udało się pobrać kodu. Znajdziesz go też w Ustawieniach.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ] else ...[
                          SelectableText(
                            code,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _copy,
                                  child: Text(context.tr('Kopiuj kod')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _send,
                                  child: Text(context.tr('Wyślij')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _continue,
                      child: Text(
                        context.tr(
                          _sharedOrCopied ? 'Gotowe' : 'Zrobię to później',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
