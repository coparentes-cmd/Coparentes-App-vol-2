import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/consent_config.dart';
import '../../data/models/user_consent.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_utils.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/consent_widgets.dart';

class RegistrationDraft {
  final String name;
  final String email;
  final String password;
  final String workspaceName;

  const RegistrationDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.workspaceName,
  });
}

class ConsentRegistrationScreen extends StatefulWidget {
  final RegistrationDraft draft;

  const ConsentRegistrationScreen({
    super.key,
    required this.draft,
  });

  @override
  State<ConsentRegistrationScreen> createState() =>
      _ConsentRegistrationScreenState();
}

class _ConsentRegistrationScreenState extends State<ConsentRegistrationScreen> {
  late Map<ConsentType, bool> _selections;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selections = defaultConsentSelections();
  }

  bool get _canSubmit => areRequiredConsentsGranted(_selections);

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) {
      return;
    }

    setState(() => _submitting = true);

    final appProvider = context.read<AppProvider>();
    final success = await appProvider.registerWorkspace(
      name: widget.draft.name,
      email: widget.draft.email,
      password: widget.draft.password,
      workspaceName: widget.draft.workspaceName,
      consents: _selections,
    );

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appProvider.authError ?? 'Nie udało się zakończyć rejestracji.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LayoutTokens.authConsentMax,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: BrandCard(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: BrandLogo(width: 168, height: 54)),
                      const SizedBox(height: 24),
                      Text(
                        'Zanim zaczniesz',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Przeczytaj i zaakceptuj poniższe zgody. Niektóre są wymagane do działania aplikacji.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 18),
                      ...ConsentConfig.registrationConsents.map((definition) {
                        return Column(
                          children: [
                            ConsentRow(
                              definition: definition,
                              value: _selections[definition.type] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _selections[definition.type] = value;
                                });
                              },
                            ),
                            if (definition != ConsentConfig.registrationConsents.last)
                              const Divider(color: AppTheme.dividerColor, height: 1),
                          ],
                        );
                      }),
                      const SizedBox(height: 18),
                      const Text(
                        'Możesz wycofać zgody opcjonalne w dowolnym momencie w Ustawieniach → Prywatność.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _canSubmit ? AppTheme.brandGradient : null,
                            color: _canSubmit ? null : AppTheme.dividerColor,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: _canSubmit ? AppTheme.softShadow : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _canSubmit && !_submitting ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor:
                                  _canSubmit ? Colors.white : AppTheme.textHint,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Zakończ rejestrację'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Anuluj rejestrację',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textHint,
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
        ),
      ),
    );
  }
}
