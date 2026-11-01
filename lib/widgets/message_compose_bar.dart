import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../services/message_attachment_service.dart';
import '../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';

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
  static const double _emojiPickerHeight = 256;

  final FocusNode _focusNode = FocusNode();
  int _hintIndex = 0;
  Timer? _hintTimer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _emojiShowing = false;

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
    _focusNode.addListener(_onFocusChanged);
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
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

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _emojiShowing) {
      setState(() => _emojiShowing = false);
    }
  }

  void _toggleEmojiPicker() {
    if (_emojiShowing) {
      setState(() => _emojiShowing = false);
      _focusNode.requestFocus();
      return;
    }
    _focusNode.unfocus();
    setState(() => _emojiShowing = true);
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
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold already shrinks for the keyboard — do NOT re-add viewInsets
    // (that left a large empty gap and pushed the send button off-screen on
    // mobile Safari). Home-indicator is handled by the parent tab bar.
    const bottomPad = 10.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, bottomPad),
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
                        onDeleted: () =>
                            widget.onRemoveAttachment(attachment.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ComposeIconButton(
                tooltip: context.tr('Dodaj załącznik'),
                icon: Icons.add_circle_outline,
                color: widget.pendingAttachments.length >=
                        maxMessageAttachmentsPerMessage
                    ? AppTheme.textHint
                    : AppTheme.textSecondary,
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
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: _showCyclingPlaceholder ? 2 : 1,
                        textAlignVertical: TextAlignVertical.top,
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
                          hintText:
                              _showCyclingPlaceholder ? null : 'Wiadomość',
                          hintStyle:
                              const TextStyle(color: AppTheme.textHint),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(14, 10, 40, 10),
                          isDense: true,
                        ),
                        onChanged: widget.onChanged,
                      ),
                      if (_showCyclingPlaceholder)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 40, 10),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: FadeTransition(
                                  opacity: _fadeAnim,
                                  child: Text(
                                    _currentPlaceholder,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.3,
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
                      Positioned(
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: _ComposeIconButton(
                          tooltip: context.tr('Emoji'),
                          icon: _emojiShowing
                              ? Icons.keyboard_outlined
                              : Icons.emoji_emotions_outlined,
                          color: _emojiShowing
                              ? AppTheme.primaryTeal
                              : AppTheme.textSecondary,
                          iconSize: 22,
                          onPressed: _toggleEmojiPicker,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (widget.sending)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                // Always reserve the send control so it cannot "escape" the row.
                Material(
                  color: _canSend
                      ? AppTheme.primaryTeal
                      : const Color(0xFFD1D5DB),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _canSend ? widget.onSend : null,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _canSend
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_emojiShowing)
            SizedBox(
              height: _emojiPickerHeight,
              child: EmojiPicker(
                textEditingController: widget.controller,
                onBackspacePressed: () {
                  setState(() {});
                },
                config: Config(
                  height: _emojiPickerHeight,
                  checkPlatformCompatibility: true,
                  locale: const Locale('en'),
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: const Color(0xFFF7F7F9),
                    emojiSizeMax: 28 *
                        (foundation.defaultTargetPlatform ==
                                TargetPlatform.iOS
                            ? 1.20
                            : 1.0),
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    initCategory: Category.SMILEYS,
                    backgroundColor: Color(0xFFF7F7F9),
                    indicatorColor: AppTheme.primaryTeal,
                    iconColorSelected: AppTheme.primaryTeal,
                    backspaceColor: AppTheme.primaryTeal,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    backgroundColor: AppTheme.primaryTeal,
                    buttonIconColor: Colors.white,
                  ),
                  searchViewConfig: const SearchViewConfig(
                    backgroundColor: Color(0xFFF7F7F9),
                    buttonIconColor: AppTheme.textSecondary,
                    hintText: 'Search emoji',
                  ),
                  skinToneConfig: const SkinToneConfig(
                    indicatorColor: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact tap target that does not inflate past ~36px (default IconButton is 48).
class _ComposeIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double iconSize;

  const _ComposeIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.iconSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}
