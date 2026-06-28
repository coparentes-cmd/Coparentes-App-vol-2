import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/consent_config.dart';
import '../data/models/user_consent.dart';
import '../theme/app_theme.dart';
import '../utils/open_url.dart';

class ConsentRow extends StatefulWidget {
  final ConsentDefinition definition;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showRequiredBadge;
  final String? statusLabel;

  const ConsentRow({
    super.key,
    required this.definition,
    required this.value,
    this.onChanged,
    this.showRequiredBadge = true,
    this.statusLabel,
  });

  @override
  State<ConsentRow> createState() => _ConsentRowState();
}

class _ConsentRowState extends State<ConsentRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final isLocked = widget.onChanged == null;
    final switchWidget = Switch(
      value: widget.value,
      onChanged: widget.onChanged,
      activeColor: AppTheme.primaryTeal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: isLocked
                ? Tooltip(
                    message: 'Ta zgoda jest wymagana do korzystania z aplikacji',
                    child: Opacity(opacity: 0.45, child: switchWidget),
                  )
                : switchWidget,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (widget.showRequiredBadge && definition.type.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Wymagana',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Zwiń' : 'Czytaj więcej',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  ...definition.expandBlocks.map(_buildExpandBlock),
                ],
                if (widget.statusLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.statusLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandBlock(ConsentExpandBlock block) {
    if (block.linkUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => openExternalUrl(block.linkUrl!),
          child: Text(
            block.linkLabel ?? block.linkUrl!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        block.text ?? '',
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

String formatConsentStatusLabel(UserConsentRecord record) {
  final formatter = DateFormat('dd.MM.yyyy');
  if (record.granted && record.grantedAt != null) {
    return 'Zaakceptowano: ${formatter.format(record.grantedAt!.toLocal())}';
  }
  if (!record.granted && record.revokedAt != null) {
    return 'Wycofano: ${formatter.format(record.revokedAt!.toLocal())}';
  }
  if (!record.granted && record.grantedAt != null) {
    return 'Wycofano: ${formatter.format(record.grantedAt!.toLocal())}';
  }
  return '';
}

ConsentDefinition? consentDefinitionFor(ConsentType type) {
  for (final definition in ConsentConfig.registrationConsents) {
    if (definition.type == type) {
      return definition;
    }
  }
  return null;
}
