import 'package:flutter_test/flutter_test.dart';

import 'package:bharathbiomedpharma/domain/models/designation.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';

void main() {
  group('Designation.fromJson/toJson', () {
    test('round-trips every field', () {
      final designation = Designation(
        id: 'd1',
        name: 'Area Business Manager',
        category: DesignationCategory.field,
        hierarchyLevel: 3,
        parentDesignationId: 'd2',
        permissions: [Permission.approveOrders.value, Permission.approveRequests.value],
      );

      final json = designation.toJson();
      final parsed = Designation.fromJson('d1', json);

      expect(parsed, designation);
    });

    test('defaults safely for a legacy doc missing every new field', () {
      final parsed = Designation.fromJson('d1', {'name': 'Medical Representative'});

      expect(parsed.category, DesignationCategory.field);
      expect(parsed.hierarchyLevel, 0);
      expect(parsed.parentDesignationId, isNull);
      expect(parsed.permissions, isEmpty);
    });

    test('parses each category string correctly', () {
      expect(designationCategoryFromString('field'), DesignationCategory.field);
      expect(designationCategoryFromString('office_administration'), DesignationCategory.officeAdministration);
      expect(designationCategoryFromString('executive'), DesignationCategory.executive);
      expect(designationCategoryFromString(null), DesignationCategory.field);
      expect(designationCategoryFromString('nonsense'), DesignationCategory.field);
    });
  });

  group('Designation.permissionSet', () {
    test('drops unrecognized permission strings instead of throwing', () {
      final designation = Designation(
        id: 'd1',
        name: 'X',
        permissions: [Permission.createOrders.value, 'some_future_permission'],
      );

      expect(designation.permissionSet, {Permission.createOrders});
    });
  });
}
