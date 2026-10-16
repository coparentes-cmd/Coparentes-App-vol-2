/// No-op Clarity bridge for non-web / unit tests.
class ClarityBridge {
  bool get isLoaded => false;

  Future<void> ensureLoaded(String projectId) async {}

  void stop() {}
}
