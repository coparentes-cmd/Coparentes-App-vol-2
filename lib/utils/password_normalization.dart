/// Password string used for bcrypt hashes and E2E private-key envelopes.
///
/// Existing accounts were created with passwords after this normalization
/// (strip whitespace / `-` / `_` / `.`). Do not remove or change the rule
/// without a password + envelope migration.
String normalizePassword(String raw) =>
    raw.replaceAll(RegExp(r'[\s\-_.]+'), '');

/// Matches backend `PASSWORD_MIN_LENGTH` (register / join / login / change).
const int kPasswordMinLength = 8;

String passwordTooShortMessage([int minLength = kPasswordMinLength]) =>
    'Hasło musi mieć min. $minLength znaków (bez spacji, myślników, podkreśleń i kropek)';

/// Returns an error message when [normalized] is shorter than [minLength], else null.
String? validateNormalizedPasswordLength(
  String normalized, {
  int minLength = kPasswordMinLength,
}) {
  if (normalized.length < minLength) {
    return passwordTooShortMessage(minLength);
  }
  return null;
}
