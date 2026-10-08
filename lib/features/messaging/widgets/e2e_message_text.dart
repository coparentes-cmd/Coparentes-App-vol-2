import 'package:flutter/material.dart';

import '../../../models/models.dart';

/// Renders message body. Client E2E decrypt is retired — [Message.content] only.
class E2eMessageText extends StatelessWidget {
  final Message message;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const E2eMessageText({
    super.key,
    required this.message,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message.content,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
