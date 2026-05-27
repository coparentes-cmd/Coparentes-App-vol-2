import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

Future<void> showChildOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const ChildOnboardingSheet(),
  );
}

class ChildOnboardingSheet extends StatefulWidget {
  const ChildOnboardingSheet({super.key});

  @override
  State<ChildOnboardingSheet> createState() => _ChildOnboardingSheetState();
}

class _ChildOnboardingSheetState extends State<ChildOnboardingSheet> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  DateTime _dateOfBirth = DateTime(DateTime.now().year - 8, 6, 1);
  bool _submitting = false;
  int _addedCount = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(DateTime.now().year - 25),
      lastDate: DateTime.now(),
      helpText: 'Data urodzenia dziecka',
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

    setState(() => _submitting = true);

    final success = await context.read<AppProvider>().addWorkspaceChild(
          name: name,
          dateOfBirth: _dateOfBirth,
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

    setState(() {
      _addedCount += 1;
      _nameController.clear();
      _schoolController.clear();
      _dateOfBirth = DateTime(DateTime.now().year - 8, 6, 1);
    });
    return true;
  }

  void _finish() {
    context.read<AppProvider>().completeChildOnboarding();
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dodaj dziecko do przestrzeni',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _addedCount == 0
                ? 'Profil dziecka ułatwi wątki, kalendarz i rozliczenia. Możesz pominąć ten krok i dodać dziecko później.'
                : 'Dodano $_addedCount ${_addedCount == 1 ? 'dziecko' : 'dzieci'}. Dodaj kolejne lub przejdź dalej.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Imię i nazwisko dziecka',
              hintText: 'np. Zosia Kowalska',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _submitting ? null : _pickDateOfBirth,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data urodzenia',
              ),
              child: Text(
                '${_dateOfBirth.day.toString().padLeft(2, '0')}.'
                '${_dateOfBirth.month.toString().padLeft(2, '0')}.'
                '${_dateOfBirth.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _schoolController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Szkoła (opcjonalnie)',
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
                        final added = await _submitChild();
                        if (added && mounted && _addedCount > 0) {
                          _showMessage('Dodano dziecko.');
                        }
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
                    : Text(_addedCount == 0 ? 'Dodaj dziecko' : 'Dodaj kolejne dziecko'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _submitting ? null : _finish,
              child: Text(_addedCount == 0 ? 'Pomiń na razie' : 'Gotowe'),
            ),
          ),
        ],
      ),
    );
  }
}
