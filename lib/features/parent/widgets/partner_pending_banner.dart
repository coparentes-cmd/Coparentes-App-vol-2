import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/legal_config.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/client_platform.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

/// Mobile-only home card while only one adult is in the workspace.
class PartnerPendingBanner extends StatefulWidget {
  const PartnerPendingBanner({super.key});

  @override
  State<PartnerPendingBanner> createState() => _PartnerPendingBannerState();
}

class _PartnerPendingBannerState extends State<PartnerPendingBanner> {
  bool _collapsed = false;
  bool _loaded = false;

  static String _prefsKey(String workspaceId) =>
      'partner_invite_banner_collapsed_$workspaceId';

  Future<void> _load(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _collapsed = prefs.getBool(_prefsKey(workspaceId)) ?? false;
      _loaded = true;
    });
  }

  Future<void> _setCollapsed(String workspaceId, bool value) async {
    setState(() => _collapsed = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(workspaceId), value);
  }

  int _adultCount(Workspace? ws) {
    if (ws == null) return 0;
    return ws.members
        .where(
          (m) => m.role == UserRole.parentA || m.role == UserRole.parentB,
        )
        .length;
  }

  String _shareBody(String code) {
    return 'Zapraszam Cię do Coparentes, żebyśmy mieli wspólny kalendarz i czat '
        'w sprawach dziecka. Kod: $code. W aplikacji lub w przeglądarce na '
        '${LegalConfig.websiteUrl.replaceFirst(RegExp(r'^https?://'), '')} '
        'wybierz „Dołączanie”, a potem „Dorosły”.';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !isMobileClientPlatform) {
      return const SizedBox.shrink();
    }

    final ap = context.watch<AppProvider>();
    final user = ap.currentUser;
    final ws = ap.currentWorkspace;
    if (user == null ||
        ws == null ||
        (user.role != UserRole.parentA && user.role != UserRole.parentB)) {
      return const SizedBox.shrink();
    }
    if (_adultCount(ws) != 1) {
      return const SizedBox.shrink();
    }

    final code = ws.inviteCode;
    if (!_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load(ws.id);
      });
      return const SizedBox.shrink();
    }

    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Material(
          color: AppTheme.primaryTeal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _setCollapsed(ws.id, false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Zaproś drugiego rodzica'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppTheme.primaryDark),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Drugi rodzic jeszcze nie dołączył'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _setCollapsed(ws.id, true),
                    child: Text(context.tr('Zwiń')),
                  ),
                ],
              ),
              if (code != null && code.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showTopSnackBar(
                            SnackBar(
                              content: Text(context.tr('Skopiowano')),
                            ),
                          );
                        },
                        child: Text(context.tr('Kopiuj')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final bodyText = _shareBody(code);
                          await Clipboard.setData(
                            ClipboardData(text: bodyText),
                          );
                          final subject =
                              Uri.encodeComponent('Zaproszenie do Coparentes');
                          final body = Uri.encodeComponent(bodyText);
                          final uri = Uri.parse(
                            'mailto:?subject=$subject&body=$body',
                          );
                          unawaited(
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            )
                                .timeout(
                                  const Duration(seconds: 2),
                                  onTimeout: () => false,
                                )
                                .catchError((_) => false),
                          );
                        },
                        child: Text(context.tr('Wyślij')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
