/// Fixed calendar day used only while demo mode is active.
///
/// When inactive, [now] is identical to [DateTime.now] so production paths
/// that call it are unaffected.
class DemoTime {
  DemoTime._();

  static final DateTime demoDay = DateTime(2026, 8, 10);

  static bool _active = false;

  static bool get isActive => _active;

  static void activate() => _active = true;

  static void deactivate() => _active = false;

  /// Demo: always 10.08.2026 12:00 local. Otherwise real device time.
  static DateTime now() {
    if (!_active) {
      return DateTime.now();
    }
    return DateTime(demoDay.year, demoDay.month, demoDay.day, 12);
  }
}
