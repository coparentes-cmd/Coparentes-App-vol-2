import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/documents_provider.dart';
import '../../services/document_attachment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/file_download.dart';
import '../../widgets/parent_tab_scaffold.dart';

const _allCategoriesFilter = 'All';

const _documentCategoryValues = [
  'All',
  'Agreements',
  'School',
  'Medical',
  'Shared',
  'Private',
];

String _documentCategoryLabel(String category) {
  switch (category) {
    case 'All':
      return 'Wszystkie';
    case 'Agreements':
      return 'Umowy';
    case 'School':
      return 'Szkoła';
    case 'Medical':
      return 'Medyczne';
    case 'Shared':
      return 'Wspólne';
    case 'Private':
      return 'Prywatne';
    default:
      return category;
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategory = _allCategoriesFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DocumentsProvider>();
      final viewerUserId = context.read<AppProvider>().currentUser?.id;
      if (provider.documents.isEmpty && !provider.isLoading) {
        provider.load(viewerUserId: viewerUserId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final documentsProvider = context.watch<DocumentsProvider>();
    final viewerUserId = context.watch<AppProvider>().currentUser?.id;
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final documents = _selectedCategory == _allCategoriesFilter
        ? documentsProvider.documents
        : documentsProvider.documents
            .where((document) => document.category == _selectedCategory)
            .toList();

    return ParentTabScaffold(
      title: 'Dokumenty',
      actions: [
        ParentHeaderActionButton(
          label: 'Dodaj dokument',
          icon: Icons.add,
          backgroundColor: AppTheme.purpleColor,
          prominent: true,
          onPressed: documentsProvider.isLoading
              ? null
              : () => _showUploadSheet(context, workspace, viewerUserId),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => documentsProvider.load(viewerUserId: viewerUserId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sejf rodzinny',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Przechowuj umowy, dokumenty szkolne, medyczne i wspólne pliki — w jednym miejscu.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (documentsProvider.error != null) ...[
              const SizedBox(height: 12),
              Text(
                documentsProvider.error!,
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _documentCategoryValues
                  .map(
                    (category) => ChoiceChip(
                      label: Text(_documentCategoryLabel(category)),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_selectedCategory == FamilyDocument.privateCategory) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.purpleColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.purpleColor.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: AppTheme.purpleColor),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dokumenty prywatne widzi tylko osoba, która je dodała.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (documentsProvider.isLoading && documents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (documents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Brak dokumentów w tej kategorii. Dodaj pierwszy plik.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...documents.map(
                (document) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      document.isPrivate
                          ? Icons.lock_outline
                          : Icons.description_outlined,
                      color: document.isPrivate
                          ? AppTheme.purpleColor
                          : AppTheme.textSecondary,
                    ),
                    title: Text(document.title),
                    subtitle: Text(
                      '${_documentCategoryLabel(document.category)} · ${document.childName ?? 'Rodzina'} · ${_formatRelative(document.updatedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDocument(context, document),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showUploadSheet(
    BuildContext context,
    Workspace? workspace,
    String? viewerUserId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDocumentSheet(
        workspace: workspace,
        viewerUserId: viewerUserId,
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, FamilyDocument document) async {
    if (document.fileUrl != null && document.fileUrl!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link: ${document.fileUrl}')),
      );
      return;
    }

    if (!document.hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak pliku do tego dokumentu.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pobieram dokument…')),
    );

    final payload =
        await context.read<DocumentsProvider>().downloadDocument(document.id);
    if (!context.mounted) {
      return;
    }

    if (payload == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się pobrać dokumentu.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final contentBase64 = payload['contentBase64'] as String?;
    if (contentBase64 == null || contentBase64.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Brak danych pliku.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      await saveBytesAsFile(
        fileName: payload['fileName'] as String? ??
            document.fileName ??
            document.title,
        mimeType: payload['mimeType'] as String? ??
            document.mimeType ??
            'application/octet-stream',
        bytes: decodeDocumentBase64(contentBase64),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? '1 dzień temu' : '${diff.inDays} dni temu';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? '1 godz. temu' : '${diff.inHours} godz. temu';
    }
    return 'dziś';
  }
}

class _AddDocumentSheet extends StatefulWidget {
  final Workspace? workspace;
  final String? viewerUserId;

  const _AddDocumentSheet({
    this.workspace,
    this.viewerUserId,
  });

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  final _titleController = TextEditingController();
  PendingDocumentAttachment? _pendingFile;
  var _category = 'Agreements';
  String? _childId;
  bool _isPicking = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(DocumentCaptureSource source) async {
    if (_isPicking) {
      return;
    }

    setState(() => _isPicking = true);
    try {
      final picked = await DocumentAttachmentPicker.pick(source: source);
      if (!mounted || picked == null) {
        return;
      }

      setState(() {
        _pendingFile = picked;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = defaultDocumentTitleFromFileName(picked.fileName);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _save() async {
    if (_pendingFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw dodaj zdjęcie lub plik.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj tytuł dokumentu.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final created = await context.read<DocumentsProvider>().uploadDocument(
          title: title,
          category: _category,
          childId: _childId,
          fileName: _pendingFile!.fileName,
          mimeType: _pendingFile!.mimeType,
          contentBase64: _pendingFile!.contentBase64,
          uploadedById: widget.viewerUserId,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == null
              ? 'Nie udało się dodać dokumentu.'
              : 'Dokument zapisany ✓',
        ),
        backgroundColor:
            created == null ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dodaj dokument',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_pendingFile == null) ...[
              if (_isPicking)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickFile(DocumentCaptureSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Zrób zdjęcie aparatem'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFile(DocumentCaptureSource.file),
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Dodaj plik'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Obsługiwane formaty: JPG, PNG, PDF, DOC, DOCX, TXT (max 5 MB).',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ] else ...[
              if (_pendingFile!.isImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pendingFile!.bytes,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        color: AppTheme.primaryTeal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pendingFile!.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextButton.icon(
                onPressed: _isSaving ? null : () => setState(() => _pendingFile = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Wybierz inny plik'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł',
                  hintText: 'np. Projekt umowy wychowawczej',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategoria'),
                items: _documentCategoryValues
                    .where((value) => value != _allCategoriesFilter)
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_documentCategoryLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              if (widget.workspace != null &&
                  widget.workspace!.children.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _childId,
                  decoration:
                      const InputDecoration(labelText: 'Dziecko (opcjonalnie)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Rodzina'),
                    ),
                    ...widget.workspace!.children.map(
                      (child) => DropdownMenuItem<String?>(
                        value: child.id,
                        child: Text(child.name),
                      ),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _childId = value),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zapisz dokument'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
