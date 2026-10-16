// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Injects Microsoft Clarity only when asked (after ANALYTICS consent).
class ClarityBridge {
  Completer<void>? _loadCompleter;

  bool get isLoaded => _loadCompleter?.isCompleted ?? false;

  static final _safeProjectId = RegExp(r'^[a-zA-Z0-9]+$');

  Future<void> ensureLoaded(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty || !_safeProjectId.hasMatch(id)) {
      return;
    }
    if (_loadCompleter != null) {
      return _loadCompleter!.future;
    }
    _loadCompleter = Completer<void>();
    try {
      final existing = html.document.querySelector(
        'script[data-coparentes-clarity="1"]',
      );
      if (existing != null) {
        if (!_loadCompleter!.isCompleted) {
          _loadCompleter!.complete();
        }
        return _loadCompleter!.future;
      }

      // Same bootstrap as Clarity "Install manually" snippet.
      final bootstrap = html.ScriptElement()
        ..type = 'text/javascript'
        ..setAttribute('data-coparentes-clarity', '1')
        ..text = '''
(function(c,l,a,r,i,t,y){
  c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
  t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
  t.setAttribute("data-coparentes-clarity","1");
  y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
})(window, document, "clarity", "script", "$id");
''';

      html.document.head?.append(bootstrap);
      if (!_loadCompleter!.isCompleted) {
        _loadCompleter!.complete();
      }
    } catch (error, stack) {
      if (!(_loadCompleter?.isCompleted ?? true)) {
        _loadCompleter!.completeError(error, stack);
      }
      _loadCompleter = null;
      rethrow;
    }
    return _loadCompleter!.future;
  }

  /// Stops recording after consent is revoked.
  void stop() {
    try {
      if (js.context.hasProperty('clarity')) {
        js.context.callMethod('clarity', ['stop']);
      }
    } catch (_) {
      // Ignore JS errors when tearing down.
    }
    html.document
        .querySelectorAll('script[data-coparentes-clarity="1"]')
        .forEach((node) => node.remove());
    _loadCompleter = null;
  }
}
