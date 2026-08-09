/// Product feature flags. Flip a constant to restore a hidden surface.
class FeatureFlags {
  FeatureFlags._();

  /// Parent / observer bottom-nav and rail tab "Eksporty".
  ///
  /// Set to `true` to show the tab again. Finance PDF export and
  /// [ExportsProvider] keep working independently of this flag.
  static const bool showExportsTab = false;
}
