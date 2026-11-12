import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/app_environment.dart';
import '../../data/api/app_api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/offline_sync_provider.dart';
import '../../services/cookie_consent/cookie_consent_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/language_flag.dart';
import 'consent_registration_screen.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

/// Brand login gradient from wzor-logowanie.html (marketing shell only).
const _loginGradient = LinearGradient(
  begin: Alignment(-0.85, -1),
  end: Alignment(0.95, 1),
  colors: [
    Color(0xFF0B4F94),
    Color(0xFF106DBC),
    Color(0xFF00769C),
    Color(0xFF009570),
  ],
  stops: [0.0, 0.30, 0.62, 1.0],
);

const _loginFormShadow = [
  BoxShadow(
    color: Color(0x47001932),
    blurRadius: 80,
    offset: Offset(0, 30),
  ),
  BoxShadow(
    color: Color(0x14001932),
    blurRadius: 6,
    offset: Offset(0, 2),
  ),
];

const _demoOrange = Color(0xFFF96245);
const _demoOrangeHover = Color(0xFFEE5537);
const _loginGreen = Color(0xFF0FC494);
const _tabBlue = Color(0xFF1276D6);

/// Login-screen-only fonts (Poppins headings/controls, Inter body/fields).
TextStyle _loginPoppins({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _loginInter({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

enum _AuthMode { login, register, join, joinChild }

enum _Audience { adult, child }

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  _AuthMode _mode = _AuthMode.login;
  _Audience _audience = _Audience.adult;
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _workspaceController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _childInviteCodeController = TextEditingController();
  final _childLoginController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _showSubmittingHint = false;
  Timer? _submittingHintTimer;
  bool _registerIsMama = true;
  bool _demoPickerOpen = false;
  bool? _backendReachable;
  ChildJoinPreview? _childJoinPreview;
  bool _loadingChildPreview = false;
  DateTime? _childDateOfBirth;

  bool _obscureLoginPassword = true;

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
    _submittingHintTimer?.cancel();
    _nameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _workspaceController.dispose();
    _inviteCodeController.dispose();
    _childInviteCodeController.dispose();
    _childLoginController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  void _setSubmitting(bool value) {
    _submittingHintTimer?.cancel();
    _submittingHintTimer = null;
    if (!value) {
      setState(() {
        _submitting = false;
        _showSubmittingHint = false;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _showSubmittingHint = false;
    });
    _submittingHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_submitting) {
        return;
      }
      setState(() => _showSubmittingHint = true);
    });
  }

  String get _composedRegisterName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return '$first $last'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final authError = appProvider.authError;

    // Fonts are scoped via _loginPoppins / _loginInter on this screen only.
    return Scaffold(
      backgroundColor: const Color(0xFF0B4F94),
      body: _LoginMarketingBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              // wzor HTML: max-width 860 → 1 kolumna. U Ciebie okno ~1024 —
              // dwie kolumny OK, ale poniżej 900 px stack.
              final narrow = viewport.maxWidth < 900;
              final short = viewport.maxHeight < 820;
              final sidePad = narrow ? 16.0 : 24.0;
              final offlineBanner =
                  context.watch<OfflineSyncProvider>().showBanner;
              // Banner offline jest overlay — zostaw miejsce pod logo.
              final topPad = (offlineBanner ? 56.0 : 0.0) +
                  (narrow ? 24.0 : (short ? 20.0 : 40.0));
              final bottomPad = 32.0;
              // wzor .page: 560 + 36 + 690 ≈ 1286
              final contentWidth =
                  (viewport.maxWidth - sidePad * 2).clamp(0.0, 1286.0);
              final intro = _BrandIntroCard(
                compact: narrow,
                short: short,
                demoPickerOpen: _demoPickerOpen,
                onDemoHorseTap: _submitting
                    ? null
                    : () => setState(
                          () => _demoPickerOpen = !_demoPickerOpen,
                        ),
                onDemoRoleSelected: _submitting ? null : _enterDemoRole,
              );
              final form = BrandCard(
                            padding: EdgeInsets.fromLTRB(
                              narrow ? 16 : 36,
                              narrow ? 18 : 32,
                              narrow ? 16 : 36,
                              narrow ? 18 : 28,
                            ),
                            borderRadius: 24,
                            border: Border.all(color: Colors.transparent),
                            boxShadow: _loginFormShadow,
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
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _ModeSelector(
                                      mode: _mode == _AuthMode.joinChild
                                          ? _AuthMode.join
                                          : _mode,
                                      onChanged: (mode) => setState(() {
                                        _childJoinPreview = null;
                                        if (mode == _AuthMode.register) {
                                          _audience = _Audience.adult;
                                          _mode = mode;
                                        } else if (mode == _AuthMode.join &&
                                            _audience == _Audience.child) {
                                          _mode = _AuthMode.joinChild;
                                        } else {
                                          _mode = mode;
                                        }
                                      }),
                                    ),
                                    if (_mode == _AuthMode.login ||
                                        _mode == _AuthMode.join ||
                                        _mode == _AuthMode.joinChild) ...[
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _RoleChoiceChip(
                                              label: context.tr('Dorosły'),
                                              selected:
                                                  _audience == _Audience.adult,
                                              onTap: () => setState(() {
                                                _audience = _Audience.adult;
                                                if (_mode ==
                                                    _AuthMode.joinChild) {
                                                  _mode = _AuthMode.join;
                                                }
                                                _childJoinPreview = null;
                                              }),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _RoleChoiceChip(
                                              label: context.tr('Dziecko'),
                                              selected:
                                                  _audience == _Audience.child,
                                              onTap: () => setState(() {
                                                _audience = _Audience.child;
                                                if (_mode == _AuthMode.join) {
                                                  _mode = _AuthMode.joinChild;
                                                }
                                                _childJoinPreview = null;
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    if (_backendReachable == false) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppTheme.warningColor
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          'Serwer API niedostępny (${AppEnvironment.apiBaseUrl}). Rejestracja i logowanie nie zadziałają, dopóki backend nie odpowiada.',
                                          style: _loginInter(
                                            color: AppTheme.warningColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
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
                                          style: _loginInter(
                                            color: AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    _LoginPrimaryButton(
                                      onPressed:
                                          _submitting ? null : _submit,
                                      child: _submitting
                                          ? Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (_showSubmittingHint) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    context.tr(
                                                      'To może potrwać chwilę...',
                                                    ),
                                                    style: _loginInter(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : Text(
                                              _buttonLabel(_mode),
                                              style: _loginPoppins(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 17,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                    final showDebugBanner = kDebugMode &&
                        !const bool.fromEnvironment(
                          'COPARENTES_HIDE_DEBUG_BANNER',
                        );
                    final debugBanner = showDebugBanner
                        ? Container(
                            width: double.infinity,
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
                            child: Text(
                              context.tr(
                                'Lokalny tryb debug jest aktywny. Użyj własnych danych seed skonfigurowanych po stronie backendu deweloperskiego.',
                              ),
                              style: _loginInter(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null;

                    final pageBody = narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              intro,
                              const SizedBox(height: 16),
                              form,
                              if (debugBanner != null) ...[
                                const SizedBox(height: 16),
                                debugBanner,
                              ],
                            ],
                          )
                        : Row(
                            // wzor: grid 560 / 690
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 560, child: intro),
                              SizedBox(
                                width: contentWidth < 1100 ? 22 : 36,
                              ),
                              Expanded(
                                flex: 690,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: form,
                                ),
                              ),
                            ],
                          );

                    final minBodyHeight = (viewport.maxHeight -
                            topPad -
                            bottomPad)
                        .clamp(0.0, double.infinity);

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              sidePad,
                              topPad,
                              sidePad,
                              bottomPad,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: minBodyHeight,
                                maxWidth: contentWidth,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: contentWidth,
                                  child: pageBody,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: offlineBanner ? 52 : 8,
                          right: 12,
                          child: _StartLanguageButton(
                            languageCode: appProvider.language,
                            onPick: () =>
                                _pickLanguage(context, appProvider),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: TextButton(
                            onPressed: () => context
                                .read<CookieConsentController>()
                                .openSettings(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              context.tr('Ustawienia cookies'),
                              style: _loginInter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
    );
  }

  void _pickLanguage(BuildContext context, AppProvider ap) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (Locale('pl'), 'Polski', 'pl'),
              (Locale('en'), 'English', 'en'),
            ])
              ListTile(
                leading: LanguageFlag(languageCode: entry.$3, size: 28),
                title: Text(entry.$2),
                trailing: ap.language == entry.$1.languageCode
                    ? const Icon(Icons.check, color: AppTheme.primaryTeal)
                    : null,
                onTap: () {
                  ap.setLocale(entry.$1);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModeFields() {
    switch (_mode) {
      case _AuthMode.login:
        if (_audience == _Audience.child) {
          return [
            _Field(
              controller: _childLoginController,
              label: context.tr('Login'),
              hint: context.tr('Imię użyte przy pierwszym dołączeniu'),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Data urodzenia')),
              subtitle: Text(
                _childDateOfBirth == null
                    ? context.tr('Wybierz datę (DD-MM-RRRR)')
                    : _formatDob(_childDateOfBirth!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickChildDateOfBirth,
            ),
            _Field(
              controller: _passwordController,
              label: context.tr('Hasło'),
              hint: context.tr('Minimum 8 znaków'),
              obscureText: _obscureLoginPassword,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: null,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submitIfIdle(),
              onToggleObscure: () => setState(
                () => _obscureLoginPassword = !_obscureLoginPassword,
              ),
            ),
          ];
        }
        // Web: autofillHints: null → AutofillConfiguration.disabled →
        // autocomplete="off". Empty list [] does NOT disable (still enabled).
        // Browsers may still offer to save when type=password; Flutter cannot
        // fully suppress that.
        return [
          _Field(
            controller: _emailController,
            label: 'E-mail',
            hint: 'twoj@email.pl',
            keyboardType: TextInputType.emailAddress,
            autofillHints: null,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: context.tr('Hasło'),
            hint: context.tr('Hasło lub 12 cyfr z maila'),
            obscureText: _obscureLoginPassword,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: null,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
            onToggleObscure: () => setState(
              () => _obscureLoginPassword = !_obscureLoginPassword,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _ForgotPasswordLink(
              onPressed: _submitting ? null : _showForgotPasswordDialog,
              label: context.tr('Nie pamiętam hasła'),
            ),
          ),
          const SizedBox(height: 4),
        ];
      case _AuthMode.register:
        // AutofillGroup stays mounted while ConsentRegistrationScreen is pushed
        // on top. onDisposeAction.cancel avoids browser save on leave/cancel;
        // ConsentRegistrationScreen calls finishAutofillContext(shouldSave: true)
        // only after a successful "Utwórz".
        return [
          AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Column(
              children: [
                _Field(
                  controller: _firstNameController,
                  label: context.tr('Imię'),
                  hint: 'np. Anna',
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                _Field(
                  controller: _lastNameController,
                  label: context.tr('Nazwisko'),
                  hint: 'np. Kowalska',
                  autofillHints: const [AutofillHints.familyName],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RoleChoiceChip(
                          label: context.tr('Mama'),
                          selected: _registerIsMama,
                          onTap: () => setState(() => _registerIsMama = true),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _RoleChoiceChip(
                          label: context.tr('Tata'),
                          selected: !_registerIsMama,
                          onTap: () => setState(() => _registerIsMama = false),
                        ),
                      ),
                    ],
                  ),
                ),
                _Field(
                  controller: _workspaceController,
                  label: context.tr('Nazwa przestrzeni'),
                  hint: 'np. Rodzina Kowalska',
                  autofillHints: const [AutofillHints.organizationName],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                _Field(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'twoj@email.pl',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                _Field(
                  controller: _passwordController,
                  label: context.tr('Hasło'),
                  hint: context.tr('Minimum 8 znaków'),
                  obscureText: true,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submitIfIdle(),
                ),
              ],
            ),
          ),
        ];
      case _AuthMode.join:
        return [
          _Field(
            controller: _inviteCodeController,
            label: context.tr('Kod zaproszenia do przestrzeni'),
            hint: 'np. RODZINA-AB12',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _nameController,
            label: context.tr('Imię i nazwisko'),
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
            label: context.tr('Hasło'),
            hint: context.tr('Minimum 8 znaków'),
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
      case _AuthMode.joinChild:
        return [
          _Field(
            controller: _childInviteCodeController,
            label: context.tr('Kod zaproszenia dziecka'),
            hint: 'np. DZIECIKOWAL2026',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loadingChildPreview ? null : _loadChildPreview,
              child: _loadingChildPreview
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Sprawdź kod')),
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
                style: _loginInter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(context.tr('Podaj datę urodzenia z profilu dodanego przez rodzica.'),
              style: _loginInter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Data urodzenia')),
              subtitle: Text(
                _childDateOfBirth == null
                    ? context.tr('Wybierz datę (DD-MM-RRRR)')
                    : _formatDob(_childDateOfBirth!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickChildDateOfBirth,
            ),
          ],
          _Field(
            controller: _nameController,
            label: context.tr('Login (imię przy pierwszym dołączeniu)'),
            hint: 'np. Zosia',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          _Field(
            controller: _passwordController,
            label: context.tr('Hasło'),
            hint: context.tr('Minimum 8 znaków'),
            obscureText: true,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitIfIdle(),
          ),
        ];
    }
  }

  Future<void> _pickChildDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _childDateOfBirth ?? DateTime(now.year - 8, 6, 1),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Twoja data urodzenia (DD-MM-RRRR)',
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

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    var sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('Nie pamiętam hasła')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Podaj e-mail konta. Wyślemy link do ustawienia nowego hasła. Sprawdź skrzynkę i kliknij w link.'),
                    style: _loginInter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      labelText: context.tr('E-mail'),
                      hintText: 'twoj@email.pl',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      sending ? null : () => Navigator.pop(dialogContext),
                  child: Text(context.tr('Anuluj')),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final messenger =
                              ScaffoldMessenger.of(this.context);
                          final appProvider =
                              this.context.read<AppProvider>();
                          if (email.isEmpty || !email.contains('@')) {
                            messenger.showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr('Podaj prawidłowy adres e-mail.')),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => sending = true);
                          final ok =
                              await appProvider.requestPasswordReset(email);
                          if (!dialogContext.mounted) {
                            return;
                          }
                          setDialogState(() => sending = false);

                          if (ok) {
                            Navigator.pop(dialogContext);
                            if (!mounted) {
                              return;
                            }
                            _emailController.text = email;
                            _passwordController.clear();
                            setState(() => _obscureLoginPassword = false);
                            messenger.showTopSnackBar(
                              SnackBar(
                                content: Text(context.tr('Sprawdź swoją skrzynkę e-mail i kliknij w link, aby ustawić nowe hasło.')),
                                backgroundColor: AppTheme.successColor,
                                duration: Duration(seconds: 8),
                              ),
                            );
                          } else {
                            messenger.showTopSnackBar(
                              SnackBar(
                                content: Text(
                                  appProvider.authError ??
                                      context.tr('Nie udało się wysłać hasła.'),
                                ),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: sending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('Wyślij link')),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  Future<void> _submit() async {
    final appProvider = context.read<AppProvider>();
    final email = _emailController.text.trim();
    final password = normalizePassword(_passwordController.text);

    final isChildLogin =
        _mode == _AuthMode.login && _audience == _Audience.child;
    final isChildJoin = _mode == _AuthMode.joinChild;

    if (isChildLogin || isChildJoin) {
      if (password.isEmpty) {
        _showMessage('Uzupełnij hasło.');
        return;
      }
    } else if (email.isEmpty || password.isEmpty) {
      _showMessage('Uzupełnij e-mail i hasło.');
      return;
    }

    final lengthError = validateNormalizedPasswordLength(password);
    if (lengthError != null) {
      _showMessage(lengthError);
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
      // Mama/Tata is UX-only for labels — first registrant remains parentA on API.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConsentRegistrationScreen(
            draft: RegistrationDraft(
              name: name,
              email: email,
              password: password,
              workspaceName: workspaceName,
              isMama: _registerIsMama,
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

    if (isChildLogin) {
      if (_childLoginController.text.trim().length < 2) {
        _showMessage('Podaj login (min. 2 znaki).');
        return;
      }
      if (_childDateOfBirth == null) {
        _showMessage('Wybierz datę urodzenia.');
        return;
      }
    }

    if (isChildJoin) {
      final childInviteCode = _childInviteCodeController.text.trim();
      if (childInviteCode.length < 6) {
        _showMessage('Kod zaproszenia dziecka musi mieć co najmniej 6 znaków.');
        return;
      }
      if (_childJoinPreview == null) {
        _showMessage('Najpierw sprawdź kod zaproszenia dziecka.');
        return;
      }
      if (_childDateOfBirth == null) {
        _showMessage('Wybierz datę urodzenia.');
        return;
      }
      if (_childDateOfBirth!.isAfter(DateTime.now())) {
        _showMessage('Data urodzenia nie może być w przyszłości.');
        return;
      }
    }

    _setSubmitting(true);

    bool success;
    switch (_mode) {
      case _AuthMode.login:
        if (isChildLogin) {
          success = await appProvider.loginChildAccount(
            login: _childLoginController.text.trim(),
            password: password,
            dateOfBirth: _childDateOfBirth!,
          );
        } else {
          success = await appProvider.login(email: email, password: password);
        }
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
          dateOfBirth: _childDateOfBirth!,
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        );
        break;
    }

    if (!mounted) {
      return;
    }

    _setSubmitting(false);

    if (!success) {
      _showMessage(appProvider.authError ?? 'Operacja nie powiodła się.');
    }
  }

  Future<void> _enterDemoRole(UserRole role) async {
    _setSubmitting(true);
    await context.read<AppProvider>().enterDemoRole(role);
    if (!mounted) {
      return;
    }
    _setSubmitting(false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showTopSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  String _buttonLabel(_AuthMode mode) {
    switch (mode) {
      case _AuthMode.login:
        return context.tr('Zaloguj');
      case _AuthMode.register:
        return context.tr('Zarejestruj');
      case _AuthMode.join:
        return context.tr('Dołącz');
      case _AuthMode.joinChild:
        return context.tr('Wejdź');
    }
  }
}


class _BrandIntroCard extends StatelessWidget {
  final bool compact;
  final bool short;
  final bool demoPickerOpen;
  final VoidCallback? onDemoHorseTap;
  final Future<void> Function(UserRole role)? onDemoRoleSelected;

  const _BrandIntroCard({
    required this.compact,
    this.short = false,
    required this.demoPickerOpen,
    required this.onDemoHorseTap,
    required this.onDemoRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final featureGap = short ? 14.0 : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 8 : (short ? 8 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/branding/coparentes-logo-white-wordmark.png',
            width: compact ? 200 : 240,
            height: compact ? 40 : (short ? 48 : 58),
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const BrandLogo(width: 220, height: 56),
          ),
          SizedBox(height: compact ? 14 : (short ? 14 : 26)),
          Text(
            context.tr('Spokojne rodzicielstwo po rozstaniu'),
            style: _loginPoppins(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
              fontSize: compact ? 18 : (short ? 18 : 21),
              height: 1.35,
            ),
          ),
          if (!compact) ...[
            SizedBox(height: short ? 18 : 34),
            _FeatureBullet(
              dense: short,
              icon: Icons.chat_bubble_outline,
              title: context.tr('Komunikacja'),
              subtitle: context.tr(
                'Wiadomości i archiwizacja rozmów w jednym miejscu.',
              ),
            ),
            SizedBox(height: featureGap),
            _FeatureBullet(
              dense: short,
              icon: Icons.calendar_month_outlined,
              title: context.tr('Organizacja'),
              subtitle: context.tr(
                'Kalendarz opieki, wydarzenia i zamiany terminów bez chaosu.',
              ),
            ),
            SizedBox(height: featureGap),
            _FeatureBullet(
              dense: short,
              icon: Icons.account_balance_wallet_outlined,
              title: context.tr('Finanse'),
              subtitle: context.tr(
                'Wydatki, paragony i rozliczenia zaprojektowane pod wspólne rodzicielstwo.',
              ),
            ),
          ],
          SizedBox(height: compact ? 22 : (short ? 18 : 28)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 26,
              compact || short ? 16 : 26,
              compact ? 18 : 26,
              compact || short ? 14 : 24,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFDF8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFA9EFD8), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47001932),
                  blurRadius: 60,
                  offset: Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 56 : 72,
                      height: compact ? 56 : 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x140A7D5C),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/branding/demo-horse.png',
                        width: compact ? 34 : 46,
                        height: compact ? 27 : 37,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.toys_outlined,
                          color: AppTheme.primaryTeal,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 14 : 20),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Tryb demo — sprawdź czy aplikacja Ci pomoże',
                        ),
                        style: _loginPoppins(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: compact ? 16 : 18,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 22),
                _DemoLaunchButton(
                  label: context.tr('Tryb demo'),
                  expanded: demoPickerOpen,
                  onPressed: onDemoHorseTap,
                ),
                if (demoPickerOpen) ...[
                  const SizedBox(height: 14),
                  Text(
                    context.tr('Wybierz tryb wersji demo'),
                    style: _loginPoppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DemoRoleButton(
                    label: context.tr('Anna — matka'),
                    icon: Icons.person_outline,
                    onTap: onDemoRoleSelected == null
                        ? null
                        : () => onDemoRoleSelected!(UserRole.parentA),
                  ),
                  const SizedBox(height: 8),
                  _DemoRoleButton(
                    label: context.tr('Marek — ojciec'),
                    icon: Icons.person,
                    onTap: onDemoRoleSelected == null
                        ? null
                        : () => onDemoRoleSelected!(UserRole.parentB),
                  ),
                  const SizedBox(height: 8),
                  _DemoRoleButton(
                    label: context.tr('Franek — dziecko'),
                    icon: Icons.child_care,
                    onTap: onDemoRoleSelected == null
                        ? null
                        : () => onDemoRoleSelected!(UserRole.child),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool dense;
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = dense ? 52.0 : 64.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(dense ? 14 : 18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: Colors.white, size: dense ? 24 : 28),
        ),
        SizedBox(width: dense ? 14 : 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _loginPoppins(
                  color: Colors.white,
                  fontSize: dense ? 20 : 24,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: _loginInter(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: dense ? 15 : 18,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  letterSpacing: 0.01,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatefulWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  State<_ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends State<_ModeSelector> {
  _AuthMode? _hovered;

  @override
  Widget build(BuildContext context) {
    final items = <(_AuthMode, String)>[
      (_AuthMode.login, context.tr('Logowanie')),
      (_AuthMode.register, context.tr('Rejestracja')),
      (_AuthMode.join, context.tr('Dołączanie')),
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: 44,
      child: Row(
        children: items.map((item) {
          final selected = widget.mode == item.$1;
          final hovered = _hovered == item.$1;
          return Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = item.$1),
              onExit: (_) => setState(() => _hovered = null),
              child: InkWell(
                onTap: () => widget.onChanged(item.$1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 180),
                  curve: const Cubic(0.2, 0.8, 0.2, 1),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  decoration: BoxDecoration(
                    color: hovered && !selected
                        ? _tabBlue.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? _tabBlue : AppTheme.dividerColor,
                        width: selected ? 2.5 : 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    item.$2,
                    style: _loginPoppins(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
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

class _RoleChoiceChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RoleChoiceChip> createState() => _RoleChoiceChipState();
}

class _RoleChoiceChipState extends State<_RoleChoiceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduceMotion ? 0 : 180),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFD8FCF2)
              : _hovered
                  ? const Color(0xFFF6FBF9)
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _loginGreen : AppTheme.dividerColor,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: _loginGreen.withValues(alpha: 0.18),
                blurRadius: 0,
                spreadRadius: 3,
              )
            else if (_hovered)
              BoxShadow(
                color: _loginGreen.withValues(alpha: 0.10),
                blurRadius: 0,
                spreadRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: selected ? _loginGreen : AppTheme.textHint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: _loginPoppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryTeal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: _loginPoppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
                size: 18,
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
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onToggleObscure;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints = const <String>[],
    this.onSubmitted,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          style: _loginInter(fontSize: 16, height: 1.2, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: _loginInter(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: AppTheme.textHint,
            ),
            labelStyle: _loginInter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.dividerColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _loginGreen, width: 1.5),
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscureText
                        ? context.tr('Pokaż hasło')
                        : context.tr('Ukryj hasło'),
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StartLanguageButton extends StatefulWidget {
  final String languageCode;
  final VoidCallback onPick;

  const _StartLanguageButton({
    required this.languageCode,
    required this.onPick,
  });

  @override
  State<_StartLanguageButton> createState() => _StartLanguageButtonState();
}

class _StartLanguageButtonState extends State<_StartLanguageButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduceMotion ? 0 : 150),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        transformAlignment: Alignment.center,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33001E3C),
              blurRadius: _hovered ? 24 : 20,
              offset: Offset(0, _hovered ? 8 : 6),
            ),
            if (_hovered)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35),
                blurRadius: 0,
                spreadRadius: 5,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: widget.onPick,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: widget.languageCode == 'en' ? 'English' : 'Polski',
              child: Center(
                child: LanguageFlag(
                  languageCode: widget.languageCode,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMarketingBackdrop extends StatelessWidget {
  final Widget child;
  const _LoginMarketingBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _loginGradient),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -220,
            bottom: -240,
            child: _LoginOrb(
              size: 660,
              color: Color(0x8C24D3A5),
            ),
          ),
          const Positioned(
            left: -140,
            bottom: -240,
            child: _LoginOrb(
              size: 480,
              color: Color(0xBFE56446),
            ),
          ),
          const Positioned(
            left: -220,
            top: -240,
            child: _LoginOrb(
              size: 620,
              color: Color(0xB30A3F80),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _LoginOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _LoginOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _LoginPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _LoginPrimaryButton({required this.onPressed, required this.child});

  @override
  State<_LoginPrimaryButton> createState() => _LoginPrimaryButtonState();
}

class _LoginPrimaryButtonState extends State<_LoginPrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) {
        if (!enabled) return;
        setState(() => _hovered = true);
        if (!reduceMotion) {
          _shine.forward(from: 0);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduceMotion ? 0 : 180),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        transform: Matrix4.translationValues(0, _hovered && enabled ? -2 : 0, 0),
        transformAlignment: Alignment.center,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovered && enabled
              ? [
                  BoxShadow(
                    color: _loginGreen.withValues(alpha: 0.22),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: _loginGreen.withValues(alpha: 0.42),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _loginGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _loginGreen.withValues(alpha: 0.55),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: _loginPoppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ).copyWith(
                    overlayColor: WidgetStatePropertyAll(
                      Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: widget.child,
                ),
              ),
              if (!reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (context, _) {
                        if (!_hovered || _shine.value == 0) {
                          return const SizedBox.shrink();
                        }
                        final left = -0.7 + (_shine.value * 1.95);
                        return Align(
                          alignment: Alignment(left * 2 - 1, 0),
                          child: Transform(
                            transform: Matrix4.skewX(-0.35),
                            child: Container(
                              width: MediaQuery.sizeOf(context).width * 0.12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.38),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

class _DemoLaunchButton extends StatefulWidget {
  final String label;
  final bool expanded;
  final VoidCallback? onPressed;
  const _DemoLaunchButton({
    required this.label,
    required this.expanded,
    required this.onPressed,
  });

  @override
  State<_DemoLaunchButton> createState() => _DemoLaunchButtonState();
}

class _DemoLaunchButtonState extends State<_DemoLaunchButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Color get _bg {
    if (_pressed) return const Color(0xFFE04B2E);
    if (_hovered) return _demoOrangeHover;
    return _demoOrange;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) {
        if (!enabled) return;
        setState(() => _hovered = true);
        if (!reduceMotion) _shine.forward(from: 0);
      },
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion ? 0 : 180),
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          transform:
              Matrix4.translationValues(0, _hovered && enabled ? -2 : 0, 0),
          transformAlignment: Alignment.center,
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled ? _bg : _demoOrange.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: enabled ? _bg : Colors.transparent),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _demoOrange.withValues(
                        alpha: _hovered ? 0.45 : 0.35,
                      ),
                      blurRadius: _hovered ? 24 : 18,
                      offset: Offset(0, _hovered ? 10 : 8),
                    ),
                    if (_hovered)
                      BoxShadow(
                        color: _demoOrange.withValues(alpha: 0.22),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Semantics(
                  button: true,
                  label: widget.label,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.expanded
                            ? Icons.expand_less
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: _loginPoppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!reduceMotion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (context, _) {
                          if (!_hovered || _shine.value == 0) {
                            return const SizedBox.shrink();
                          }
                          final left = -0.7 + (_shine.value * 1.95);
                          return Align(
                            alignment: Alignment(left * 2 - 1, 0),
                            child: Transform(
                              transform: Matrix4.skewX(-0.35),
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.38),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordLink extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  const _ForgotPasswordLink({required this.onPressed, required this.label});

  @override
  State<_ForgotPasswordLink> createState() => _ForgotPasswordLinkState();
}

class _ForgotPasswordLinkState extends State<_ForgotPasswordLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TextButton(
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          widget.label,
          style: _loginInter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _tabBlue,
          ).copyWith(
            decoration:
                _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: _tabBlue,
            decorationThickness: 1.5,
          ),
        ),
      ),
    );
  }
}
