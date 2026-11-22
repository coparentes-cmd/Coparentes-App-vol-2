import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/consent_config.dart';
import '../../data/models/user_consent.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';
import '../../widgets/mobile_onboarding_chrome.dart';
import '../../widgets/registration_consent_panel.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

/// Mobile-only parent-B join: code → account+zgody (UI gate) → welcome.
/// Consents are UX-only here — join API has no consent payload.
class JoinParentFlowScreen extends StatefulWidget {
  const JoinParentFlowScreen({super.key});

  @override
  State<JoinParentFlowScreen> createState() => _JoinParentFlowScreenState();
}

class _JoinParentFlowScreenState extends State<JoinParentFlowScreen> {
  int _step = 0;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late Map<ConsentType, bool> _selections;
  bool _settingsExpanded = true;
  bool _submitting = false;
  bool _codeLooksValid = false;

  static final _joinConsentTypes = <ConsentType>[
    ConsentType.terms,
    ConsentType.dataProcessing,
    ConsentType.emailNotifications,
  ];

  @override
  void initState() {
    super.initState();
    _selections = {
      for (final t in ConsentType.values) t: false,
    };
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  bool get _joinConsentsOk =>
      (_selections[ConsentType.terms] ?? false) &&
      (_selections[ConsentType.dataProcessing] ?? false);

  List<ConsentDefinition> get _joinConsentDefs => ConsentConfig
      .registrationConsents
      .where((d) => _joinConsentTypes.contains(d.type))
      .toList();

  void _onCodeChanged(String value) {
    final ok = value.trim().length >= 6;
    if (ok != _codeLooksValid) {
      setState(() => _codeLooksValid = ok);
    }
  }

  void _goCodeNext() {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _toast(context.tr('Kod zaproszenia musi mieć co najmniej 6 znaków.'));
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _join() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = normalizePassword(_passwordController.text);
    if (name.length < 2) {
      _toast(context.tr('Imię i nazwisko musi mieć co najmniej 2 znaki.'));
      return;
    }
    if (email.isEmpty) {
      _toast(context.tr('Uzupełnij e-mail.'));
      return;
    }
    final lengthError = validateNormalizedPasswordLength(password);
    if (lengthError != null) {
      _toast(lengthError);
      return;
    }
    if (!_joinConsentsOk) {
      _toast(context.tr('Zaznacz wymagane zgody'));
      return;
    }
    setState(() => _submitting = true);
    final ok = await context.read<AppProvider>().joinWorkspace(
          name: name,
          email: email,
          password: password,
          inviteCode: _codeController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      final err = context.read<AppProvider>().authError ?? '';
      if (err.toLowerCase().contains('kod') ||
          err.contains('invite') ||
          err.contains('not_found')) {
        setState(() => _step = 0);
        _toast(
          context.tr(
            'Ten kod nie działa. Sprawdź go z drugim rodzicem.',
          ),
        );
      } else {
        _toast(err.isEmpty ? context.tr('Operacja nie powiodła się.') : err);
      }
      return;
    }
    setState(() => _step = 2);
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileOnboarding.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step < 2)
                OnboardingProgressHeader(
                  stepLabel: context.tr(
                    _step == 0 ? 'Krok 1 z 2' : 'Krok 2 z 2',
                  ),
                  progress: _step == 0 ? 0.5 : 1,
                  onBack: () {
                    if (_step == 1) {
                      setState(() => _step = 0);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStep(context),
                ),
              ),
              if (_step < 2)
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : (_step == 0 ? _goCodeNext : _join),
                  style: MobileOnboarding.primaryButton(enabled: !_submitting),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.tr(
                            _step == 0 ? 'Dalej' : 'Dołącz do przestrzeni',
                          ),
                        ),
                )
              else
                ElevatedButton(
                  onPressed: _finish,
                  style: MobileOnboarding.primaryButton(),
                  child: Text(context.tr('Zaczynamy')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Wpisz kod'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Kod dostałeś/aś od drugiego rodzica — np. SMS-em albo e-mailem.',
              ),
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: _onCodeChanged,
                    decoration: InputDecoration(
                      labelText: context.tr('Kod zaproszenia'),
                    ),
                  ),
                  if (_codeLooksValid) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: MobileOnboarding.greenFg,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(
                              'Kod wygląda poprawnie — dołączysz do przestrzeni drugiego rodzica.',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MobileOnboarding.greenFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Nie masz kodu? Poproś drugiego rodzica — znajdzie go w Ustawieniach.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
                height: 1.35,
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Twoje konto'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: context.tr('Imię i nazwisko'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Hasło'),
                      hintText: context.tr('Minimum 8 znaków'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RegistrationConsentPanel(
                    selections: _selections,
                    onChanged: (next) => setState(() => _selections = next),
                    settingsExpanded: _settingsExpanded,
                    onExpandSettings: () =>
                        setState(() => _settingsExpanded = true),
                    consents: _joinConsentDefs,
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        final ws = context.watch<AppProvider>().currentWorkspace;
        final child = ws?.children.isNotEmpty == true ? ws!.children.first : null;
        final childLine = child == null
            ? context.tr(
                'Dziecko pojawi się tutaj, gdy drugi rodzic je doda.',
              )
            : '${child.name}${child.age > 0 ? ', ${child.age} lat' : ''}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Gotowe, jesteś we wspólnej przestrzeni'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bullet(text: childLine),
                  _Bullet(
                    text: context.tr('Wspólny kalendarz opieki'),
                  ),
                  _Bullet(
                    text: context.tr('Czat z archiwum'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OnboardingInfoBox.trialGreen(context),
          ],
        );
    }
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: MobileOnboarding.blue,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
