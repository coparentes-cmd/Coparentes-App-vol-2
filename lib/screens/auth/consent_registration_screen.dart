import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/consent_config.dart';
import '../../data/models/user_consent.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_utils.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/consent_widgets.dart';
import 'package:coparentes/l10n/app_strings.dart';

class RegistrationDraft {
  final String name;
  final String email;
  final String password;
  final String workspaceName;

  /// UX label chosen at register (Mama/Tata). API role stays parentA.
  final bool isMama;

  const RegistrationDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.workspaceName,
    required this.isMama,
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
  bool _autofillCommitted = false;

  @override
  void initState() {
    super.initState();
    _selections = defaultConsentSelections();
  }

  bool get _canSubmit => areRequiredConsentsGranted(_selections);

  String get _missingRequiredHint {
    if (_canSubmit) {
      return '';
    }
    return context.tr('Zaznacz wymagane zgody');
  }

  void _cancel() {
    // Web: discard autofill context without prompting the browser to save.
    TextInput.finishAutofillContext(shouldSave: false);
    Navigator.of(context).pop();
  }

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
      isMama: widget.draft.isMama,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() => _submitting = false);
      TextInput.finishAutofillContext(shouldSave: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appProvider.authError ??
                context.tr('Nie udało się zakończyć rejestracji.'),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Web: only after a successful create should the browser be asked to save.
    _autofillCommitted = true;
    TextInput.finishAutofillContext(shouldSave: true);
    // Let AppGate rebuild to ParentDashboard on the root route, then clear the
    // consent/register stack so we land on home — not RoleSelection/login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        // System back / gesture: discard without prompting password save.
        if (didPop && !_autofillCommitted) {
          TextInput.finishAutofillContext(shouldSave: false);
        }
      },
      child: Scaffold(
        body: BrandBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LayoutTokens.authConsentMax,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                        child: BrandCard(
                          padding: const EdgeInsets.all(26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: BrandLogo(width: 168, height: 54),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                context.tr('Zanim zaczniesz'),
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  'Przeczytaj i zaakceptuj poniższe zgody. Niektóre są wymagane do działania aplikacji.',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              ...ConsentConfig.registrationConsents.map(
                                (definition) {
                                  return Column(
                                    children: [
                                      ConsentRow(
                                        definition: definition,
                                        value: _selections[definition.type] ??
                                            false,
                                        onChanged: (value) {
                                          setState(() {
                                            _selections[definition.type] =
                                                value;
                                          });
                                        },
                                      ),
                                      if (definition !=
                                          ConsentConfig
                                              .registrationConsents.last)
                                        const Divider(
                                          color: AppTheme.dividerColor,
                                          height: 1,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              Text(
                                context.tr(
                                  'Możesz wycofać zgody opcjonalne w dowolnym momencie w Ustawieniach → Prywatność.',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_canSubmit) ...[
                            Text(
                              _missingRequiredHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _canSubmit
                                    ? AppTheme.brandGradient
                                    : null,
                                color:
                                    _canSubmit ? null : AppTheme.dividerColor,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow:
                                    _canSubmit ? AppTheme.softShadow : null,
                              ),
                              child: ElevatedButton(
                                key: const Key('consent_create_button'),
                                onPressed: _canSubmit && !_submitting
                                    ? _submit
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: _canSubmit
                                      ? Colors.white
                                      : AppTheme.textHint,
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
                                    : Text(context.tr('Utwórz')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              key: const Key('consent_cancel_button'),
                              onPressed: _submitting ? null : _cancel,
                              child: Text(
                                context.tr('Anuluj rejestrację'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ),
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
    );
  }
}
