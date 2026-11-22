import 'package:flutter/material.dart';

import '../config/consent_config.dart';
import '../data/models/user_consent.dart';
import '../theme/app_theme.dart';
import '../utils/open_url.dart';
import 'mobile_onboarding_chrome.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Mobile registration consents: 3 action tiles + checkbox list (6 consents).
class RegistrationConsentPanel extends StatelessWidget {
  final Map<ConsentType, bool> selections;
  final ValueChanged<Map<ConsentType, bool>> onChanged;
  final bool settingsExpanded;
  final VoidCallback onExpandSettings;
  final List<ConsentDefinition>? consents;

  const RegistrationConsentPanel({
    super.key,
    required this.selections,
    required this.onChanged,
    required this.settingsExpanded,
    required this.onExpandSettings,
    this.consents,
  });

  List<ConsentDefinition> get _defs =>
      consents ?? ConsentConfig.registrationConsents;

  void _acceptAll() {
    onChanged({
      for (final type in ConsentType.values) type: true,
    });
  }

  void _rejectOptional() {
    onChanged({
      for (final type in ConsentType.values) type: type.isRequired,
    });
  }

  void _toggle(ConsentType type, bool value) {
    final next = Map<ConsentType, bool>.from(selections);
    next[type] = value;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ConsentTile(
                label: context.tr('Akceptuj wszystkie'),
                filled: true,
                onTap: _acceptAll,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConsentTile(
                label: context.tr('Odrzuć opcjonalne'),
                onTap: _rejectOptional,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConsentTile(
                label: context.tr('Ustawienia zgód'),
                onTap: onExpandSettings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (settingsExpanded)
          ..._defs.map((definition) {
            final value = selections[definition.type] ?? false;
            return _ConsentCheckboxRow(
              definition: definition,
              value: value,
              onChanged: (v) => _toggle(definition.type, v),
            );
          }),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ConsentTile({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? MobileOnboarding.blue : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled ? MobileOnboarding.blue : const Color(0xFFD7DEE8),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: filled ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCheckboxRow extends StatelessWidget {
  final ConsentDefinition definition;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConsentCheckboxRow({
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final required = definition.type.isRequired;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: MobileOnboarding.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.tr(definition.title),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: required
                            ? AppTheme.errorColor.withValues(alpha: 0.12)
                            : MobileOnboarding.greenSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.tr(required ? 'Wymagane' : 'Opcjonalne'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: required
                              ? AppTheme.errorColor
                              : MobileOnboarding.greenFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(definition.description),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
                ...definition.expandBlocks.where((b) => b.linkUrl != null).map(
                  (block) {
                    return TextButton(
                      onPressed: () => openExternalUrl(block.linkUrl!),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                        foregroundColor: MobileOnboarding.blue,
                      ),
                      child: Text(
                        context.tr(block.linkLabel ?? 'Czytaj więcej'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
