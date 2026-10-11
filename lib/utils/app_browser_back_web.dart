// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef BrowserBackHandler = bool Function();

final List<BrowserBackHandler> _handlers = <BrowserBackHandler>[];
bool _installed = false;
int _seq = 0;
bool _reentrancy = false;

void installAppBrowserBackHandling() {
  if (_installed) {
    return;
  }
  _installed = true;

  _pushSentinel('root');

  // Capture phase so we run before Flutter's own popstate listener.
  html.window.addEventListener('popstate', (html.Event event) {
    if (_reentrancy) {
      return;
    }
    var handled = false;
    for (final handler in _handlers.reversed) {
      try {
        if (handler()) {
          handled = true;
          break;
        }
      } catch (_) {
        // Keep trying other handlers.
      }
    }
    if (handled) {
      // Re-seed so the next Safari ← stays inside the app.
      _reentrancy = true;
      try {
        _pushSentinel('layer');
      } finally {
        _reentrancy = false;
      }
    }
  }, true);
}

void registerBrowserBackHandler(BrowserBackHandler handler) {
  if (!_handlers.contains(handler)) {
    _handlers.add(handler);
  }
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
  // Unique hash creates a real Safari history entry. With path URL strategy
  // Flutter ignores the hash, so this no longer fights the router.
  final loc = html.window.location;
  final url = '${loc.pathname}${loc.search}#cp=$_seq';
  html.window.history.pushState(
    <String, dynamic>{'coparentes': kind, 'seq': _seq},
    '',
    url,
  );
}
