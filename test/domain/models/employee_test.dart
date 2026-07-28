import 'package:flutter_test/flutter_test.dart';

import 'package:bharathbiomedpharma/domain/models/employee.dart';

Employee _employeeWithDob(String? dob) {
  return Employee(
    uid: 'uid1',
    username: 'rajesh',
    firstName: 'Rajesh',
    lastName: 'Kumar',
    designation: 'MR',
    areaName: 'North',
    dateOfBirth: dob,
  );
}

void main() {
  group('Employee.isBirthdayToday', () {
    test('is true when month/day match today, regardless of year', () {
      final now = DateTime.now();
      final dob =
          '1990-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(_employeeWithDob(dob).isBirthdayToday, isTrue);
    });

    test('is false when dateOfBirth is null', () {
      expect(_employeeWithDob(null).isBirthdayToday, isFalse);
    });

    test('is false when month/day do not match today', () {
      final now = DateTime.now();
      final otherDay = now.day == 1 ? 2 : 1;
      final dob = '1990-${now.month.toString().padLeft(2, '0')}-${otherDay.toString().padLeft(2, '0')}';
      expect(_employeeWithDob(dob).isBirthdayToday, isFalse);
    });

    test('is false for a malformed date string', () {
      expect(_employeeWithDob('not-a-date').isBirthdayToday, isFalse);
    });
  });
}
