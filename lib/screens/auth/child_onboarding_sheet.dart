import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal_config.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';

Future<void> showChildOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const ChildOnboardingSheet(),
  );
}

String _formatDob(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

class ChildOnboardingSheet extends StatefulWidget {
  const ChildOnboardingSheet({super.key});

  @override
  State<ChildOnboardingSheet> createState() => _ChildOnboardingSheetState();
}

class _ChildOnboardingSheetState extends State<ChildOnboardingSheet> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _submitting = false;
  bool _showForm = true;
  ChildProfile? _lastAdded;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 8, 6, 1),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Data urodzenia dziecka (DD-MM-RRRR)',
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<bool> _submitChild() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _showMessage('Podaj imię i nazwisko dziecka.');
      return false;
    }
    if (_dateOfBirth == null) {
      _showMessage('Wybierz datę urodzenia w kalendarzu.');
      return false;
    }

    setState(() => _submitting = true);

    final success = await context.read<AppProvider>().addWorkspaceChild(
          name: name,
          dateOfBirth: _dateOfBirth!,
          school: _schoolController.text.trim().isEmpty
              ? null
              : _schoolController.text.trim(),
        );

    if (!mounted) {
      return false;
    }

    setState(() => _submitting = false);

    if (!success) {
      final error = context.read<AppProvider>().authError;
      _showMessage(error ?? 'Nie udało się dodać dziecka.');
      return false;
    }

    final children = context.read<AppProvider>().currentWorkspace?.children ?? [];
    final added = children.cast<ChildProfile?>().firstWhere(
          (c) =>
              c != null &&
              c.name == name &&
              c.dateOfBirth.year == _dateOfBirth!.year &&
              c.dateOfBirth.month == _dateOfBirth!.month &&
              c.dateOfBirth.day == _dateOfBirth!.day,
          orElse: () => children.isNotEmpty ? children.last : null,
        );

    setState(() {
      _lastAdded = added;
      _showForm = false;
      _nameController.clear();
      _schoolController.clear();
      _dateOfBirth = null;
    });
    return true;
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    _showMessage('Skopiowano kod zaproszenia.');
  }

  Future<void> _sendCode(ChildProfile child) async {
    final code = child.inviteCode;
    if (code == null || code.isEmpty) {
      _showMessage('Brak kodu zaproszenia. Odśwież ustawienia.');
      return;
    }
    final appUrl = LegalConfig.websiteUrl;
    final bodyText =
        'Zaproszenie do Coparentes dla ${child.name}.\n\n'
        'Kod: $code\n'
        'Aplikacja: $appUrl\n\n'
        '1. Otwórz aplikację\n'
        '2. Dołączanie → Jako dziecko\n'
        '3. Wpisz kod, datę urodzenia (${_formatDob(child.dateOfBirth)}) i ustaw hasło.';
    await Clipboard.setData(ClipboardData(text: bodyText));
    final subject = Uri.encodeComponent('Zaproszenie do Coparentes');
    final body = Uri.encodeComponent(bodyText);
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication)
          .timeout(const Duration(seconds: 2), onTimeout: () => false)
          .catchError((_) => false),
    );
    if (!mounted) {
      return;
    }
    _showMessage(
      'Tekst z kodem skopiowany. Otwórz e-mail lub wklej go w wiadomości.',
    );
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final children =
        context.watch<AppProvider>().currentWorkspace?.children ?? const [];

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Dodaj dziecko do przestrzeni'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Po dodaniu dostaniesz osobny kod zaproszenia dla tego dziecka.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.tr('Dzieci w rodzinie'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...children.map((child) => _ChildInviteCard(
                    child: child,
                    highlight: _lastAdded?.id == child.id,
                    onCopy: () => _copyCode(child.inviteCode ?? ''),
                    onSend: () => _sendCode(child),
                  )),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _showForm = true;
                            _lastAdded = null;
                          }),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Dodaj kolejne dziecko')),
                ),
              ),
            ],
            if (_showForm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.tr('Imię i nazwisko dziecka'),
                  hintText: 'np. Zosia Kowalska',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _submitting ? null : _pickDateOfBirth,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('Data urodzenia'),
                    hintText: 'DD-MM-RRRR',
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? context.tr('Wybierz datę w kalendarzu')
                        : _formatDob(_dateOfBirth!),
                    style: TextStyle(
                      color: _dateOfBirth == null
                          ? AppTheme.textHint
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _schoolController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Szkoła (opcjonalnie)'),
                  hintText: 'np. SP nr 15 w Warszawie',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            await _submitChild();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
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
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting ? null : _finish,
                child: Text(
                  children.isEmpty
                      ? context.tr('Pomiń na razie')
                      : context.tr('Gotowe'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildInviteCard extends StatelessWidget {
  final ChildProfile child;
  final bool highlight;
  final VoidCallback onCopy;
  final VoidCallback onSend;

  const _ChildInviteCard({
    required this.child,
    required this.highlight,
    required this.onCopy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final code = child.inviteCode ?? '—';
    final status = child.linkedAccountId != null
        ? context.tr('Dołączyło')
        : context.tr('Oczekuje na dołączenie');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.childColor.withValues(alpha: 0.12)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppTheme.childColor.withValues(alpha: 0.4)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            child.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatDob(child.dateOfBirth)} · $status',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (child.inviteCode != null && child.inviteCode!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              code,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.tr('Kopiuj')),
                ),
                TextButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: Text(context.tr('Wyślij')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
