import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/user_consent.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/consent_widgets.dart';

class PrivacyConsentsSection extends StatefulWidget {
  final Color roleColor;
  final bool isDark;

  const PrivacyConsentsSection({
    super.key,
    required this.roleColor,
    required this.isDark,
  });

  @override
  State<PrivacyConsentsSection> createState() => _PrivacyConsentsSectionState();
}

class _PrivacyConsentsSectionState extends State<PrivacyConsentsSection> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final appProvider = context.read<AppProvider>();
    final ok = await appProvider.loadUserConsents();

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      if (!ok) {
        _error = appProvider.authError ?? 'Nie udało się pobrać zgód.';
      }
    });
  }

  Future<void> _toggleConsent(ConsentType type, bool granted) async {
    final appProvider = context.read<AppProvider>();
    final ok = await appProvider.updateUserConsent(type: type, granted: granted);

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appProvider.authError ?? 'Nie udało się zaktualizować zgody.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final consents = appProvider.userConsents;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _error!,
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadConsents, child: const Text('Spróbuj ponownie')),
          ],
        ),
      );
    }

    if (consents == null || consents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var i = 0; i < consents.length; i++) ...[
          _ConsentSettingsRow(
            record: consents[i],
            isDark: widget.isDark,
            onChanged: consents[i].required
                ? null
                : (value) => _toggleConsent(consents[i].type, value),
          ),
          if (i < consents.length - 1)
            Divider(
              color: widget.isDark ? Colors.white12 : AppTheme.dividerColor,
              height: 1,
            ),
        ],
      ],
    );
  }
}

class _ConsentSettingsRow extends StatelessWidget {
  final UserConsentRecord record;
  final bool isDark;
  final ValueChanged<bool>? onChanged;

  const _ConsentSettingsRow({
    required this.record,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final definition = consentDefinitionFor(record.type);
    if (definition == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ConsentRow(
        definition: definition,
        value: record.granted,
        onChanged: onChanged,
        showRequiredBadge: record.required,
        statusLabel: formatConsentStatusLabel(record),
      ),
    );
  }
}
