// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef BrowserBackHandler = bool Function();

final List<BrowserBackHandler> _handlers = <BrowserBackHandler>[];
bool _installed = false;
int _seq = 0;

void installAppBrowserBackHandling() {
  if (_installed) {
    return;
  }
  _installed = true;

  _pushSentinel('root');

  html.window.onPopState.listen((_) {
    var handled = false;
    // Newest (deepest) handler first — e.g. finance sub-tabs before dashboard tabs.
    for (final handler in _handlers.reversed) {
      try {
        if (handler()) {
          handled = true;
          break;
        }
      } catch (_) {
        // Keep trying other handlers; never let a throw leave the site.
      }
    }
    // Re-seed after a successful in-app back so the next Safari ← stays
    // inside the app instead of leaving the site.
    if (handled) {
      _pushSentinel('layer');
    }
  });
}

void registerBrowserBackHandler(BrowserBackHandler handler) {
  if (!_handlers.contains(handler)) {
    _handlers.add(handler);
  }
  // Re-seed after dashboard mounts so Flutter's own history setup cannot
  // leave us without a sentinel entry (common Safari failure mode).
  _pushSentinel('register');
}

void unregisterBrowserBackHandler(BrowserBackHandler handler) {
  _handlers.remove(handler);
}

void markBrowserHistoryForward() {
  _pushSentinel('layer');
}

void _pushSentinel(String kind) {
  _seq += 1;
  html.window.history.pushState(
    <String, dynamic>{'coparentes': kind, 'seq': _seq},
    '',
    html.window.location.href,
  );
}
