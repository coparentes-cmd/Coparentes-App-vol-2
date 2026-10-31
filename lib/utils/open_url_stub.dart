import 'package:url_launcher/url_launcher.dart';

/// Mobile / desktop: open https links in the system browser.
void openUrlImpl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  if (uri.scheme != 'http' && uri.scheme != 'https') return;
  // Fire-and-forget; callers use a sync void API shared with web.
  launchUrl(uri, mode: LaunchMode.externalApplication);
}
