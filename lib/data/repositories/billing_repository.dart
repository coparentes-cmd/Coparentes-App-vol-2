import '../api/app_api_client.dart';
import '../serializers/api_serializers.dart';
import '../../models/models.dart';

class BillingEntitlement {
  const BillingEntitlement({
    required this.platform,
    required this.accessAllowed,
    required this.billingStatus,
    this.trialStartedAt,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.billingSource,
    this.user,
  });

  final String platform;
  final bool accessAllowed;
  final BillingStatus billingStatus;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String? billingSource;
  final AppUser? user;

  factory BillingEntitlement.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return BillingEntitlement(
      platform: json['platform'] as String? ?? 'web',
      accessAllowed: json['accessAllowed'] as bool? ?? false,
      billingStatus: billingStatusFromApi(json['billingStatus'] as String?),
      trialStartedAt: _date(json['trialStartedAt']),
      trialEndsAt: _date(json['trialEndsAt']),
      currentPeriodEnd: _date(json['currentPeriodEnd']),
      billingSource: json['billingSource'] as String?,
      user: userJson is Map<String, dynamic>
          ? appUserFromJson(userJson)
          : (userJson is Map
              ? appUserFromJson(Map<String, dynamic>.from(userJson))
              : null),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class BillingRepository {
  BillingRepository({required AppApiClient apiClient}) : _apiClient = apiClient;

  final AppApiClient _apiClient;

  Future<BillingEntitlement> getEntitlement() async {
    final json = await _apiClient.getJson('/billing/entitlement');
    return BillingEntitlement.fromJson(json);
  }

  Future<BillingEntitlement> startMobileTrial() async {
    final json = await _apiClient.postJson('/billing/start-mobile-trial', {});
    return BillingEntitlement.fromJson(json);
  }
}
