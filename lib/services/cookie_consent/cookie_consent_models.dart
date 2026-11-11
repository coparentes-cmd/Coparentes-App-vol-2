/// Browser cookie consent (landing-compatible shape).
class CookieConsent {
  static const storageKey = 'coparentes_cookie_consent_v1';
  static const version = '1.0';

  final bool necessary;
  final bool functional;
  final bool analytics;
  final bool marketing;
  final String consentVersion;
  final String savedAt;

  const CookieConsent({
    this.necessary = true,
    this.functional = false,
    this.analytics = false,
    this.marketing = false,
    this.consentVersion = version,
    required this.savedAt,
  });

  factory CookieConsent.defaults() => CookieConsent(
        savedAt: DateTime.now().toUtc().toIso8601String(),
      );

  factory CookieConsent.acceptAll() => CookieConsent(
        necessary: true,
        functional: true,
        analytics: true,
        marketing: true,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      );

  factory CookieConsent.rejectOptional() => CookieConsent(
        necessary: true,
        functional: false,
        analytics: false,
        marketing: false,
        savedAt: DateTime.now().toUtc().toIso8601String(),
      );

  factory CookieConsent.fromJson(Map<String, dynamic> json) {
    return CookieConsent(
      necessary: true,
      functional: json['functional'] == true,
      analytics: json['analytics'] == true,
      marketing: json['marketing'] == true,
      consentVersion: (json['version'] as String?)?.trim().isNotEmpty == true
          ? json['version'] as String
          : version,
      savedAt: (json['savedAt'] as String?)?.trim().isNotEmpty == true
          ? json['savedAt'] as String
          : DateTime.now().toUtc().toIso8601String(),
    );
  }

  CookieConsent copyWith({
    bool? functional,
    bool? analytics,
    bool? marketing,
    String? savedAt,
  }) {
    return CookieConsent(
      necessary: true,
      functional: functional ?? this.functional,
      analytics: analytics ?? this.analytics,
      marketing: marketing ?? this.marketing,
      consentVersion: consentVersion,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'necessary': true,
        'functional': functional,
        'analytics': analytics,
        'marketing': marketing,
        'version': consentVersion,
        'savedAt': savedAt,
      };
}
