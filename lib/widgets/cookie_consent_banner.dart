import 'dart:ui';

import 'package:coparentes/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cookie_consent/cookie_consent_controller.dart';
import '../utils/open_url.dart';

/// Blocking cookie popup — no interaction with the app until a choice is saved.
class CookieConsentBanner extends StatelessWidget {
  const CookieConsentBanner({super.key});

  static const _privacyUrl = 'https://coparentes.ai/polityka-prywatnosci/';
  static const _termsUrl = 'https://coparentes.ai/regulamin/';
  static const _emerald = Color(0xFF00C896);
  static const _electric = Color(0xFF0080FF);
  static const _coral = Color(0xFFFF6B68);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF5B6470);
  static const _linkBlue = Color(0xFF0A5ECB);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CookieConsentController>();
    if (!controller.ready || !controller.bannerVisible) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;

    // Same card chrome on mobile + desktop (collapsed = settings hidden).
    return Positioned.fill(
      child: Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: context.tr('Szanujemy Twoją prywatność'),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Hard block: swallow all taps / scroll behind the dialog.
              const ModalBarrier(
                dismissible: false,
                color: Color(0x99001932),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 560,
                        maxHeight:
                            size.height - topInset - bottomInset - 32,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xF7FFFFFF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0x14111111)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4D001932),
                                  blurRadius: 40,
                                  offset: Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: SizedBox(
                                    height: 4,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _emerald,
                                            _electric,
                                            _coral,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    14,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        context.tr(
                                          'Szanujemy Twoją prywatność',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                context.tr(
                                                  'Używamy niezbędnych plików cookies, aby strona działała prawidłowo. Za Twoją zgodą możemy włączyć także cookies funkcjonalne, analityczne i marketingowe. Szczegóły znajdziesz w Polityce prywatności i cookies oraz Regulaminie.',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.45,
                                                  color: _muted,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 6,
                                                children: [
                                                  _TextLink(
                                                    label: context.tr(
                                                      'Polityka prywatności',
                                                    ),
                                                    onTap: () =>
                                                        openExternalUrl(
                                                      _privacyUrl,
                                                    ),
                                                  ),
                                                  _TextLink(
                                                    label: context.tr(
                                                      'Regulamin',
                                                    ),
                                                    onTap: () =>
                                                        openExternalUrl(
                                                      _termsUrl,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (controller
                                                  .settingsExpanded) ...[
                                                const SizedBox(height: 12),
                                                const Divider(
                                                  height: 1,
                                                  color: Color(0x14111111),
                                                ),
                                                const SizedBox(height: 12),
                                                _CategoryCard(
                                                  title: context.tr(
                                                    'Niezbędne',
                                                  ),
                                                  body: context.tr(
                                                    'Zapewniają podstawowe działanie strony, bezpieczeństwo oraz zapis Twoich preferencji cookies.',
                                                  ),
                                                  trailing:
                                                      const _AlwaysOnBadge(),
                                                ),
                                                const SizedBox(height: 8),
                                                _CategoryCard(
                                                  title: context.tr(
                                                    'Funkcjonalne',
                                                  ),
                                                  body: context.tr(
                                                    'Pozwalają zapamiętać ustawienia i ułatwiają korzystanie ze strony.',
                                                  ),
                                                  trailing: Switch.adaptive(
                                                    value: controller
                                                        .draftFunctional,
                                                    activeThumbColor: _emerald,
                                                    onChanged: controller
                                                        .setDraftFunctional,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                _CategoryCard(
                                                  title: context.tr(
                                                    'Analityczne',
                                                  ),
                                                  body: context.tr(
                                                    'Pomagają mierzyć ruch i ulepszać stronę na podstawie statystyk odwiedzin.',
                                                  ),
                                                  trailing: Switch.adaptive(
                                                    value: controller
                                                        .draftAnalytics,
                                                    activeThumbColor: _emerald,
                                                    onChanged: controller
                                                        .setDraftAnalytics,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                _CategoryCard(
                                                  title: context.tr(
                                                    'Marketingowe',
                                                  ),
                                                  body: context.tr(
                                                    'Mogą służyć do dopasowania treści promocyjnych i mierzenia skuteczności kampanii.',
                                                  ),
                                                  trailing: Switch.adaptive(
                                                    value: controller
                                                        .draftMarketing,
                                                    activeThumbColor: _emerald,
                                                    onChanged: controller
                                                        .setDraftMarketing,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _ActionRow(
                                        expanded: controller.settingsExpanded,
                                        onAcceptAll: controller.acceptAll,
                                        onRejectOptional:
                                            controller.rejectOptional,
                                        onOpenSettings:
                                            controller.expandSettings,
                                        onSave: controller.saveSelection,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _ActionRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onAcceptAll;
  final VoidCallback onRejectOptional;
  final VoidCallback onOpenSettings;
  final VoidCallback onSave;

  const _ActionRow({
    required this.expanded,
    required this.onAcceptAll,
    required this.onRejectOptional,
    required this.onOpenSettings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    // Same horizontal row on mobile + desktop (1:1 with desktop collapsed).
    return Row(
      children: [
        Expanded(
          child: _CookieButton(
            label: context.tr('Akceptuj'),
            style: _CookieButtonStyle.primary,
            onPressed: onAcceptAll,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CookieButton(
            label: context.tr('Odrzuć'),
            style: _CookieButtonStyle.outline,
            onPressed: onRejectOptional,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: expanded
              ? _CookieButton(
                  label: context.tr('Zapisz wybór'),
                  style: _CookieButtonStyle.primary,
                  onPressed: onSave,
                )
              : _CookieButton(
                  label: context.tr('Ustawienia'),
                  style: _CookieButtonStyle.ghost,
                  onPressed: onOpenSettings,
                ),
        ),
      ],
    );
  }
}

enum _CookieButtonStyle { primary, outline, ghost }

class _CookieButton extends StatelessWidget {
  final String label;
  final _CookieButtonStyle style;
  final VoidCallback onPressed;

  const _CookieButton({
    required this.label,
    required this.style,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final BorderSide? border;
    switch (style) {
      case _CookieButtonStyle.primary:
        bg = CookieConsentBanner._electric;
        fg = Colors.white;
        border = null;
        break;
      case _CookieButtonStyle.outline:
        bg = Colors.white;
        fg = CookieConsentBanner._ink;
        border = const BorderSide(color: Color(0x1A111111));
        break;
      case _CookieButtonStyle.ghost:
        bg = const Color(0x140080FF);
        fg = CookieConsentBanner._linkBlue;
        border = const BorderSide(color: Color(0x1F0080FF));
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: border == null ? null : Border.fromBorderSide(border),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget trailing;

  const _CategoryCard({
    required this.title,
    required this.body,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEBFFFFFF), Color(0xFAF8FAFF)],
        ),
        border: Border.all(color: const Color(0x0F111111)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: CookieConsentBanner._ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: CookieConsentBanner._muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _AlwaysOnBadge extends StatelessWidget {
  const _AlwaysOnBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x1F00C896),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr('Zawsze aktywne'),
        style: const TextStyle(
          color: Color(0xFF0A9D7A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: CookieConsentBanner._linkBlue,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
