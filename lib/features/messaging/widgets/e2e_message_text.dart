import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../providers/messaging_provider.dart';
import 'package:coparentes/l10n/app_strings.dart';

/// Renders [Message] body, decrypting E2E ciphertext when needed.
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
    if (!message.needsDecryption) {
      return Text(
        message.content,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final messaging = context.read<MessagingProvider>();
    return FutureBuilder<String>(
      future: messaging.decryptMessageBody(message),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Text('…', style: style, maxLines: maxLines, overflow: overflow);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            context.tr('Wiadomość niedostępna'),
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          );
        }
        return Text(
          snapshot.data!,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
