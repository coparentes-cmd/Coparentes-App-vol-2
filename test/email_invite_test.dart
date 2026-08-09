import 'package:coparentes/data/serializers/document_serializers.dart';
import 'package:coparentes/models/documents.dart';
import 'package:flutter_test/flutter_test.dart';

String inviteStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Wysłane — oczekuje na dołączenie';
    case 'ACCEPTED':
      return 'Zaakceptowane';
    case 'EXPIRED':
      return 'Wygasłe';
    default:
      return status;
  }
}

void main() {
  test('emailInviteFromJson parses invite payload', () {
    final invite = emailInviteFromJson({
      'id': 'inv_1',
      'email': 'partner@example.com',
      'status': 'PENDING',
      'expiresAt': '2026-08-16T12:00:00.000Z',
      'createdAt': '2026-08-09T12:00:00.000Z',
      'acceptedAt': null,
    });

    expect(invite.email, 'partner@example.com');
    expect(invite.status, 'PENDING');
    expect(invite.acceptedAt, isNull);
  });

  test('EmailInviteSendResult carries emailSent and inviteCode', () {
    final invite = EmailInvite(
      id: 'inv_1',
      email: 'partner@example.com',
      status: 'PENDING',
      expiresAt: DateTime.parse('2026-08-16T12:00:00.000Z'),
      createdAt: DateTime.parse('2026-08-09T12:00:00.000Z'),
    );

    final result = EmailInviteSendResult(
      invite: invite,
      emailSent: true,
      inviteCode: 'RODZINA-AB12',
    );

    expect(result.emailSent, isTrue);
    expect(result.inviteCode, 'RODZINA-AB12');
  });

  test('PENDING means sent and waiting, not failed', () {
    expect(inviteStatusLabel('PENDING'), 'Wysłane — oczekuje na dołączenie');
    expect(inviteStatusLabel('ACCEPTED'), 'Zaakceptowane');
    expect(inviteStatusLabel('EXPIRED'), 'Wygasłe');
  });
}
