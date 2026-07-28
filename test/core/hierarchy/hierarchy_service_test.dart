import 'package:flutter_test/flutter_test.dart';

import 'package:bharathbiomedpharma/core/hierarchy/hierarchy_service.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';

Employee _employee({
  required String uid,
  List<String> permissions = const [],
  List<String> reportingChainUids = const [],
}) {
  return Employee(
    uid: uid,
    username: uid,
    firstName: 'First',
    lastName: 'Last',
    designation: 'X',
    areaName: 'North',
    permissions: permissions,
    reportingChainUids: reportingChainUids,
  );
}

void main() {
  group('HierarchyService.canUserApprove', () {
    test('denies when approver lacks the permission', () {
      final approver = _employee(uid: 'abm', permissions: const []);
      final creator = _employee(uid: 'mr', reportingChainUids: ['abm']);

      expect(
        HierarchyService.canUserApprove(approver: approver, creator: creator, permission: Permission.approveOrders),
        isFalse,
      );
    });

    test('allows an in-chain manager who holds the permission', () {
      final approver = _employee(uid: 'abm', permissions: [Permission.approveOrders.value]);
      final creator = _employee(uid: 'mr', reportingChainUids: ['abm', 'rbm', 'zbm']);

      expect(
        HierarchyService.canUserApprove(approver: approver, creator: creator, permission: Permission.approveOrders),
        isTrue,
      );
    });

    test('denies an out-of-chain manager even with the permission', () {
      final approver = _employee(uid: 'other-abm', permissions: [Permission.approveOrders.value]);
      final creator = _employee(uid: 'mr', reportingChainUids: ['abm', 'rbm', 'zbm']);

      expect(
        HierarchyService.canUserApprove(approver: approver, creator: creator, permission: Permission.approveOrders),
        isFalse,
      );
    });

    test('view_global_data bypasses the chain check entirely', () {
      final approver = _employee(
        uid: 'ceo',
        permissions: [Permission.approveOrders.value, Permission.viewGlobalData.value],
      );
      final creator = _employee(uid: 'mr', reportingChainUids: ['abm', 'rbm', 'zbm']);

      expect(
        HierarchyService.canUserApprove(approver: approver, creator: creator, permission: Permission.approveOrders),
        isTrue,
      );
    });
  });

  group('HierarchyService.canViewResource', () {
    test('the resource creator can always view their own resource', () {
      final viewer = _employee(uid: 'mr');
      expect(
        HierarchyService.canViewResource(
          viewer: viewer,
          resourceCreatedByUid: 'mr',
          resourceReportingChainUids: const [],
        ),
        isTrue,
      );
    });

    test('a manager in the resource creator chain can view it', () {
      final viewer = _employee(uid: 'abm');
      expect(
        HierarchyService.canViewResource(
          viewer: viewer,
          resourceCreatedByUid: 'mr',
          resourceReportingChainUids: ['abm', 'rbm'],
        ),
        isTrue,
      );
    });

    test('an unrelated employee without global visibility cannot view it', () {
      final viewer = _employee(uid: 'other-mr');
      expect(
        HierarchyService.canViewResource(
          viewer: viewer,
          resourceCreatedByUid: 'mr',
          resourceReportingChainUids: ['abm', 'rbm'],
        ),
        isFalse,
      );
    });

    test('view_global_data grants visibility regardless of chain', () {
      final viewer = _employee(uid: 'ceo', permissions: [Permission.viewGlobalData.value]);
      expect(
        HierarchyService.canViewResource(
          viewer: viewer,
          resourceCreatedByUid: 'mr',
          resourceReportingChainUids: ['abm', 'rbm'],
        ),
        isTrue,
      );
    });
  });
}
