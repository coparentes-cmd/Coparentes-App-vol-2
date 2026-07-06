import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef BrowserBackHandler = bool Function();

final List<BrowserBackHandler> _handlers = <BrowserBackHandler>[];
StreamSubscription<html.PopStateEvent>? _subscription;
bool _installed = false;

void installAppBrowserBackHandling() {
  if (_installed) {
    return;
  }
  _installed = true;

  html.window.history.pushState(
    <String, dynamic>{'coparentes': 'root'},
    '',
    html.window.location.href,
  );

  _subscription = html.window.onPopState.listen((_) {
    for (final handler in _handlers.reversed) {
      if (handler()) {
        return;
      }
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
  html.window.history.pushState(
    <String, dynamic>{'coparentes': 'layer'},
    '',
    html.window.location.href,
  );
}
