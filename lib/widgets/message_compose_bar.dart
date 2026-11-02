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
  static const double _sideBtn = 32;

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
    // Scaffold owns keyboard insets. Side safe-area keeps the send control
    // inside the visible phone width (iOS Safari notch / home indicator).
    final safe = MediaQuery.paddingOf(context);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 0.5, thickness: 0.5, color: AppTheme.dividerColor),
          Padding(
            padding: EdgeInsets.fromLTRB(
              8 + safe.left,
              8,
              8 + safe.right,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.pendingAttachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                // Single full-width row: [+] [ pill with field + emoji + send ]
                // Send lives INSIDE the pill so it cannot clip off-screen.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ComposeTapIcon(
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
                    const SizedBox(width: 4),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFF4),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE0E0E5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    TextField(
                                      controller: widget.controller,
                                      focusNode: _focusNode,
                                      maxLines: 5,
                                      minLines:
                                          _showCyclingPlaceholder ? 2 : 1,
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
                                        hintText: _showCyclingPlaceholder
                                            ? null
                                            : 'Wiadomość',
                                        hintStyle: const TextStyle(
                                          color: AppTheme.textHint,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
                                          10,
                                          8,
                                          4,
                                          8,
                                        ),
                                        isDense: true,
                                      ),
                                      onChanged: widget.onChanged,
                                    ),
                                    if (_showCyclingPlaceholder)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              8,
                                              4,
                                              8,
                                            ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _ComposeTapIcon(
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
                              const SizedBox(width: 2),
                              if (widget.sending)
                                const SizedBox(
                                  width: _sideBtn,
                                  height: _sideBtn,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Material(
                                  color: _canSend
                                      ? AppTheme.primaryTeal
                                      : const Color(0xFFD1D5DB),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _canSend ? widget.onSend : null,
                                    child: SizedBox(
                                      width: _sideBtn,
                                      height: _sideBtn,
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        color: _canSend
                                            ? Colors.white
                                            : const Color(0xFF9CA3AF),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

/// Fixed 32×32 tap target — avoids IconButton's default 48px min size on web.
class _ComposeTapIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double iconSize;

  const _ComposeTapIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: _MessageComposeBarState._sideBtn,
        height: _MessageComposeBarState._sideBtn,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}
