import 'dart:async';

import 'package:flutter/material.dart';

import '../services/message_attachment_service.dart';
import '../theme/app_theme.dart';

class MessageComposeBar extends StatefulWidget {
  final TextEditingController controller;
  final List<PendingMessageAttachment> pendingAttachments;
  final VoidCallback onPickAttachment;
  final ValueChanged<String> onRemoveAttachment;
  final VoidCallback? onSend;
  final bool sending;
  final ValueChanged<String>? onChanged;
  final List<String>? cyclingPlaceholderHints;
  final int cyclingIntervalSeconds;

  const MessageComposeBar({
    super.key,
    required this.controller,
    required this.pendingAttachments,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onSend,
    this.sending = false,
    this.onChanged,
    this.cyclingPlaceholderHints,
    this.cyclingIntervalSeconds = 7,
  });

  @override
  State<MessageComposeBar> createState() => _MessageComposeBarState();
}

class _MessageComposeBarState extends State<MessageComposeBar>
    with SingleTickerProviderStateMixin {
  int _hintIndex = 0;
  Timer? _hintTimer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool get _canSend =>
      !widget.sending &&
      (widget.controller.text.trim().isNotEmpty ||
          widget.pendingAttachments.isNotEmpty);

  bool get _showCyclingPlaceholder =>
      widget.cyclingPlaceholderHints != null &&
      widget.cyclingPlaceholderHints!.isNotEmpty &&
      widget.controller.text.isEmpty;

  String get _currentPlaceholder {
    final hints = widget.cyclingPlaceholderHints;
    if (hints == null || hints.isEmpty) {
      return 'Wiadomość';
    }
    return hints[_hintIndex % hints.length];
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _startHintTimer();
  }

  @override
  void didUpdateWidget(MessageComposeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cyclingPlaceholderHints != widget.cyclingPlaceholderHints ||
        oldWidget.cyclingIntervalSeconds != widget.cyclingIntervalSeconds) {
      _hintTimer?.cancel();
      _hintIndex = 0;
      _fadeCtrl.value = 1;
      _startHintTimer();
    }
  }

  void _startHintTimer() {
    final hints = widget.cyclingPlaceholderHints;
    if (hints == null || hints.length <= 1) {
      return;
    }
    _hintTimer = Timer.periodic(
      Duration(seconds: widget.cyclingIntervalSeconds),
      (_) => unawaited(_nextHint()),
    );
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _nextHint() async {
    if (!mounted || !_showCyclingPlaceholder) {
      return;
    }
    await _fadeCtrl.reverse();
    if (!mounted) {
      return;
    }
    setState(() {
      _hintIndex =
          (_hintIndex + 1) % widget.cyclingPlaceholderHints!.length;
    });
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _fadeCtrl.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset > 0 ? bottomInset + 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pendingAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.pendingAttachments
                    .map(
                      (attachment) => InputChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          '${attachment.name} (${formatAttachmentSize(attachment.sizeBytes)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => widget.onRemoveAttachment(attachment.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 28,
                  color: widget.pendingAttachments.length >=
                          maxMessageAttachmentsPerMessage
                      ? AppTheme.textHint
                      : AppTheme.textSecondary,
                ),
                tooltip: 'Dodaj załącznik',
                onPressed: widget.pendingAttachments.length >=
                        maxMessageAttachmentsPerMessage
                    ? null
                    : widget.onPickAttachment,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF4),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE0E0E5)),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: widget.controller,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (_canSend) {
                            widget.onSend?.call();
                          }
                        },
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: _showCyclingPlaceholder ? null : 'Wiadomość',
                          hintStyle: const TextStyle(color: AppTheme.textHint),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: widget.onChanged,
                      ),
                      if (_showCyclingPlaceholder)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FadeTransition(
                                  opacity: _fadeAnim,
                                  child: Text(
                                    _currentPlaceholder,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.35,
                                      color: AppTheme.textHint,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (widget.sending)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_canSend)
                Material(
                  color: AppTheme.primaryTeal,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onSend,
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 34, height: 34),
            ],
          ),
        ],
      ),
    );
  }
}
