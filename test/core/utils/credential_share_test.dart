import 'package:flutter_test/flutter_test.dart';

import 'package:bharathbiomedpharma/core/utils/credential_share.dart';

void main() {
  group('buildCredentialsMessage', () {
    test('includes the password line when a password is given', () {
      final message = buildCredentialsMessage(
        name: 'Rajesh',
        username: 'rajesh_kumar',
        loginEmail: 'rajesh@example.com',
        password: 'Bharathbio@2026',
      );
      expect(message, contains('Username: rajesh_kumar'));
      expect(message, contains('Email: rajesh@example.com'));
      expect(message, contains('Password: Bharathbio@2026'));
    });

    test('omits the password line when no password is given (editing)', () {
      final message = buildCredentialsMessage(
        name: 'Rajesh',
        username: 'rajesh_kumar',
        loginEmail: 'rajesh@example.com',
      );
      expect(message, isNot(contains('Password:')));
    });
  });

  group('toWhatsAppNumber', () {
    test('prepends 91 to a plain 10-digit number', () {
      expect(toWhatsAppNumber('9876543210'), '919876543210');
    });

    test('strips spaces/dashes before prepending 91', () {
      expect(toWhatsAppNumber('98765-43210'), '919876543210');
    });

    test('leaves a number that already has a country code alone', () {
      expect(toWhatsAppNumber('919876543210'), '919876543210');
    });
  });
}
