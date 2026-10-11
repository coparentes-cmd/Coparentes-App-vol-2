// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Injects gtag.js and talks to `window.gtag` (GA4).
class GaBridge {
  Completer<void>? _loadCompleter;
  bool _stubReady = false;

  bool get isLoaded => _loadCompleter?.isCompleted ?? false;

  Future<void> ensureLoaded(String measurementId) async {
    if (measurementId.isEmpty) {
      return;
    }
    if (_loadCompleter != null) {
      return _loadCompleter!.future;
    }
    _loadCompleter = Completer<void>();
    try {
      _ensureGtagStub();

      final existing = html.document.querySelector(
        'script[data-coparentes-ga="1"]',
      );
      if (existing != null) {
        if (!_loadCompleter!.isCompleted) {
          _loadCompleter!.complete();
        }
        return _loadCompleter!.future;
      }

      final script = html.ScriptElement()
        ..async = true
        ..src =
            'https://www.googletagmanager.com/gtag/js?id=${Uri.encodeComponent(measurementId)}'
        ..setAttribute('data-coparentes-ga', '1');

      final done = Completer<void>();
      script.onLoad.listen((_) {
        if (!done.isCompleted) {
          done.complete();
        }
      });
      script.onError.listen((_) {
        if (!done.isCompleted) {
          done.completeError(StateError('Failed to load gtag.js'));
        }
      });
      html.document.head?.append(script);
      await done.future;
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

  void setAnalyticsConsent(bool granted) {
    _ensureGtagStub();
    _callGtag('consent', 'update', <String, Object>{
      'ad_storage': 'denied',
      'ad_user_data': 'denied',
      'ad_personalization': 'denied',
      'analytics_storage': granted ? 'granted' : 'denied',
    });
  }

  void config(String measurementId) {
    if (measurementId.isEmpty) {
      return;
    }
    _ensureGtagStub();
    _callGtag('js', DateTime.now());
    _callGtag('config', measurementId, <String, Object>{
      'send_page_view': false,
      'anonymize_ip': true,
    });
  }

  void event(String name, [Map<String, Object>? params]) {
    _ensureGtagStub();
    if (params == null || params.isEmpty) {
      _callGtag('event', name);
    } else {
      _callGtag('event', name, params);
    }
  }

  void pageView({required String pagePath, String? pageTitle}) {
    event('page_view', <String, Object>{
      'page_path': pagePath,
      if (pageTitle != null && pageTitle.isNotEmpty) 'page_title': pageTitle,
    });
  }

  void _ensureGtagStub() {
    if (_stubReady) {
      return;
    }
    if (!js.context.hasProperty('gtag')) {
      final inline = html.ScriptElement()
        ..type = 'text/javascript'
        ..text = '''
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('consent','default',{
  'ad_storage':'denied',
  'ad_user_data':'denied',
  'ad_personalization':'denied',
  'analytics_storage':'denied',
  'wait_for_update':500
});
''';
      html.document.head?.append(inline);
    }
    _stubReady = true;
  }

  void _callGtag(Object a, Object b, [Object? c]) {
    if (!js.context.hasProperty('gtag')) {
      return;
    }
    if (c != null) {
      final payload = c is Map ? js.JsObject.jsify(c) : c;
      js.context.callMethod('gtag', [a, b, payload]);
    } else if (b is DateTime) {
      js.context.callMethod('gtag', [a, b]);
    } else {
      js.context.callMethod('gtag', [a, b]);
    }
  }
}
