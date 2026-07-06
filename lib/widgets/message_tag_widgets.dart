import 'package:flutter/material.dart';

import '../config/message_tags.dart';
import '../theme/app_theme.dart';

class MessageTagChip extends StatelessWidget {
  final String tag;
  final VoidCallback? onTap;
  final bool compact;

  const MessageTagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = messageTagColor(tag);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        messageTagDisplayLabel(tag),
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

class MessageTagFilterBar extends StatelessWidget {
  final Set<String> activeTags;
  final Set<String> userTags;
  final ValueChanged<String> onTagTap;

  const MessageTagFilterBar({
    super.key,
    required this.activeTags,
    required this.userTags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = sortedMessageTags({
      ...suggestedMessageTags,
      ...userTags,
    });

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = tags[index];
          final selected = activeTags.contains(tag);
          final color = messageTagColor(tag);

          return FilterChip(
            label: Text(
              messageTagDisplayLabel(tag),
              style: TextStyle(
                fontSize: 12,
                color: selected ? color : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            selected: selected,
            showCheckmark: true,
            checkmarkColor: color,
            selectedColor: color.withValues(alpha: 0.14),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? color.withValues(alpha: 0.45) : AppTheme.dividerColor,
            ),
            onSelected: (_) => onTagTap(tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class MessageTagEditorSheet extends StatefulWidget {
  final List<String> initialTags;
  final List<String> customSuggestions;

  const MessageTagEditorSheet({
    super.key,
    required this.initialTags,
    this.customSuggestions = const [],
  });

  @override
  State<MessageTagEditorSheet> createState() => _MessageTagEditorSheetState();
}

class _MessageTagEditorSheetState extends State<MessageTagEditorSheet> {
  late final TextEditingController _controller;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = sortedMessageTags(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTag(String raw) {
    final tag = normalizeMessageTag(raw);
    if (tag.isEmpty) {
      return;
    }
    setState(() {
      if (_tags.contains(tag)) {
        _tags = _tags.where((item) => item != tag).toList();
      } else {
        _tags = sortedMessageTags([..._tags, tag]);
      }
    });
  }

  void _addCustomTag(String raw) {
    final tag = normalizeMessageTag(raw);
    if (tag.isEmpty || _tags.contains(tag)) {
      return;
    }
    setState(() {
      _tags = sortedMessageTags([..._tags, tag]);
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final customSuggestions = customMessageTags(widget.customSuggestions)
        .where((tag) => !_tags.contains(tag))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Etykiety',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prywatne — widzisz je tylko Ty. Inni rodzice mogą mieć własne etykiety '
            'na tej samej wiadomości. Szukaj: tag:szkoła',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sugerowane',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestedMessageTags
                .map(
                  (tag) => _SuggestedTagToggle(
                    tag: tag,
                    selected: _tags.contains(tag),
                    onTap: () => _toggleTag(tag),
                  ),
                )
                .toList(),
          ),
          if (_tags.any((tag) => !isSuggestedMessageTag(tag))) ...[
            const SizedBox(height: 16),
            const Text(
              'Twoje etykiety na tej wiadomości',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .where((tag) => !isSuggestedMessageTag(tag))
                  .map(
                    (tag) => InputChip(
                      label: Text(messageTagDisplayLabel(tag)),
                      deleteIconColor: messageTagColor(tag),
                      labelStyle: TextStyle(
                        color: messageTagColor(tag),
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor:
                          messageTagColor(tag).withValues(alpha: 0.1),
                      onDeleted: () => _toggleTag(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Utwórz własną etykietę',
              hintText: 'np. paragon, pilne',
              prefixIcon: const Icon(Icons.new_label_outlined, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Dodaj etykietę',
                onPressed: () => _addCustomTag(_controller.text),
              ),
            ),
            onSubmitted: _addCustomTag,
          ),
          if (customSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Ostatnio używane',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customSuggestions
                  .take(8)
                  .map(
                    (tag) => ActionChip(
                      avatar: Icon(
                        Icons.label_outline,
                        size: 16,
                        color: messageTagColor(tag),
                      ),
                      label: Text(messageTagDisplayLabel(tag)),
                      onPressed: () => _toggleTag(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _tags),
                child: const Text('Zastosuj'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestedTagToggle extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback onTap;

  const _SuggestedTagToggle({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = messageTagColor(tag);

    return FilterChip(
      label: Text(messageTagDisplayLabel(tag)),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: color,
      selectedColor: color.withValues(alpha: 0.16),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.5) : AppTheme.dividerColor,
      ),
      avatar: Icon(
        selected ? Icons.label : Icons.label_outline,
        size: 18,
        color: color,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
