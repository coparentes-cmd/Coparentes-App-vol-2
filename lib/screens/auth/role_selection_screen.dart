import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_environment.dart';
import '../../config/legal_config.dart';
import '../../data/api/app_api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_utils.dart';
import '../../widgets/brand_widgets.dart';
import 'consent_registration_screen.dart';
import 'otp_verification_screen.dart';

enum _AuthMode { login, register, join, joinChild }

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  _AuthMode _mode = _AuthMode.login;
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _workspaceController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _childInviteCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _registerIsMama = true;
  bool _demoPickerOpen = false;
  bool? _backendReachable;
  ChildJoinPreview? _childJoinPreview;
  bool _loadingChildPreview = false;
  DateTime _childDateOfBirth = DateTime(DateTime.now().year - 8, 6, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkBackendReachability());
  }

  Future<void> _checkBackendReachability() async {
    final client = AppApiClient(baseUrl: AppEnvironment.apiBaseUrl);
    try {
      final ok = await client.pingHealth();
      if (!mounted) {
        return;
      }
      setState(() => _backendReachable = ok);
      if (!ok) {
        _showMessage(
          'Backend niedostępny pod adresem ${AppEnvironment.apiBaseUrl}. '
          'Sprawdź Netlify → COPARENTES_API_BASE_URL.',
        );
      }
    } finally {
      client.dispose();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _workspaceController.dispose();
    _inviteCodeController.dispose();
    _childInviteCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _composedRegisterName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return '$first $last'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final pendingOtp = appProvider.pendingLoginChallenge;
    if (pendingOtp != null) {
      return OtpVerificationScreen(
        challenge: pendingOtp,
        onCancel: appProvider.clearLoginChallenge,
      );
    }

    final authError = appProvider.authError;

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LayoutTokens.authMarketingMax,
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow =
                        constraints.maxWidth < LayoutTokens.authTwoColumnMin;
                    return Wrap(
                      spacing: 22,
                      runSpacing: 22,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: narrow ? constraints.maxWidth : 420,
                          child: _BrandIntroCard(
                            demoPickerOpen: _demoPickerOpen,
                            onDemoHorseTap: _submitting
                                ? null
                                : () => setState(
                                      () => _demoPickerOpen = !_demoPickerOpen,
                                    ),
                            onDemoRoleSelected: _submitting
                                ? null
                                : _enterDemoRole,
                          ),
                        ),
                        SizedBox(
                          width: narrow ? constraints.maxWidth : 520,
                          child: BrandCard(
                            padding: const EdgeInsets.all(26),
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(LogicalKeyboardKey.enter):
                                    _submitIfIdle,
                                const SingleActivator(
                                  LogicalKeyboardKey.numpadEnter,
                                ): _submitIfIdle,
                              },
                              child: Focus(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ModeSelector(
                                      mode: _mode == _AuthMode.joinChild
                                          ? _AuthMode.join
                                          : _mode,
                                      onChanged: (mode) => setState(() {
                                        _mode = mode;
                                        _childJoinPreview = null;
                                      }),
                                    ),
                                    const SizedBox(height: 22),
                                    if (_backendReachable == false) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: AppTheme.warningColor
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          'Serwer API niedostępny (${AppEnvironment.apiBaseUrl}). '
                                          'Rejestracja i logowanie nie zadziałają, dopóki backend nie odpowiada.',
                                          style: const TextStyle(
                                            color: AppTheme.warningColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    ..._buildModeFields(),
                                    if (authError != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppTheme.coralColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: AppTheme.coralColor
                                                .withValues(alpha: 0.18),
                                          ),
                                        ),
                                        child: Text(
                                          authError,
                                          style: const TextStyle(
                                            color: AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _submitting ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryTeal,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _submitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                _buttonLabel(_mode),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                      ),
                                    ),
                                    if (_mode == _AuthMode.join) ...[
                                      const SizedBox(height: 12),
                                      Center(
                                        child: TextButton(
                                          onPressed: () => setState(() {
                                            _mode = _AuthMode.joinChild;
                                            _childJoinPreview = null;
                                          }),
                                          child: const Text('Wejście dziecka'),
                                        ),
                                      ),
                                    ],
                                    if (_mode == _AuthMode.joinChild) ...[
                                      const SizedBox(height: 8),
                                      Center(
                                        child: TextButton(
                                          onPressed: () => setState(() {
                                            _mode = _AuthMode.join;
                                            _childJoinPreview = null;
                                          }),
                                          child: const Text(
                                            '← Powrót do dołączania rodzica',
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    if (_mode != _AuthMode.register)
                                      Text(
                                        'Korzystając z aplikacji akceptujesz zasady Coparentes oraz prywatność zgodną ze stroną ${LegalConfig.websiteUrl}.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (kDebugMode)
                          SizedBox(
                            width: narrow ? constraints.maxWidth : 962,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.yellowColor
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.yellowColor
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: const Text(
                                'Lokalny tryb debug jest aktywny. Użyj własnych danych seed skonfigurowanych po stronie backendu deweloperskiego.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildModeFields() {
    switch (_mode) {
      case _AuthMode.login:
        return [
          _Field(
            controller: _emailController,
            label: 'E-mail',
            hint: 'twoj@email.pl',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: 'Hasło',
            hint: 'Minimum 10 znaków',
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
      case _AuthMode.register:
        return [
          _Field(
            controller: _firstNameController,
            label: 'Imię',
            hint: 'np. Anna',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _lastNameController,
            label: 'Nazwisko',
            hint: 'np. Kowalska',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _RoleChoiceChip(
                    label: 'Mama',
                    selected: _registerIsMama,
                    onTap: () => setState(() => _registerIsMama = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RoleChoiceChip(
                    label: 'Tata',
                    selected: !_registerIsMama,
                    onTap: () => setState(() => _registerIsMama = false),
                  ),
                ),
              ],
            ),
          ),
          _Field(
            controller: _workspaceController,
            label: 'Nazwa przestrzeni',
            hint: 'np. Rodzina Kowalska',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _emailController,
            label: 'E-mail',
            hint: 'twoj@email.pl',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: 'Hasło',
            hint: 'Minimum 10 znaków',
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
      case _AuthMode.join:
        return [
          _Field(
            controller: _inviteCodeController,
            label: 'Kod zaproszenia do przestrzeni',
            hint: 'np. RODZINA-AB12',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _nameController,
            label: 'Imię i nazwisko',
            hint: 'np. Marek Kowalski',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _emailController,
            label: 'E-mail',
            hint: 'twoj@email.pl',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: 'Hasło',
            hint: 'Minimum 10 znaków',
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
      case _AuthMode.joinChild:
        return [
          _Field(
            controller: _childInviteCodeController,
            label: 'Kod zaproszenia dziecka',
            hint: 'np. DZIECIKOWAL2026',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loadingChildPreview ? null : _loadChildPreview,
              child: _loadingChildPreview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sprawdź kod'),
            ),
          ),
          if (_childJoinPreview != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.childColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.childColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Rodzina: ${_childJoinPreview!.workspaceName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Podaj datę urodzenia z profilu dodanego przez rodzica.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data urodzenia'),
              subtitle: Text(
                '${_childDateOfBirth.day.toString().padLeft(2, '0')}.'
                '${_childDateOfBirth.month.toString().padLeft(2, '0')}.'
                '${_childDateOfBirth.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickChildDateOfBirth,
            ),
          ],
          _Field(
            controller: _nameController,
            label: 'Imię (przy pierwszym logowaniu)',
            hint: 'np. Zosia',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: 'Hasło',
            hint: 'Minimum 10 znaków',
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
    }
  }

  Future<void> _pickChildDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _childDateOfBirth,
      firstDate: DateTime(DateTime.now().year - 25),
      lastDate: DateTime.now(),
      helpText: 'Twoja data urodzenia',
    );

    if (picked != null) {
      setState(() => _childDateOfBirth = picked);
    }
  }

  Future<void> _loadChildPreview() async {
    final code = _childInviteCodeController.text.trim();
    if (code.length < 6) {
      _showMessage('Kod zaproszenia dziecka musi mieć co najmniej 6 znaków.');
      return;
    }

    setState(() {
      _loadingChildPreview = true;
      _childJoinPreview = null;
    });

    final preview = await context.read<AppProvider>().getChildJoinPreview(code);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingChildPreview = false;
      _childJoinPreview = preview;
    });

    if (preview == null) {
      _showMessage('Nie znaleziono rodziny dla tego kodu.');
    } else if (preview.children.isEmpty) {
      _showMessage(
        'Brak profili dzieci. Poproś rodzica o dodanie Twojego profilu.',
      );
    }
  }

  void _submitIfIdle() {
    if (_submitting) {
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    final appProvider = context.read<AppProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_mode != _AuthMode.joinChild) {
      if (email.isEmpty || password.isEmpty) {
        _showMessage('Uzupełnij e-mail i hasło.');
        return;
      }
    } else if (password.isEmpty) {
      _showMessage('Uzupełnij hasło.');
      return;
    }

    if (password.length < 10) {
      _showMessage('Hasło musi mieć co najmniej 10 znaków.');
      return;
    }

    if (_mode == _AuthMode.register) {
      final name = _composedRegisterName;
      if (_firstNameController.text.trim().length < 2 ||
          _lastNameController.text.trim().length < 2) {
        _showMessage('Uzupełnij imię i nazwisko (min. 2 znaki każde).');
        return;
      }
      if (name.length < 2) {
        _showMessage('Imię i nazwisko musi mieć co najmniej 2 znaki.');
        return;
      }
      final workspaceName = _workspaceController.text.trim();
      if (workspaceName.length < 2) {
        _showMessage('Nazwa przestrzeni musi mieć co najmniej 2 znaki.');
        return;
      }
      // Mama/Tata is UX-only — first registrant remains parentA on API.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConsentRegistrationScreen(
            draft: RegistrationDraft(
              name: name,
              email: email,
              password: password,
              workspaceName: workspaceName,
            ),
          ),
        ),
      );
      return;
    }

    if (_mode == _AuthMode.join) {
      final name = _nameController.text.trim();
      if (name.length < 2) {
        _showMessage('Imię i nazwisko musi mieć co najmniej 2 znaki.');
        return;
      }
      final inviteCode = _inviteCodeController.text.trim();
      if (inviteCode.length < 6) {
        _showMessage('Kod zaproszenia musi mieć co najmniej 6 znaków.');
        return;
      }
    }

    if (_mode == _AuthMode.joinChild) {
      final childInviteCode = _childInviteCodeController.text.trim();
      if (childInviteCode.length < 6) {
        _showMessage('Kod zaproszenia dziecka musi mieć co najmniej 6 znaków.');
        return;
      }
      if (_childJoinPreview == null) {
        _showMessage('Najpierw sprawdź kod zaproszenia dziecka.');
        return;
      }
      if (_childDateOfBirth.isAfter(DateTime.now())) {
        _showMessage('Data urodzenia nie może być w przyszłości.');
        return;
      }
    }

    setState(() => _submitting = true);

    bool success;
    switch (_mode) {
      case _AuthMode.login:
        success = await appProvider.login(email: email, password: password);
        break;
      case _AuthMode.register:
        success = false;
        break;
      case _AuthMode.join:
        success = await appProvider.joinWorkspace(
          name: _nameController.text.trim(),
          email: email,
          password: password,
          inviteCode: _inviteCodeController.text.trim(),
        );
        break;
      case _AuthMode.joinChild:
        success = await appProvider.accessChildAccount(
          password: password,
          childInviteCode: _childInviteCodeController.text.trim(),
          dateOfBirth: _childDateOfBirth,
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        );
        break;
    }

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    if (!success) {
      _showMessage(appProvider.authError ?? 'Operacja nie powiodła się.');
    }
  }

  Future<void> _enterDemoRole(UserRole role) async {
    setState(() => _submitting = true);
    await context.read<AppProvider>().enterDemoRole(role);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buttonLabel(_AuthMode mode) {
    switch (mode) {
      case _AuthMode.login:
        return 'Zaloguj';
      case _AuthMode.register:
        return 'Zarejestruj';
      case _AuthMode.join:
        return 'Dołącz';
      case _AuthMode.joinChild:
        return 'Wejdź';
    }
  }
}

class _BrandIntroCard extends StatelessWidget {
  final bool demoPickerOpen;
  final VoidCallback? onDemoHorseTap;
  final Future<void> Function(UserRole role)? onDemoRoleSelected;

  const _BrandIntroCard({
    required this.demoPickerOpen,
    required this.onDemoHorseTap,
    required this.onDemoRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(width: 220, height: 56),
          const SizedBox(height: 14),
          Text(
            'Spokojne rodzicielstwo po rozstaniu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 28),
          const _FeatureBullet(
            icon: Icons.chat_bubble_outline,
            title: 'Komunikacja',
            subtitle:
                'Wiadomości, AI Coach i archiwizacja rozmów w jednym miejscu.',
          ),
          const SizedBox(height: 14),
          const _FeatureBullet(
            icon: Icons.calendar_month_outlined,
            title: 'Organizacja',
            subtitle:
                'Kalendarz opieki, wydarzenia i zamiany terminów bez chaosu.',
          ),
          const SizedBox(height: 14),
          const _FeatureBullet(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Finanse',
            subtitle:
                'Wydatki, paragony i rozliczenia zaprojektowane pod wspólne rodzicielstwo.',
          ),
          const SizedBox(height: 28),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDemoHorseTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/branding/demo-horse.png',
                      width: 36,
                      height: 29,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.toys_outlined,
                        color: AppTheme.primaryTeal,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tryb demo — sprawdź czy aplikacja Ci pomoże',
                        style: TextStyle(
                          color: AppTheme.primaryTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      demoPickerOpen
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppTheme.primaryTeal,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (demoPickerOpen) ...[
            const SizedBox(height: 14),
            Text(
              'Wybierz tryb wersji demo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _DemoRoleButton(
              label: 'Anna — matka',
              icon: Icons.person_outline,
              onTap: onDemoRoleSelected == null
                  ? null
                  : () => onDemoRoleSelected!(UserRole.parentA),
            ),
            const SizedBox(height: 8),
            _DemoRoleButton(
              label: 'Marek — ojciec',
              icon: Icons.person,
              onTap: onDemoRoleSelected == null
                  ? null
                  : () => onDemoRoleSelected!(UserRole.parentB),
            ),
            const SizedBox(height: 8),
            _DemoRoleButton(
              label: 'Franek — dziecko',
              icon: Icons.child_care,
              onTap: onDemoRoleSelected == null
                  ? null
                  : () => onDemoRoleSelected!(UserRole.child),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <(_AuthMode, String)>[
      (_AuthMode.login, 'Logowanie'),
      (_AuthMode.register, 'Rejestracja'),
      (_AuthMode.join, 'Dołączanie'),
    ];

    return SizedBox(
      height: 44,
      child: Row(
        children: items.map((item) {
          final selected = mode == item.$1;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(item.$1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? AppTheme.accentColor
                          : AppTheme.dividerColor,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RoleChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primaryTeal.withValues(alpha: 0.12)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppTheme.primaryTeal : AppTheme.dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: selected ? AppTheme.primaryTeal : AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoRoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _DemoRoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryTeal, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
