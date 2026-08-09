import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/messaging_categories.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../theme/app_theme.dart';

class NewThreadSheet extends StatefulWidget {
  const NewThreadSheet({super.key});

  @override
  State<NewThreadSheet> createState() => NewThreadSheetState();
}

class NewThreadSheetState extends State<NewThreadSheet> {
  final _subjectController = TextEditingController();
  String? _selectedChildId;
  bool _creating = false;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? const [];

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
          const Text(
            'Nowy wątek',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wątek pojawi się w zakładce $allTabDisplayLabel. Możesz oznaczać wiadomości '
            'prywatnymi etykietami (np. szkoła, zdrowie, finanse).',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            enabled: !_creating,
            decoration: const InputDecoration(
              labelText: 'Temat wątku',
              hintText: 'np. Angielski – zmiana terminu',
            ),
            onSubmitted: (_) => _createThread(),
          ),
          if (children.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedChildId ?? children.first.id,
              decoration: const InputDecoration(labelText: 'Dotyczy dziecka'),
              items: children
                  .map(
                    (child) => DropdownMenuItem(
                      value: child.id,
                      child: Text(child.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  _creating ? null : (value) => setState(() => _selectedChildId = value),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creating ? null : _createThread,
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Utwórz wątek'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createThread() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty || _creating) {
      return;
    }
    if (messagingCategoryChannels.contains(subject)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ten temat jest zarezerwowany dla kanału systemowego.',
          ),
        ),
      );
      return;
    }

    final workspace = context.read<AppProvider>().currentWorkspace;
    final children = workspace?.children ?? const [];
    final childId = children.isEmpty
        ? null
        : (_selectedChildId ?? children.first.id);

    setState(() => _creating = true);
    final app = context.read<AppProvider>();
    final thread = await context.read<MessagingProvider>().createThread(
          subject: subject,
          category: 'Ogólne',
          childId: childId,
          localOnly: app.isDemoMode,
        );
    if (!mounted) {
      return;
    }
    setState(() => _creating = false);

    if (thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się utworzyć wątku.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    Navigator.pop(context, thread);
  }
}
