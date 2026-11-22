import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_normalization.dart';
import '../../widgets/brand_widgets.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'package:coparentes/utils/app_snackbar.dart';

/// Mobile-only parent-B join: code → account → welcome (no consents — API has none).
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
  bool _submitting = false;

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
    final lengthError = validateNormalizedPasswordLength(password);
    if (lengthError != null) {
      _toast(lengthError);
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
      appBar: AppBar(
        title: Text(context.tr('Dołączanie')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else if (_step == 0) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: BrandBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: BrandCard(
                      padding: const EdgeInsets.all(22),
                      child: _buildStep(context),
                    ),
                  ),
                ),
                if (_step < 2)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting
                          ? null
                          : (_step == 0 ? _goCodeNext : _join),
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
                    ),
                  )
                else
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _finish,
                      child: Text(context.tr('Zaczynamy')),
                    ),
                  ),
              ],
            ),
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.tr('Kod zaproszenia'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Nie masz kodu? Poproś drugiego rodzica, znajdzie go w Ustawieniach.',
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
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
              ),
            ),
          ],
        );
      default:
        final ws = context.watch<AppProvider>().currentWorkspace;
        final childName = ws?.children.isNotEmpty == true
            ? ws!.children.first.name
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Gotowe, jesteś we wspólnej przestrzeni.'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              childName ??
                  context.tr(
                    'Dziecko pojawi się tutaj, gdy drugi rodzic je doda.',
                  ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Kalendarz i czat są gotowe do użycia.'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        );
    }
  }
}
