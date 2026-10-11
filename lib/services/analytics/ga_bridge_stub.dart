/// No-op bridge for non-web platforms and unit tests without JS.
class GaBridge {
  bool get isLoaded => false;

  Future<void> ensureLoaded(String measurementId) async {}

  void setAnalyticsConsent(bool granted) {}

  void config(String measurementId) {}

  void event(String name, [Map<String, Object>? params]) {}

  void pageView({required String pagePath, String? pageTitle}) {}
}
