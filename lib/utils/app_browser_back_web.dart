// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef BrowserBackHandler = bool Function();

final List<BrowserBackHandler> _handlers = <BrowserBackHandler>[];
bool _installed = false;

void installAppBrowserBackHandling() {
  if (_installed) {
    return;
  }
  _installed = true;

  _pushSentinel('root');

  html.window.onPopState.listen((_) {
    var handled = false;
    for (final handler in _handlers.reversed) {
      if (handler()) {
        handled = true;
        break;
      }
    }
    // Re-seed a history entry after a successful in-app back so the next
    // browser ← still stays inside the app instead of leaving the site.
    if (handled) {
      _pushSentinel('layer');
    }
  });
}

void registerBrowserBackHandler(BrowserBackHandler handler) {
  if (!_handlers.contains(handler)) {
    _handlers.add(handler);
  }
}

void unregisterBrowserBackHandler(BrowserBackHandler handler) {
  _handlers.remove(handler);
}

void markBrowserHistoryForward() {
  _pushSentinel('layer');
}

void _pushSentinel(String kind) {
  html.window.history.pushState(
    <String, dynamic>{'coparentes': kind},
    '',
    html.window.location.href,
  );
}
