import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_widgets.dart';
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
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

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
        body: BrandBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(width: 140, height: 46),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('Dodaj dziecko'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: BrandCard(
                        padding: const EdgeInsets.all(22),
                        child: _added == null
                            ? _buildForm(context)
                            : _buildAfterAdd(context),
                      ),
                    ),
                  ),
                  if (_added == null) ...[
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
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
                    ),
                    TextButton(
                      onPressed: _submitting ? null : _finish,
                      child: Text(context.tr('Zrobię to później')),
                    ),
                  ] else
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _finish,
                        child: Text(context.tr('Dalej')),
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

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: context.tr('Imię i nazwisko'),
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
          child: Text(
            context.tr(
              _showMore ? 'Ukryj dodatkowe informacje' : 'Dodaj więcej informacji',
            ),
          ),
        ),
        if (_showMore)
          TextField(
            controller: _schoolController,
            decoration: InputDecoration(labelText: context.tr('Szkoła')),
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
        SelectableText(
          code?.isNotEmpty == true ? code! : '—',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: code == null || code.isEmpty ? null : _copyChildCode,
          child: Text(context.tr('Kopiuj')),
        ),
      ],
    );
  }
}
