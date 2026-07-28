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

  group('Employee.fromJson hierarchy fields', () {
    test('default safely for a legacy doc missing all of them', () {
      final employee = Employee.fromJson('uid1', {
        'username': 'rajesh',
        'firstName': 'Rajesh',
        'lastName': 'Kumar',
        'designation': 'MR',
        'areaName': 'North',
      });

      expect(employee.designationId, isNull);
      expect(employee.managerId, isNull);
      expect(employee.reportingChainUids, isEmpty);
      expect(employee.permissions, isEmpty);
      expect(employee.hierarchyLevel, isNull);
      expect(employee.category, isNull);
    });

    test('parse when present', () {
      final employee = Employee.fromJson('uid1', {
        'username': 'rajesh',
        'firstName': 'Rajesh',
        'lastName': 'Kumar',
        'designation': 'MR',
        'areaName': 'North',
        'designationId': 'd1',
        'managerId': 'uid2',
        'reportingChainUids': ['uid2', 'uid3'],
        'permissions': ['create_orders'],
        'hierarchyLevel': 5,
        'category': 'field',
      });

      expect(employee.designationId, 'd1');
      expect(employee.managerId, 'uid2');
      expect(employee.reportingChainUids, ['uid2', 'uid3']);
      expect(employee.permissions, ['create_orders']);
      expect(employee.hierarchyLevel, 5);
      expect(employee.category, 'field');
    });
  });
}
