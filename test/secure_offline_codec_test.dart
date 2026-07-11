import 'package:coparentes/data/local/secure_offline_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeSessionPayloadForCache removes token', () {
    final sanitized = sanitizeSessionPayloadForCache({
      'token': 'secret-token',
      'user': {'id': 'user_1', 'name': 'Anna'},
      'workspace': {'id': 'ws_1', 'name': 'Rodzina'},
    });

    expect(sanitized.containsKey('token'), isFalse);
    expect(sanitized['workspace'], {'id': 'ws_1', 'name': 'Rodzina'});
  });
}
