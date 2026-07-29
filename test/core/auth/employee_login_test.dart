import 'package:bharathbiomedpharma/core/auth/employee_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLoginEmail', () {
    test('passes a real email through unchanged', () {
      expect(resolveLoginEmail('bharathbiomedpharma@gmail.com'), 'bharathbiomedpharma@gmail.com');
    });

    test('trims a real email before passing it through', () {
      expect(resolveLoginEmail('  bharathbiomedpharma@gmail.com  '), 'bharathbiomedpharma@gmail.com');
    });

    test('turns a bare username into the synthetic MR email', () {
      expect(resolveLoginEmail('rajesh_kumar'), 'mr-rajesh_kumar@bharathbiomed-14368.firebaseapp.com');
    });

    test('lowercases the username so login is case-insensitive', () {
      expect(resolveLoginEmail('Rajesh_Kumar'), 'mr-rajesh_kumar@bharathbiomed-14368.firebaseapp.com');
    });
  });
}
