import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/exports_provider.dart';
import '../../utils/layout_utils.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/parent_tab_scaffold.dart';

class ExportsScreen extends StatefulWidget {
  const ExportsScreen({super.key});

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<ExportsProvider>();
      if (provider.jobs.isEmpty && !provider.isLoading) {
        provider.loadExports();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exportsProvider = context.watch<ExportsProvider>();

    return ParentTabScaffold(
      title: 'Eksporty',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // New export
            const Text(
              'Nowy eksport',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: gridCrossAxisCountFor(context),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: ExportType.values.map((type) {
                return _ExportTypeCard(
                  type: type,
                  onTap: () => _createExport(context, type),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // History
            const Text(
              'Historia eksportów',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (exportsProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (exportsProvider.jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Brak wygenerowanych eksportow.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...exportsProvider.jobs.map((job) => _ExportJobCard(job: job)),
          ],
        ),
      ),
    );
  }

  Future<void> _createExport(BuildContext context, ExportType type) async {
    final created = await showModalBottomSheet<ExportJob>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExportConfigSheet(type: type),
    );

    if (!context.mounted || created == null) return;

    final saved = await context.read<ExportsProvider>().saveExportAsPdf(created);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Pakiet "${created.typeLabel}" zapisany jako PDF.'
              : context.read<ExportsProvider>().error ??
                  'Eksport utworzony, ale nie udało się zapisać PDF.',
        ),
        backgroundColor: saved ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }
}

class _ExportTypeCard extends StatelessWidget {
  final ExportType type;
  final VoidCallback onTap;

  const _ExportTypeCard({required this.type, required this.onTap});

  Color get _color {
    switch (type) {
      case ExportType.messages:
        return AppTheme.primaryTeal;
      case ExportType.calendar:
        return AppTheme.parentBColor;
      case ExportType.finances:
        return AppTheme.successColor;
      case ExportType.fullPack:
        return AppTheme.highConflictColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.typeIcon, color: _color, size: 24),
              const SizedBox(height: 8),
              Text(
                type.typeLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
              if (type == ExportType.fullPack) ...[
                const SizedBox(height: 2),
                const Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportJobCard extends StatelessWidget {
  final ExportJob job;

  const _ExportJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    job.typeIcon,
                    color: AppTheme.primaryTeal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.typeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${job.fromDate.day}.${job.fromDate.month}.${job.fromDate.year} – ${job.toDate.day}.${job.toDate.month}.${job.toDate.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _ExportStatusChip(status: job.status),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                label: const Text(
                  'Pobierz PDF',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: job.status == 'completed'
                    ? () async {
                        final saved = await context
                            .read<ExportsProvider>()
                            .saveExportAsPdf(job);
                        if (!context.mounted) {
                          return;
                        }

                        final provider = context.read<ExportsProvider>();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              saved
                                  ? 'PDF zapisany na urządzeniu.'
                                  : provider.error ??
                                      'Nie udało się zapisać PDF.',
                            ),
                            backgroundColor: saved
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportStatusChip extends StatelessWidget {
  final String status;

  const _ExportStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: _label,
      color: _color,
    );
  }

  String get _label {
    switch (status) {
      case 'completed':
        return 'Gotowy';
      case 'queued':
        return 'W kolejce';
      case 'processing':
        return 'Generowanie';
      case 'failed':
        return 'Błąd';
      default:
        return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'queued':
      case 'processing':
        return AppTheme.warningColor;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _ExportConfigSheet extends StatefulWidget {
  final ExportType type;
  const _ExportConfigSheet({required this.type});

  @override
  State<_ExportConfigSheet> createState() => _ExportConfigSheetState();
}

class _ExportConfigSheetState extends State<_ExportConfigSheet> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now();
  bool _includeAttachments = true;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nowy eksport – ${widget.type.typeLabel}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Date range
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'Od',
                  date: _fromDate,
                  onChanged: (d) => setState(() => _fromDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerField(
                  label: 'Do',
                  date: _toDate,
                  onChanged: (d) => setState(() => _toDate = d),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Załącz pliki (paragony, dokumenty)'),
            value: _includeAttachments,
            onChanged: (v) => setState(() => _includeAttachments = v),
            activeThumbColor: AppTheme.primaryTeal,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.folder_special),
              label: Text(_isGenerating ? 'Generuję...' : 'Generuj eksport'),
              onPressed: _isGenerating ? null : _generate,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);

    final created = await context.read<ExportsProvider>().createExport(
          type: widget.type,
          fromDate: _fromDate,
          toDate: _toDate,
        );

    if (!mounted) {
      return;
    }

    setState(() => _isGenerating = false);
    Navigator.pop(context, created);
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}.${date.month}.${date.year}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
