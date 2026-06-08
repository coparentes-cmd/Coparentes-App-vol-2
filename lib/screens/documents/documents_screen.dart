import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/documents_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_tab_scaffold.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<DocumentsProvider>();
      if (provider.documents.isEmpty && !provider.isLoading) {
        provider.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final documentsProvider = context.watch<DocumentsProvider>();
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final documents = _selectedCategory == 'All'
        ? documentsProvider.documents
        : documentsProvider.documents
            .where((document) => document.category == _selectedCategory)
            .toList();

    return ParentTabScaffold(
      title: 'Documents',
      actions: [
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: documentsProvider.isLoading
              ? null
              : () => _showUploadSheet(context, workspace),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => documentsProvider.load(),
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
                    'Family vault',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Store agreements, school files, medical documents and shared evidence-ready assets in one place.',
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
              children: ['All', 'Agreements', 'School', 'Medical', 'Shared']
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  )
                  .toList(),
            ),
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
                  'Brak dokumentów w tej kategorii. Dodaj pierwszy plik lub link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...documents.map(
                (document) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document.title),
                    subtitle: Text(
                      '${document.category} · ${document.childName ?? 'Rodzina'} · ${_formatRelative(document.updatedAt)}',
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

  Future<void> _showUploadSheet(BuildContext context, Workspace? workspace) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    var category = 'Agreements';
    String? childId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dodaj dokument',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tytuł',
                      hintText: 'np. Parenting agreement draft',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategoria'),
                    items: const [
                      DropdownMenuItem(value: 'Agreements', child: Text('Agreements')),
                      DropdownMenuItem(value: 'School', child: Text('School')),
                      DropdownMenuItem(value: 'Medical', child: Text('Medical')),
                      DropdownMenuItem(value: 'Shared', child: Text('Shared')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => category = value);
                      }
                    },
                  ),
                  if (workspace != null && workspace.children.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: childId,
                      decoration: const InputDecoration(labelText: 'Dziecko (opcjonalnie)'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Rodzina'),
                        ),
                        ...workspace.children.map(
                          (child) => DropdownMenuItem<String?>(
                            value: child.id,
                            child: Text(child.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() => childId = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Link do pliku (URL)',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final fileUrl = urlController.text.trim();
                        if (title.isEmpty || fileUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Podaj tytuł i link do pliku.'),
                            ),
                          );
                          return;
                        }

                        final created = await context
                            .read<DocumentsProvider>()
                            .uploadDocument(
                              title: title,
                              category: category,
                              childId: childId,
                              fileUrl: fileUrl,
                              fileName: title,
                            );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              created == null
                                  ? 'Nie udało się dodać dokumentu.'
                                  : 'Dokument dodany ✓',
                            ),
                            backgroundColor: created == null
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                          ),
                        );
                      },
                      child: const Text('Zapisz'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    titleController.dispose();
    urlController.dispose();
  }

  Future<void> _openDocument(BuildContext context, FamilyDocument document) async {
    if (document.fileUrl != null && document.fileUrl!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link: ${document.fileUrl}')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brak linku do tego dokumentu.')),
    );
  }

  String _formatRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    return 'today';
  }
}
