import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../data/api/app_api_client.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/exports_provider.dart';
import '../../../../providers/offline_sync_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/receipt_attachment_service.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/parent_tab_scaffold.dart';

import 'status_count_chip.dart';
import 'period_chip.dart';
import 'summary_card.dart';
import 'category_bar.dart';
import 'split_overview_card.dart';
import 'expense_card.dart';
import 'dispute_expense_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  final bool initialOcrMode;
  final ReceiptImageSource? autoLaunchSource;

  const AddExpenseSheet({
    this.initialOcrMode = false,
    this.autoLaunchSource,
  });

  @override
  State<AddExpenseSheet> createState() => AddExpenseSheetState();
}

class AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Szkoła';
  String? _selectedChildId;
  DateTime _selectedDate = DateTime.now();
  double _splitRatio = 0.5;
  late bool _ocrMode;
  PendingReceiptImage? _pendingReceipt;
  bool _isParsingReceipt = false;

  static const _categories = [
    'Szkoła',
    'Zdrowie',
    'Zajęcia',
    'Ubrania',
    'Jedzenie',
    'Transport',
    'Inne',
  ];

  static const _splitPresets = [
    (label: '50/50', ratio: 0.5),
    (label: '70/30', ratio: 0.7),
    (label: '80/20', ratio: 0.8),
    (label: '100/0', ratio: 1.0),
  ];

  @override
  void initState() {
    super.initState();
    _ocrMode = widget.initialOcrMode;
    if (widget.autoLaunchSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickAndParseReceipt(widget.autoLaunchSource!);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return 'Inne';
    if (_categories.contains(category)) return category;
    return 'Inne';
  }

  Future<void> _pickAndParseReceipt(ReceiptImageSource source) async {
    if (_isParsingReceipt) return;

    final app = context.read<AppProvider>();
    if (app.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR paragonu wymaga konta produkcyjnego (nie trybu demo).',
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      final picked = await ReceiptAttachmentPicker.pickReceiptImage(
        source: source,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _isParsingReceipt = true;
        _pendingReceipt = picked;
      });

      final parsed = await context.read<FinanceProvider>().parseReceipt(
        contentBase64: picked.contentBase64,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;

      setState(() {
        _ocrMode = false;
        _isParsingReceipt = false;
        if (parsed.title != null && parsed.title!.trim().isNotEmpty) {
          _titleController.text = parsed.title!.trim();
        }
        if (parsed.amount != null && parsed.amount! > 0) {
          _amountController.text = parsed.amount!.toStringAsFixed(2);
        }
        _selectedCategory = _normalizeCategory(parsed.category);
        if (parsed.date != null) {
          _selectedDate = parsed.date!;
        }
      });

      final confidenceLabel = parsed.confidence == 'medium'
          ? 'Rozpoznano dane z paragonu. Sprawdź przed zapisem.'
          : 'Rozpoznanie niepewne — uzupełnij brakujące pola ręcznie.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confidenceLabel),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isParsingReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_receiptParseErrorMessage(error)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _receiptParseErrorMessage(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is ApiException) {
      switch (error.message) {
        case 'receipt_invalid':
          return 'Nieobsługiwany format zdjęcia. Wybierz JPG lub PNG.';
        case 'receipt_unreadable':
          return 'Nie udało się odczytać tekstu z paragonu. Spróbuj jaśniejszego zdjęcia.';
        case 'receipt_too_large':
          return 'Zdjęcie jest za duże (max 512 KB). Zbliż paragon i spróbuj ponownie.';
        default:
          if (error.statusCode >= 500) {
            return 'Serwer OCR chwilowo niedostępny. Spróbuj za chwilę.';
          }
          return 'Nie udało się odczytać paragonu (${error.message}).';
      }
    }
    if (error is TimeoutException) {
      return 'OCR trwa zbyt długo. Spróbuj mniejszego zdjęcia lub poczekaj chwilę.';
    }
    return 'Nie udało się odczytać paragonu. Spróbuj jaśniejszego zdjęcia JPG.';
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? [];

    if (_selectedChildId == null && children.isNotEmpty) {
      _selectedChildId = children.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ocrMode ? 'Wydatek z paragonu' : 'Nowy wydatek',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            if (_ocrMode) ...[
              if (_pendingReceipt != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pendingReceipt!.bytes,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isParsingReceipt)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Odczytuję paragon…',
                        style: TextStyle(
                          color: AppTheme.primaryTeal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _pickAndParseReceipt(ReceiptImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Zrób zdjęcie aparatem'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _pickAndParseReceipt(ReceiptImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Dodaj załącznik'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Po zrobieniu zdjęcia odczytamy kwotę, sklep i datę z paragonu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ] else ...[
              if (_pendingReceipt != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pendingReceipt!.bytes,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paragon: ${_pendingReceipt!.fileName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Opis wydatku',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Kwota (PLN)',
                  suffixText: 'PLN',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data wydatku',
                  ),
                  child: Text(
                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                  ),
                ),
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Dziecko',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: children
                      .map(
                        (child) => ChoiceChip(
                          label: Text(
                            child.name.split(' ').first,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _selectedChildId == child.id,
                          onSelected: (_) =>
                              setState(() => _selectedChildId = child.id),
                          selectedColor:
                              AppTheme.primaryTeal.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryTeal,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Kategoria',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _categories
                    .map(
                      (cat) => ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryTeal,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Podział kosztów (udział drugiego rodzica)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _splitPresets
                    .map(
                      (preset) => ChoiceChip(
                        label: Text(
                          preset.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _splitRatio == preset.ratio,
                        onSelected: (_) =>
                            setState(() => _splitRatio = preset.ratio),
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.primaryTeal,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notatka (opcjonalnie)',
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (!_ocrMode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text('Zapisz wydatek'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (title.isEmpty || amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Uzupełnij poprawnie opis i kwotę wydatku.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final app = context.read<AppProvider>();
    final user = app.currentUser;
    final note = _noteController.text.trim();

    try {
      await context.read<FinanceProvider>().addExpense(
        Expense(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          amount: amount,
          category: _selectedCategory,
          childId: _selectedChildId,
          paidBy: user?.id ?? 'unknown',
          splitRatio: _splitRatio,
          date: _selectedDate,
          status: ExpenseStatus.pending,
          note: note.isEmpty ? null : note,
          hash: 'sha256_exp_${DateTime.now().millisecondsSinceEpoch}',
        ),
        receiptContentBase64: _pendingReceipt?.contentBase64,
        receiptMimeType: _pendingReceipt?.mimeType,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się zapisać wydatku.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _pendingReceipt != null
              ? 'Wydatek z paragonem zapisany. Oczekuje na akceptację drugiego rodzica.'
              : 'Wydatek zapisany. Oczekuje na akceptację drugiego rodzica.',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
