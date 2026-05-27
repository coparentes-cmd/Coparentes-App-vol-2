import 'package:flutter_test/flutter_test.dart';

import 'package:coparentes/data/serializers/api_serializers.dart';
import 'package:coparentes/models/models.dart';

void main() {
  group('userRoleFromApi', () {
    test('maps known roles', () {
      expect(userRoleFromApi('parentA'), UserRole.parentA);
      expect(userRoleFromApi('parentB'), UserRole.parentB);
    });

    test('throws on unknown role', () {
      expect(() => userRoleFromApi('admin'), throwsFormatException);
    });
  });
}
