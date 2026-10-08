import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/country_profiles.dart';
import '../../../config/legal_config.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/open_url.dart';
import '../../../widgets/app_content_shell.dart';
import '../../screens/auth/child_onboarding_sheet.dart';
import '../../screens/settings/privacy_consents_section.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/change_password_sheet.dart';
import 'widgets/delete_account_sheet.dart';
import 'widgets/email_invite_sheet.dart';
import 'widgets/parent_invite_actions_sheet.dart';
import 'widgets/children_settings_section.dart';
import 'widgets/delete_child_password_dialog.dart';
import 'widgets/settings_divider.dart';
import 'widgets/info_tile.dart';
import 'widgets/action_tile.dart';
import 'widgets/switch_tile.dart';
import 'widgets/ios_settings_accordion.dart';
import '../../../widgets/language_flag.dart';
import 'package:coparentes/l10n/app_strings.dart';

const _showPreLaunchPlaceholderSections = false;

/// Optional deep-link target when opening Settings from the onboarding tour.
enum SettingsFocus { parentInvite, addChild }

class SettingsScreen extends StatefulWidget {
  final SettingsFocus? focus;

  const SettingsScreen({super.key, this.focus});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// iOS-style accordion: one section open at a time (null = all collapsed).
  String? _expandedId = 'profile';
  final _parentInviteKey = GlobalKey();
  final _addChildKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _didApplyFocus = false;

