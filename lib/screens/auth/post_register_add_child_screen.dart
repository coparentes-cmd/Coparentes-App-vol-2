import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/mobile_onboarding_chrome.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

/// Mobile-only: add first child after invite (same API as Settings sheet).
class PostRegisterAddChildScreen extends StatefulWidget {
  const PostRegisterAddChildScreen({super.key});

  @override
  State<PostRegisterAddChildScreen> createState() =>
      _PostRegisterAddChildScreenState();
}

class _PostRegisterAddChildScreenState
    extends State<PostRegisterAddChildScreen> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _submitting = false;
  bool _showMore = false;
  ChildProfile? _added;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 8, 6, 1),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: context.tr('Data urodzenia'),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast(context.tr('Podaj imię i nazwisko dziecka.'));
      return;
    }
    if (_dateOfBirth == null) {
      _toast(context.tr('Wybierz datę urodzenia.'));
      return;
    }
    setState(() => _submitting = true);
    final school = _schoolController.text.trim();
    final ok = await context.read<AppProvider>().addWorkspaceChild(
          name: name,
          dateOfBirth: _dateOfBirth!,
          school: school.isEmpty ? null : school,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      _toast(
        context.read<AppProvider>().authError ??
            context.tr('Nie udało się dodać dziecka. Spróbuj ponownie.'),
      );
      return;
    }
    final children = context.read<AppProvider>().currentWorkspace?.children;
    setState(() {
      _added = children?.isNotEmpty == true ? children!.last : null;
    });
  }

  Future<void> _copyChildCode() async {
    final code = _added?.inviteCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _toast(context.tr('Skopiowano'));
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: MobileOnboarding.pageBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandLogo(width: 160, height: 44),
                const SizedBox(height: 20),
                Text(
                  context.tr('Dodaj dziecko'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Profil dziecka ułatwia wspólny kalendarz i czat.',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _added == null
                          ? _buildForm(context)
                          : _buildAfterAdd(context),
                    ),
                  ),
                ),
                if (_added == null) ...[
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: MobileOnboarding.primaryButton(
                      enabled: !_submitting,
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
                        : Text(context.tr('Dodaj dziecko')),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: MobileOnboarding.blue,
                    ),
                    child: Text(
                      context.tr('Zrobię to później'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: _finish,
                    style: MobileOnboarding.primaryButton(),
                    child: Text(context.tr('Dalej')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('Imię i nazwisko dziecka'),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Data urodzenia')),
          subtitle: Text(
            _dateOfBirth == null
                ? context.tr('Wybierz datę')
                : _formatDob(_dateOfBirth!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: _pickDob,
        ),
        TextButton(
          onPressed: () => setState(() => _showMore = !_showMore),
          style: TextButton.styleFrom(
            foregroundColor: MobileOnboarding.blue,
            alignment: Alignment.centerLeft,
          ),
          child: Text(
            context.tr(
              _showMore
                  ? 'Ukryj dodatkowe informacje'
                  : '+ Dodaj więcej informacji',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (_showMore)
          TextField(
            controller: _schoolController,
            decoration: InputDecoration(labelText: context.tr('Szkoła')),
          ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Po dodaniu: kod dla dziecka (nie wysyłaj go drugiemu rodzicowi).',
          ),
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildAfterAdd(BuildContext context) {
    final code = _added?.inviteCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(
            'Kod dla dziecka (nie wysyłaj go drugiemu rodzicowi)',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        OnboardingDashedCodeBox(code: code?.isNotEmpty == true ? code! : '—'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: code == null || code.isEmpty ? null : _copyChildCode,
          style: MobileOnboarding.outlineButton(),
          child: Text(context.tr('Kopiuj')),
        ),
      ],
    );
  }
}
