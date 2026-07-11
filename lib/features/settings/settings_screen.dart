import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/country_profiles.dart';
import '../../../config/legal_config.dart';
import '../../../models/models.dart';
import '../../../providers/app_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/open_url.dart';
import '../../screens/auth/child_onboarding_sheet.dart';
import '../../screens/settings/privacy_consents_section.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/change_password_sheet.dart';
import 'widgets/email_invite_sheet.dart';
import 'widgets/section_header.dart';
import 'widgets/settings_card.dart';
import 'widgets/settings_divider.dart';
import 'widgets/info_tile.dart';
import 'widgets/action_tile.dart';
import 'widgets/switch_tile.dart';
import 'widgets/setup_pin_sheet.dart';
import 'widgets/change_pin_sheet.dart';

const _showPreLaunchPlaceholderSections = false;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.surfaceColor,
      body: CustomScrollView(
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user?.name ?? 'Użytkownik',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _roleBadge(user?.role),
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
                  SectionHeader(
                      label: 'Profil osobisty', icon: Icons.person_outline),
                  SettingsCard(isDark: isDark, children: [
                    InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Imię i nazwisko',
                      value: user?.name ?? '—',
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Adres e-mail',
                      value: user?.email ?? '—',
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.work_outline,
                      label: 'Rola w aplikacji',
                      value: _roleBadge(user?.role),
                      isDark: isDark,
                    ),
                    SettingsDivider(),
                    InfoTile(
                      icon: Icons.group_outlined,
                      label: 'Workspace',
                      value: workspace?.name ?? '—',
                      isDark: isDark,
                    ),
                    if (workspace != null && workspace.members.isNotEmpty) ...[
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.people_outline,
                        label: 'Członkowie rodziny',
                        value:
                            '${workspace.members.length} (${workspace.members.map((m) => m.name.split(' ').first).join(', ')})',
                        isDark: isDark,
                      ),
                    ],
                    if (canShowInviteCode) ...[
                      SettingsDivider(),
                      if (user?.role == UserRole.parentA &&
                          workspace.childInviteCode != null &&
                          workspace.childInviteCode!.isNotEmpty) ...[
                        ActionTile(
                          icon: Icons.child_care_outlined,
                          label: 'Kod zaproszenia dziecka',
                          subtitle: workspace.childInviteCode!,
                          color: roleColor,
                          isDark: isDark,
                          onTap: () => _copyInviteCode(
                            context,
                            workspace.childInviteCode!,
                            roleColor,
                          ),
                        ),
                        SettingsDivider(),
                      ],
                      ActionTile(
                        icon: Icons.family_restroom_outlined,
                        label: 'Kod zaproszenia dla drugiego rodzica',
                        subtitle: workspace.inviteCodeExpiresAt != null
                            ? '${workspace.inviteCode!}\nWażny do ${_formatInviteExpiry(workspace.inviteCodeExpiresAt!)}'
                            : workspace.inviteCode!,
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _copyInviteCode(
                          context,
                          workspace.inviteCode!,
                          roleColor,
                        ),
                      ),
                    ],

                    if (user?.role == UserRole.parentA) ...[
                      SettingsDivider(),
                      if (workspace != null && workspace.children.isNotEmpty) ...[
                        InfoTile(
                          icon: Icons.people_outline,
                          label: 'Dzieci w rodzinie',
                          value: workspace.children
                              .map((c) => c.name.split(' ').first)
                              .join(', '),
                          isDark: isDark,
                        ),
                        ...workspace.children.map(
                          (child) => InfoTile(
                            icon: Icons.child_care,
                            label: child.name,
                            value: [
                              '${child.age} lat',
                              if (child.school != null && child.school!.isNotEmpty)
                                child.school!,
                            ].join(' · '),
                            isDark: isDark,
                          ),
                        ),
                      ],
                      ActionTile(
                        icon: Icons.person_add_outlined,
                        label: 'Dodaj dziecko',
                        subtitle: workspace?.children.isEmpty ?? true
                            ? 'Dodaj pierwszy profil dziecka'
                            : 'Dodaj kolejny profil dziecka',
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => showChildOnboardingSheet(context),
                      ),
                    ],

                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edytuj profil',
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showEditProfile(context, user, roleColor),
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.password_outlined,
                      label: 'Zmień hasło',
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showChangePasswordSheet(context, roleColor),
                    ),
                  ]),

                  if (user?.role == UserRole.parentA) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      label: 'Zaproszenia e-mail',
                      icon: Icons.mail_outline,
                    ),
                    SettingsCard(isDark: isDark, children: [
                      ActionTile(
                        icon: Icons.send_outlined,
                        label: 'Zaproś drugiego rodzica mailem',
                        subtitle: 'Wyślij link akceptacji na e-mail',
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showEmailInviteSheet(context, roleColor),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // ── Wygląd ────────────────────────────────────────────────
                  SectionHeader(label: 'Wygląd', icon: Icons.palette_outlined),
                  SettingsCard(isDark: isDark, children: [
                    // Dark / Light mode
                    SwitchTile(
                      icon: isDark
                          ? Icons.dark_mode
                          : Icons.light_mode_outlined,
                      label: 'Tryb ciemny',
                      subtitle: isDark ? 'Ciemne tło aktywne' : 'Jasne tło aktywne',
                      value: isDark,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: (v) => ap.toggleDarkMode(),
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
                          const SizedBox(height: 8),
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

                  const SizedBox(height: 20),

                  // ── Bezpieczeństwo i logowanie ────────────────────────────
                  SectionHeader(
                      label: 'Bezpieczeństwo',
                      icon: Icons.security_outlined),
                  SettingsCard(isDark: isDark, children: [
                    SwitchTile(
                      icon: Icons.lock_outline,
                      label: 'PIN przy wznowieniu',
                      subtitle: ap.hasPinSet
                          ? 'Wymagaj PIN-u po przejściu aplikacji w tło'
                          : 'Najpierw ustaw PIN w „Zmień PIN logowania”',
                      value: ap.requirePinOnResume,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.hasPinSet
                          ? (value) => _togglePinOnResume(context, ap, value)
                          : (value) {
                              if (value) {
                                _showSetupPinSheet(context, roleColor, ap,
                                    enableOnResume: true);
                              }
                            },
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.verified_user_outlined,
                      label: '2FA (dwuetapowa weryfikacja)',
                      subtitle: 'Kod weryfikacyjny e-mail przy logowaniu',
                      value: user?.twoFactorEnabled ?? false,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.isDemoMode
                          ? null
                          : (value) async {
                              final ok = await ap.updateProfile(
                                twoFactorEnabled: value,
                              );
                              if (!context.mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ap.authError ??
                                          'Nie udało się zaktualizować 2FA.',
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            },
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.pin_outlined,
                      label: 'Zmień PIN logowania',
                      subtitle: ap.hasPinSet
                          ? 'Zmień 4-cyfrowy PIN'
                          : 'Ustaw 4-cyfrowy PIN',
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showChangePinDialog(context, roleColor, ap),
                    ),
                    if (_showPreLaunchPlaceholderSections) ...[
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.history_outlined,
                        label: 'Ostatnie logowanie',
                        value: 'Dziś, ${_formatNow()}',
                        isDark: isDark,
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.devices_outlined,
                        label: 'Zaufane urządzenia',
                        subtitle: '1 urządzenie zarejestrowane',
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showFeatureInfo(
                            context,
                            'Zaufane urządzenia',
                            'Zarządzaj urządzeniami z dostępem do konta. Ta funkcja będzie dostępna w pełnej wersji.',
                            roleColor),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 20),

                  // ── Powiadomienia ─────────────────────────────────────────
                  SectionHeader(
                      label: 'Powiadomienia',
                      icon: Icons.notifications_outlined),
                  SettingsCard(isDark: isDark, children: [
                    SwitchTile(
                      icon: Icons.chat_bubble_outline,
                      label: 'Nowe wiadomości',
                      subtitle: 'Alert przy każdej nowej wiadomości',
                      value: ap.notifyMessages,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyMessages,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Zdarzenia kalendarza',
                      subtitle: 'Przypomnienia o przekazaniach i zajęciach',
                      value: ap.notifyCalendar,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyCalendar,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.swap_horiz_outlined,
                      label: 'Wnioski o zamianę',
                      subtitle: 'Alert o nowych wnioskach o zamianę',
                      value: ap.notifySwaps,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifySwaps,
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Finanse',
                      subtitle: 'Nowe wydatki wymagające uwagi',
                      value: ap.notifyFinance,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: ap.setNotifyFinance,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── AI & Prywatność ────────────────────────────────────────
                  SectionHeader(
                      label: 'AI i prywatność',
                      icon: Icons.auto_awesome_outlined),
                  SettingsCard(isDark: isDark, children: [
                    SwitchTile(
                      icon: Icons.psychology_outlined,
                      label: 'AI Coach (pre-send)',
                      subtitle: 'Analiza tonu przed wysłaniem wiadomości',
                      value: ap.aiCoachEnabled,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: (_) => ap.toggleAiCoach(),
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.shield_outlined,
                      label: 'AI Shield (post-receive)',
                      subtitle: 'Filtrowanie toksycznych treści',
                      value: ap.aiShieldEnabled,
                      activeColor: roleColor,
                      isDark: isDark,
                      onChanged: (_) => ap.toggleAiShield(),
                    ),
                    SettingsDivider(),
                    SwitchTile(
                      icon: Icons.warning_amber_outlined,
                      label: 'Tryb wysokiego konfliktu',
                      subtitle: 'HC – ograniczone powiadomienia',
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
                                          'Nie udało się zaktualizować trybu konfliktu.',
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            },
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Polityka prywatności AI',
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showFeatureInfo(
                          context,
                          'AI i prywatność',
                          'Modele AI nie przechowują Twoich wiadomości. Każda analiza jest efemeryczna i nie wpływa na treningowe zbiory danych. Zgodność z EU AI Act (tryb transparency).',
                          roleColor),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Prywatność i zgody ───────────────────────────────────
                  SectionHeader(
                    label: 'Prywatność i zgody',
                    icon: Icons.verified_user_outlined,
                  ),
                  SettingsCard(
                    isDark: isDark,
                    children: [
                      PrivacyConsentsSection(
                        roleColor: roleColor,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  if (_showPreLaunchPlaceholderSections) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                        label: 'Subskrypcja i rozliczenia',
                        icon: Icons.credit_card_outlined),
                    SettingsCard(isDark: isDark, children: [
                      InfoTile(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Plan',
                        value: 'Coparentes',
                        isDark: isDark,
                        valueColor: const Color(0xFF6A1B9A),
                      ),
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.calendar_month_outlined,
                        label: 'Następne odnowienie',
                        value: '15 maja 2025',
                        isDark: isDark,
                      ),
                      SettingsDivider(),
                      InfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Kwota',
                        value: '39,99 PLN / miesiąc',
                        isDark: isDark,
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.receipt_long_outlined,
                        label: 'Historia płatności',
                        color: roleColor,
                        isDark: isDark,
                        onTap: () => _showBillingHistory(context, roleColor),
                      ),
                      SettingsDivider(),
                      ActionTile(
                        icon: Icons.credit_card_outlined,
                        label: 'Zmień metodę płatności',
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
                        label: 'Anuluj subskrypcję',
                        color: AppTheme.errorColor,
                        isDark: isDark,
                        onTap: () => _showCancelDialog(context, roleColor),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // ── Eksport danych ────────────────────────────────────────
                  SectionHeader(
                      label: 'Dane i eksport',
                      icon: Icons.folder_special_outlined),
                  SettingsCard(isDark: isDark, children: [
                    ActionTile(
                      icon: Icons.download_outlined,
                      label: 'Pobierz moje dane (RODO)',
                      subtitle: 'Wyślij wniosek e-mailem do supportu',
                      color: roleColor,
                      isDark: isDark,
                      onTap: () => _showRodoExportDialog(context, ap, roleColor),
                    ),
                    SettingsDivider(),
                    ActionTile(
                      icon: Icons.delete_outline,
                      label: 'Usuń konto',
                      subtitle: 'Nieodwracalne – wymaga potwierdzenia',
                      color: AppTheme.errorColor,
                      isDark: isDark,
                      onTap: () => _showDeleteDialog(context, ap, roleColor),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Aplikacja ─────────────────────────────────────────────
                  SectionHeader(
                      label: 'Aplikacja', icon: Icons.info_outline),
                  SettingsCard(isDark: isDark, children: [
                    InfoTile(
                      icon: Icons.apps_outlined,
                      label: 'Wersja aplikacji',
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
                        label: 'Regulamin',
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
                        label: 'Polityka prywatności (RODO)',
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
                        label: 'Pomoc i wsparcie',
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

                  const SizedBox(height: 24),

                  // ── Wyloguj ───────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Wyloguj się',
                          style: TextStyle(fontSize: 16)),
                      onPressed: () => _logout(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side:
                            const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Coparentes v1.0.0 · branding aligned\nCopyright © 2026 ${LegalConfig.companyName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
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

  String _roleBadge(UserRole? role) {
    switch (role) {
      case UserRole.parentA:
        return 'Parent A';
      case UserRole.parentB:
        return 'Parent B';
      case UserRole.child:
        return 'Child';
      case UserRole.observer:
        return 'Professional / Observer';
      default:
        return 'User';
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
        title: const Text('Wyloguj się'),
        content:
            const Text('Czy na pewno chcesz się wylogować z Coparentes?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj')),
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
            child: const Text('Wyloguj',
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
            for (final locale in const [
              Locale('pl'),
              Locale('en'),
              Locale('de'),
              Locale('fr'),
            ])
              ListTile(
                leading: Icon(Icons.language, color: color),
                title: Text(locale.languageCode.toUpperCase()),
                onTap: () {
                  ap.setLocale(locale);
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
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kod zaproszenia skopiowany: $inviteCode'),
        backgroundColor: color,
      ),
    );
  }

  void _showFeatureInfo(
      BuildContext context, String title, String msg, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg, style: const TextStyle(fontSize: 14)),
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

  void _showEmailInviteSheet(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EmailInviteSheet(color: color),
    );
  }

  Future<void> _togglePinOnResume(
    BuildContext context,
    AppProvider ap,
    bool enabled,
  ) async {
    final ok = await ap.setRequirePinOnResumeEnabled(enabled);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zmienić ustawienia PIN')),
      );
    }
  }

  Future<void> _showSetupPinSheet(
    BuildContext context,
    Color color,
    AppProvider ap, {
    bool enableOnResume = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SetupPinSheet(
        color: color,
        enableOnResume: enableOnResume,
      ),
    );
  }

  void _showChangePinDialog(
    BuildContext context,
    Color color,
    AppProvider ap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangePinSheet(
        color: color,
        hasExistingPin: ap.hasPinSet,
      ),
    );
  }

  void _showBillingHistory(BuildContext context, Color color) {
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
            const Text('Historia płatności',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _billingRow('15 kwi 2025', '39,99 PLN', 'Opłacona', color),
            _billingRow('15 mar 2025', '39,99 PLN', 'Opłacona', color),
            _billingRow('15 lut 2025', '39,99 PLN', 'Opłacona', color),
            _billingRow('15 sty 2025', '39,99 PLN', 'Opłacona', color),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zamknij'),
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
            child: Text(status,
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
        title: const Text('Anuluj subskrypcję'),
        content: const Text(
            'Czy na pewno chcesz anulować? Stracisz dostęp do wszystkich funkcji Pro po zakończeniu okresu rozliczeniowego (15 maja 2025).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nie, zachowaj')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Subskrypcja zostanie anulowana 15 maja 2025'),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            },
            child: const Text('Anuluj subskrypcję',
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
        title: const Text('Eksport danych RODO'),
        content: Text(
          'Wyślemy wniosek o kopię Twoich danych (art. 20 RODO) na adres '
          '${LegalConfig.supportEmail}. Odpowiemy na e-mail powiązany z kontem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
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
            child: const Text('Wyślij e-mail', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AppProvider ap, Color color) {
    final email = ap.currentUser?.email ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń konto'),
        content: const Text(
          'Ta operacja jest nieodwracalna. Aby usunąć konto, wyślij wniosek '
          'e-mailem do supportu. Potwierdzimy usunięcie danych po weryfikacji.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSupportMailto(
                subject: 'Wniosek o usunięcie konta — Coparentes',
                body: 'Proszę o trwałe usunięcie mojego konta Coparentes.\n\n'
                    'E-mail konta: $email\n',
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Wyślij wniosek e-mailem',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}







// ─── Shared sub-widgets ───────────────────────────────────────────────────────