  void _toggleSection(String id) {
    setState(() {
      _expandedId = _expandedId == id ? null : id;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFocusIfNeeded() {
    if (_didApplyFocus || widget.focus == null) return;
    _didApplyFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Invite / add-child live under Przestrzeń (not Profil).
      setState(() => _expandedId = 'workspace');
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final key = widget.focus == SettingsFocus.parentInvite
            ? _parentInviteKey
            : _addChildKey;
        final ctx = key.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            alignment: 0.15,
          );
        }
        if (!mounted) return;
        // Tour krok 1: open invite sheet immediately (Skopiuj / Wyślij kod e-mailem).
        if (widget.focus == SettingsFocus.parentInvite) {
          final ap = context.read<AppProvider>();
          final code = ap.currentWorkspace?.inviteCode;
          if (code != null && code.isNotEmpty) {
            await _showParentInviteActions(
              context,
              inviteCode: code,
              color: _roleColor(ap.currentUser?.role),
            );
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _applyFocusIfNeeded();
    final ap = context.watch<AppProvider>();
    final user = ap.currentUser;
    final workspace = ap.currentWorkspace;
    final roleColor = _roleColor(user?.role);
    final isDark = ap.isDark;
    final canShowInviteCode =
        workspace?.inviteCode != null &&
        workspace!.inviteCode!.isNotEmpty &&
        (user?.role == UserRole.parentA || user?.role == UserRole.parentB);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: AppContentShell(
        child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: roleColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [roleColor, roleColor.withValues(alpha: 0.8)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _roleEmoji(user?.role),
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user?.name ?? context.tr('Użytkownik'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ap.parentFamilyRoleLabel(user),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profil osobisty ──────────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Profil osobisty'),
                    icon: Icons.person_outline,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'profile',
                    onToggle: () => _toggleSection('profile'),
                    children: [
                    InfoTile(
                      icon: Icons.badge_outlined,
                      label: context.tr('Imię i nazwisko'),
                      value: user?.name ?? '—',
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.email_outlined,
                      label: context.tr('Adres e-mail'),
                      value: user?.email ?? '—',
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.work_outline,
                      label: context.tr('Rola w aplikacji'),
                      value: ap.parentFamilyRoleLabel(user),
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.edit_outlined,
                      label: context.tr('Edytuj profil'),
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showEditProfile(context, user, roleColor),
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.password_outlined,
                      label: context.tr('Zmień hasło'),
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showChangePasswordSheet(context, roleColor),
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.delete_outline,
                      label: context.tr('Usuń konto'),
                      subtitle: context.tr('Nieodwracalne – wymaga potwierdzenia'),
                      color: AppTheme.errorColor,
                      isDark: isDark,
                      onTap: () => _showDeleteDialog(context, ap, roleColor),
                    ),
                  ]),

                  if (user?.role == UserRole.parentA ||
                      user?.role == UserRole.parentB) ...[
                    SizedBox(height: 20),
                    IosSettingsAccordion(
                      title: context.tr('Przestrzeń'),
                      icon: Icons.home_outlined,
                      isDark: isDark,
                      accent: roleColor,
                      expanded: _expandedId == 'workspace',
                      onToggle: () => _toggleSection('workspace'),
                      children: [
                        ActionTile(
                          icon: Icons.edit_outlined,
                          label: context.tr('Nazwa przestrzeni'),
                          subtitle: workspace?.name ?? '—',
                          color: roleColor,
                          isDark: isDark,
                          onTap: () => _showRenameWorkspace(
                            context,
                            ap,
                            roleColor,
                          ),
                        ),
                        if (workspace != null &&
                            workspace.members.isNotEmpty) ...[
                          SettingsDivider(),
                          InfoTile(
                            icon: Icons.people_outline,
                            label: context.tr('Członkowie'),
                            value: workspace.members
                                .map((m) =>
                                    '${m.name} (${ap.parentFamilyRoleLabel(m)})')
                                .join('\n'),
                            isDark: isDark,
                          ),
                        ],
                        if (canShowInviteCode) ...[
                          SettingsDivider(),
                          KeyedSubtree(
                            key: _parentInviteKey,
                            child: ActionTile(
                              icon: Icons.family_restroom_outlined,
                              label: context.tr(
                                'Kod zaproszenia dla drugiego rodzica',
                              ),
                              subtitle: workspace.inviteCodeExpiresAt != null
                                  ? '${workspace.inviteCode!}\nWażny do ${_formatInviteExpiry(workspace.inviteCodeExpiresAt!)}'
                                  : (workspace.inviteCode ?? '—'),
                              color: roleColor,
                              isDark: isDark,
                              onTap: () => _showParentInviteActions(
                                context,
                                inviteCode: workspace.inviteCode!,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                        ChildrenSettingsSection(
                          children: workspace?.children ?? const [],
                          userRole: user?.role,
                          roleColor: roleColor,
                          isDark: isDark,
                          initiallyExpanded:
                              widget.focus == SettingsFocus.addChild,
                          addChildKey: _addChildKey,
                          onAddChild: user?.role == UserRole.parentA
                              ? () => showChildOnboardingSheet(context)
                              : null,
                          onCopyInvite: (child) {
                            final code = child.inviteCode;
                            if (code == null || code.isEmpty) return;
                            _copyInviteCode(context, code, roleColor);
                          },
                          onEdit: (child) => _showEditChild(
                            context,
                            ap,
                            child,
                            roleColor,
                          ),
                          onDelete: (child) => _confirmDeleteChild(
                            context,
                            ap,
                            child,
                          ),
                          onResetPassword: (child) {
                            final linkedId = child.linkedAccountId;
                            if (linkedId == null) return;
                            _resetChildLoginPassword(
                              context,
                              childUserId: linkedId,
                              ap: ap,
                            );
                          },
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 20),

                  // ── Wygląd ────────────────────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Wygląd'),
                    icon: Icons.palette_outlined,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'appearance',
                    onToggle: () => _toggleSection('appearance'),
                    children: [
                    // Dark / Light mode
                    SwitchTile(
                      icon: isDark
                          ? Icons.dark_mode
                          : Icons.light_mode_outlined,
                      label: context.tr('Tryb ciemny'),
                      subtitle: isDark ? context.tr('Ciemne tło aktywne') : context.tr('Jasne tło aktywne'),
                      value: isDark,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: (v) => ap.setThemeMode(
                        v ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                    SettingsDivider(),

                    // Color palette
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.color_lens_outlined,
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.textSecondary,
                                  size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Kolor aplikacji',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                AppColorScheme.values.map((scheme) {
                              final isSelected =
                                  ap.colorScheme == scheme;
                              return GestureDetector(
                                onTap: () => ap.setColorScheme(scheme),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: isSelected ? 46 : 40,
                                  height: isSelected ? 46 : 40,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: scheme.primary
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Wybrano: ${ap.colorScheme.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  SizedBox(height: 20),

                  // ── Powiadomienia ─────────────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Powiadomienia'),
                    icon: Icons.notifications_outlined,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'notifications',
                    onToggle: () => _toggleSection('notifications'),
                    children: [
                    SwitchTile(
                      icon: Icons.chat_bubble_outline,
                      label: context.tr('Nowe wiadomości'),
                      subtitle: context.tr('Alert przy każdej nowej wiadomości'),
                      value: ap.notifyMessages,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyMessages,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.calendar_today_outlined,
                      label: context.tr('Zdarzenia kalendarza'),
                      subtitle: context.tr('Przypomnienia o przekazaniach i zajęciach'),
                      value: ap.notifyCalendar,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyCalendar,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.swap_horiz_outlined,
                      label: context.tr('Wnioski o zamianę'),
                      subtitle: context.tr('Alert o nowych wnioskach o zamianę'),
                      value: ap.notifySwaps,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifySwaps,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: context.tr('Finanse'),
                      subtitle: context.tr('Nowe wydatki wymagające uwagi'),
                      value: ap.notifyFinance,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyFinance,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.warning_amber_outlined,
                      label: context.tr('Tryb wysokiego konfliktu'),
                      subtitle: context.tr('HC – ograniczone powiadomienia'),
                      value: ap.highConflictMode,
                      activeColor: AppTheme.highConflictColor,
                      isDark: isDark,
                      onChanged: ap.isDemoMode
                          ? (_) => ap.toggleHighConflictMode()
                          : (_) async {
                              await ap.toggleHighConflictMode();
                              if (!context.mounted) return;
                              if (ap.authError != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ap.authError ??
                                          context.tr('Nie udało się zaktualizować trybu konfliktu.'),
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            },
                    ),
                  ]),

                  SizedBox(height: 20),

                  // ── Prywatność i zgody ───────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Prywatność i zgody'),
                    icon: Icons.verified_user_outlined,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'privacy',
                    onToggle: () => _toggleSection('privacy'),
                    children: [
                      PrivacyConsentsSection(
                        roleColor: roleColor,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  if (_showPreLaunchPlaceholderSections) ...[
                    SizedBox(height: 20),
                    IosSettingsAccordion(
                    title: context.tr('Subskrypcja i rozliczenia'),
                    icon: Icons.credit_card_outlined,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'billing',
                    onToggle: () => _toggleSection('billing'),
                    children: [
                      InfoTile(
                        icon: Icons.workspace_premium_outlined,
                        label: context.tr('Plan'),
                        value: 'Coparentes',
                        isDark: isDark,
                        valueColor: const Color(0xFF6A1B9A),
                      ),
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.calendar_month_outlined,
                        label: context.tr('Następne odnowienie'),
                        value: '15 maja 2025',
                        isDark: isDark,
                      ),
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.payments_outlined,
                        label: context.tr('Kwota'),
                        value: '39,99 ${ap.currencyCode} / ${context.tr('miesiąc')}',
                        isDark: isDark,
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.receipt_long_outlined,
                        label: context.tr('Historia płatności'),
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showBillingHistory(context, roleColor),
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.credit_card_outlined,
                        label: context.tr('Zmień metodę płatności'),
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showFeatureInfo(
                            context,
                            'Metoda płatności',
                            'Obsługujemy BLIK, kartę płatniczą oraz przelew bankowy. Zarządzaj metodami płatności w panelu klienta.',
                            roleColor),
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.cancel_outlined,
                        label: context.tr('Anuluj subskrypcję'),
                        color: AppTheme.errorColor,
                        isDark: isDark,
                        onTap: () => _showCancelDialog(context, roleColor),
                      ),
                    ]),
                  ],

                  SizedBox(height: 20),

                  // ── Eksport danych ────────────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Dane i eksport'),
                    icon: Icons.folder_special_outlined,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'data',
                    onToggle: () => _toggleSection('data'),
                    children: [
                    ActionTile(
                      icon: Icons.download_outlined,
                      label: context.tr('Pobierz moje dane (RODO)'),
                      subtitle: context.tr('Wyślij wniosek e-mailem do supportu'),
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showRodoExportDialog(context, ap, roleColor),
                    ),
                  ]),

                  SizedBox(height: 20),

                  // ── Aplikacja ─────────────────────────────────────────────
                  IosSettingsAccordion(
                    title: context.tr('Aplikacja'),
                    icon: Icons.info_outline,
                    isDark: isDark,
                    accent: roleColor,
                    expanded: _expandedId == 'app',
                    onToggle: () => _toggleSection('app'),
                    children: [
                    InfoTile(
                      icon: Icons.apps_outlined,
                      label: context.tr('Wersja aplikacji'),
                      value: '1.0.0 (MVP)',
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.language_outlined,
                      label: 'Language',
                      subtitle: ap.locale.languageCode.toUpperCase(),
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _pickLanguage(context, ap, roleColor),
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.public_outlined,
                      label: 'Country profile',
                      subtitle: ap.countryProfile.code,
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _pickCountryProfile(context, ap, roleColor),
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.credit_card_outlined,
                      label: 'Currency',
                      value: ap.currencyCode,
                      isDark: isDark,
                    ),
                    if (_showPreLaunchPlaceholderSections) ...[
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.gavel_outlined,
                        label: context.tr('Regulamin'),
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showFeatureInfo(
                            context,
                            'Regulamin',
                            '${LegalConfig.companyName} · ${LegalConfig.companyAddress}\nRegulamin i polityka prywatnosci powinny byc opublikowane pod ${LegalConfig.websiteUrl} przed wysylka do sklepow.',
                            roleColor),
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.shield_moon_outlined,
                        label: context.tr('Polityka prywatności (RODO)'),
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showFeatureInfo(
                            context,
                            'RODO',
                            'Administratorem danych jest ${LegalConfig.companyName}. Zakres danych i retencja zaleza od aktywnych funkcji konta. Przed publikacja produkcyjna nalezy opublikowac finalna polityke prywatnosci pod ${LegalConfig.privacyUrl}.',
                            roleColor),
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.support_agent_outlined,
                        label: context.tr('Pomoc i wsparcie'),
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showFeatureInfo(
                            context,
                            'Wsparcie',
                            'E-mail: ${LegalConfig.supportEmail}\nTelefon: ${LegalConfig.supportPhone}\nWWW: ${LegalConfig.supportUrl}\n\nPrzed wypchnieciem do sklepow upewnij sie, ze te dane prowadza do aktywnego supportu.',
                            roleColor),
                      ),
                    ],
                  ]),

                  SizedBox(height: 24),

                  // ── Wyloguj (iOS-style destructive row) ───────────────────
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _logout(context),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(context.tr('Wyloguj się'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Coparentes v1.0.0\nCopyright © 2026 ${LegalConfig.companyName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white38 : AppTheme.textHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _roleEmoji(UserRole? role) {
    switch (role) {
      case UserRole.parentA:
        return '👩';
      case UserRole.parentB:
        return '👨';
      case UserRole.child:
        return '👧';
      case UserRole.observer:
        return '⚖️';
      default:
        return '👤';
    }
  }

  Color _roleColor(UserRole? role) {
    switch (role) {
      case UserRole.parentA:
        return AppTheme.parentAColor;
      case UserRole.parentB:
        return AppTheme.parentBColor;
      case UserRole.child:
        return AppTheme.childColor;
      case UserRole.observer:
        return AppTheme.observerColor;
      default:
        return AppTheme.primaryTeal;
    }
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Wyloguj się')),
        content:
            Text(context.tr('Czy na pewno chcesz się wylogować z Coparentes?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Anuluj'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              context.read<AppProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: Text(context.tr('Wyloguj'),
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(BuildContext context, AppProvider ap, Color color) {
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
                    ? Icon(Icons.check, color: color)
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

  void _pickCountryProfile(BuildContext context, AppProvider ap, Color color) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in CountryProfiles.all)
              ListTile(
                leading: Icon(Icons.public, color: color),
                title: Text('${profile.name} (${profile.code})'),
                subtitle: Text(
                  '${profile.languageCode.toUpperCase()} · ${profile.currencyCode}',
                ),
                onTap: () {
                  ap.setCountryProfile(profile.code);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatInviteExpiry(DateTime expiresAt) {
    final local = expiresAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Future<void> _copyInviteCode(
    BuildContext context,
    String inviteCode,
    Color color,
  ) async {
    await copyParentInviteCode(
      context,
      inviteCode: inviteCode,
      color: color,
    );
  }

  Future<void> _showParentInviteActions(
    BuildContext context, {
    required String inviteCode,
    required Color color,
  }) async {
    final action = await ParentInviteActionsSheet.show(
      context,
      inviteCode: inviteCode,
      color: color,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case ParentInviteAction.copy:
        await copyParentInviteCode(
          context,
          inviteCode: inviteCode,
          color: color,
        );
      case ParentInviteAction.sendEmail:
        _showEmailInviteSheet(context, color);
    }
  }

  void _showFeatureInfo(
      BuildContext context, String title, String msg, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr(title)),
        content: Text(context.tr(msg), style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(
      BuildContext context, AppUser? user, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EditProfileSheet(user: user, color: color),
    );
  }

  Future<void> _showRenameWorkspace(
    BuildContext context,
    AppProvider ap,
    Color color,
  ) async {
    final controller = TextEditingController(
      text: ap.currentWorkspace?.name ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Nazwa przestrzeni')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('Nazwa'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Anuluj')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(
              context.tr('Zapisz'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      controller.dispose();
      return;
    }
    final name = controller.text.trim();
    controller.dispose();
    final success = await ap.renameWorkspace(name);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('Zapisano nazwę przestrzeni.')
              : (ap.authError ?? context.tr('Nie udało się zapisać.')),
        ),
        backgroundColor: success ? color : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _showEditChild(
    BuildContext context,
    AppProvider ap,
    ChildProfile child,
    Color color,
  ) async {
    final nameController = TextEditingController(text: child.name);
    final schoolController = TextEditingController(text: child.school ?? '');
    var dob = child.dateOfBirth;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(context.tr('Edytuj dziecko')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('Imię i nazwisko'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Data urodzenia')),
                    subtitle: Text(
                      '${dob.day.toString().padLeft(2, '0')}-'
                      '${dob.month.toString().padLeft(2, '0')}-'
                      '${dob.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dob,
                        firstDate: DateTime(DateTime.now().year - 25),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setLocal(() => dob = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: schoolController,
                    decoration: InputDecoration(
                      labelText: context.tr('Szkoła (opcjonalnie)'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('Anuluj')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: Text(
                    context.tr('Zapisz'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) {
      nameController.dispose();
      schoolController.dispose();
      return;
    }

    final success = await ap.updateWorkspaceChild(
      childId: child.id,
      name: nameController.text.trim(),
      dateOfBirth: dob,
      school: schoolController.text.trim().isEmpty
          ? null
          : schoolController.text.trim(),
    );
    nameController.dispose();
    schoolController.dispose();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('Zapisano profil dziecka.')
              : (ap.authError ?? context.tr('Nie udało się zapisać.')),
        ),
        backgroundColor: success ? color : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _confirmDeleteChild(
    BuildContext context,
    AppProvider ap,
    ChildProfile child,
  ) async {
    final password = await showDeleteChildPasswordDialog(
      context,
      childName: child.name,
    );
    if (password == null || !context.mounted) {
      return;
    }
    final success = await ap.deleteWorkspaceChild(
      child.id,
      password: password,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('Usunięto profil dziecka.')
              : (ap.authError ?? context.tr('Nie udało się usunąć.')),
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangePasswordSheet(color: color),
    );
  }

  Future<void> _resetChildLoginPassword(
    BuildContext context, {
    required String childUserId,
    required AppProvider ap,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Zresetuj hasło logowania dziecka')),
        content: Text(
          context.tr(
            'Wyślemy link do ustawienia nowego hasła na e-mail obojga rodziców. '
            'Dziecko będzie musiało zalogować się nowym hasłem przy następnej okazji.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Anuluj')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Wyślij')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ap.resetChildPassword(childUserId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('Link wysłany na e-mail obojga rodziców.')
              : (ap.authError ??
                  context.tr('Nie udało się zresetować hasła dziecka.')),
        ),
        backgroundColor: ok ? null : AppTheme.errorColor,
      ),
    );
  }

  void _showEmailInviteSheet(BuildContext context, Color color) {
    final inviteCode =
        context.read<AppProvider>().currentWorkspace?.inviteCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EmailInviteSheet(
        color: color,
        inviteCode: inviteCode,
      ),
    );
  }

  void _showBillingHistory(BuildContext context, Color color) {
    final currencyCode = context.read<AppProvider>().currencyCode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Historia płatności'),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            _billingRow('15 kwi 2025', '39,99 $currencyCode', 'Opłacona', color),
            _billingRow('15 mar 2025', '39,99 $currencyCode', 'Opłacona', color),
            _billingRow('15 lut 2025', '39,99 $currencyCode', 'Opłacona', color),
            _billingRow('15 sty 2025', '39,99 $currencyCode', 'Opłacona', color),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Zamknij')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billingRow(
      String date, String amount, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(date,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary))),
          Text(amount,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(context.tr(status),
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Anuluj subskrypcję')),
        content: Text(context.tr('Czy na pewno chcesz anulować? Stracisz dostęp do wszystkich funkcji Pro po zakończeniu okresu rozliczeniowego (15 maja 2025).')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Nie, zachowaj'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Subskrypcja zostanie anulowana 15 maja 2025'),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            },
            child: Text(context.tr('Anuluj subskrypcję'),
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _openSupportMailto({required String subject, required String body}) {
    final uri = Uri(
      scheme: 'mailto',
      path: LegalConfig.supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    openExternalUrl(uri.toString());
  }

  void _showRodoExportDialog(
    BuildContext context,
    AppProvider ap,
    Color color,
  ) {
    final email = ap.currentUser?.email ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Eksport danych RODO')),
        content: Text('Wyślemy wniosek o kopię Twoich danych (art. 20 RODO) na adres ${LegalConfig.supportEmail}. Odpowiemy na e-mail powiązany z kontem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Anuluj')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSupportMailto(
                subject: 'Wniosek o eksport danych RODO — Coparentes',
                body: 'Proszę o eksport moich danych osobowych.\n\n'
                    'E-mail konta: $email\n',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(context.tr('Wyślij e-mail'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AppProvider ap, Color color) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Usuń konto')),
        content: Text(
          context.tr(
            'Ta operacja jest nieodwracalna. Twoje konto zostanie trwale usunięte, nie będziesz mógł się już zalogować. Historia wiadomości i wspólnych danych (kalendarz, wydatki, dokumenty) zostanie zachowana dla drugiego rodzica, ale bez możliwości przypisania jej do Ciebie z powrotem.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Anuluj')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => DeleteAccountSheet(color: color),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              context.tr('Kontynuuj'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}







// ─── Shared sub-widgets ───────────────────────────────────────────────────────
