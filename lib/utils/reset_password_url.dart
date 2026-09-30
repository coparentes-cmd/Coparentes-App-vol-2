import 'package:flutter/foundation.dart';

/// Reads a password-reset token from a path-style deep link
/// (`/reset-password?token=...`). Returns null on non-web or when absent.
String? readResetPasswordTokenFromUrl() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  if (!uri.path.endsWith('/reset-password')) return null;
  final token = uri.queryParameters['token'];
  return (token != null && token.isNotEmpty) ? token : null;
}
