import 'auth_session.dart';

class LoginChallenge {
  final String challengeId;
  final String maskedEmail;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  const LoginChallenge({
    required this.challengeId,
    required this.maskedEmail,
    required this.expiresAt,
    required this.resendAvailableAt,
  });

  factory LoginChallenge.fromJson(Map<String, dynamic> json) {
    return LoginChallenge(
      challengeId: json['challengeId'] as String,
      maskedEmail: json['email'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      resendAvailableAt: DateTime.parse(json['resendAvailableAt'] as String),
    );
  }
}

class LoginResponse {
  final AuthSession? session;
  final LoginChallenge? challenge;

  const LoginResponse({this.session, this.challenge});

  bool get requiresOtp => challenge != null;
}
