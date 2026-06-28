enum ConsentType {
  terms,
  dataProcessing,
  childData,
  emailNotifications,
  marketing,
  analytics,
}

extension ConsentTypeApi on ConsentType {
  String get apiValue {
    switch (this) {
      case ConsentType.terms:
        return 'TERMS';
      case ConsentType.dataProcessing:
        return 'DATA_PROCESSING';
      case ConsentType.childData:
        return 'CHILD_DATA';
      case ConsentType.emailNotifications:
        return 'EMAIL_NOTIFICATIONS';
      case ConsentType.marketing:
        return 'MARKETING';
      case ConsentType.analytics:
        return 'ANALYTICS';
    }
  }

  bool get isRequired {
    switch (this) {
      case ConsentType.terms:
      case ConsentType.dataProcessing:
      case ConsentType.childData:
        return true;
      case ConsentType.emailNotifications:
      case ConsentType.marketing:
      case ConsentType.analytics:
        return false;
    }
  }

  static ConsentType? fromApi(String value) {
    switch (value) {
      case 'TERMS':
        return ConsentType.terms;
      case 'DATA_PROCESSING':
        return ConsentType.dataProcessing;
      case 'CHILD_DATA':
        return ConsentType.childData;
      case 'EMAIL_NOTIFICATIONS':
        return ConsentType.emailNotifications;
      case 'MARKETING':
        return ConsentType.marketing;
      case 'ANALYTICS':
        return ConsentType.analytics;
      default:
        return null;
    }
  }
}

class UserConsentRecord {
  final ConsentType type;
  final bool granted;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final String consentVersion;
  final bool required;

  const UserConsentRecord({
    required this.type,
    required this.granted,
    this.grantedAt,
    this.revokedAt,
    required this.consentVersion,
    required this.required,
  });

  factory UserConsentRecord.fromJson(Map<String, dynamic> json) {
    final type = ConsentTypeApi.fromApi(json['consentType'] as String);
    if (type == null) {
      throw FormatException('Unknown consent type: ${json['consentType']}');
    }

    return UserConsentRecord(
      type: type,
      granted: json['granted'] as bool? ?? false,
      grantedAt: json['grantedAt'] != null
          ? DateTime.parse(json['grantedAt'] as String).toUtc()
          : null,
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String).toUtc()
          : null,
      consentVersion: json['consentVersion'] as String? ?? '1.0.0',
      required: json['required'] as bool? ?? type.isRequired,
    );
  }
}

Map<String, bool> consentSelectionsToApi(Map<ConsentType, bool> selections) {
  return {
    for (final entry in selections.entries) entry.key.apiValue: entry.value,
  };
}

bool areRequiredConsentsGranted(Map<ConsentType, bool> selections) {
  for (final type in ConsentType.values) {
    if (type.isRequired && selections[type] != true) {
      return false;
    }
  }
  return true;
}

Map<ConsentType, bool> defaultConsentSelections() {
  return {
    for (final type in ConsentType.values) type: false,
  };
}
