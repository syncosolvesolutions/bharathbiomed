import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/employee_repository.dart';
import '../../domain/models/employee.dart';

final employeeControllerProvider = AsyncNotifierProvider<EmployeeController, List<Employee>>(EmployeeController.new);

class EmployeeController extends AsyncNotifier<List<Employee>> {
  @override
  Future<List<Employee>> build() async {
    debugPrint('EmployeeController.build: fetching employees');
    final result = await ref.read(employeeRepositoryProvider).fetchAll();
    debugPrint('EmployeeController.build: fetched ${result.length} employees');
    return result;
  }

  /// Returns what the MR actually logs in with, so the caller can show it to
  /// the admin alongside the password they chose.
  Future<EmployeeCredentials> createEmployee({
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
    String? designationId,
    String? managerId,
  }) async {
    debugPrint('EmployeeController.createEmployee: creating employee username=$username designation=$designation');
    final credentials = await ref.read(employeeRepositoryProvider).create(
          firstName: firstName,
          lastName: lastName,
          username: username,
          password: password,
          designation: designation,
          areaName: areaName,
          email: email,
          mobileNumber: mobileNumber,
          photoUrl: photoUrl,
          dateOfBirth: dateOfBirth,
          designationId: designationId,
          managerId: managerId,
        );
    debugPrint('EmployeeController.createEmployee: created employee username=$username');
    await _refresh();
    return credentials;
  }

  Future<EmployeeCredentials> updateEmployee({
    required String uid,
    required String firstName,
    required String lastName,
    required String username,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
    String? designationId,
    String? managerId,
  }) async {
    debugPrint('EmployeeController.updateEmployee: updating employee uid=$uid');
    final credentials = await ref.read(employeeRepositoryProvider).update(
          uid: uid,
          firstName: firstName,
          lastName: lastName,
          username: username,
          designation: designation,
          areaName: areaName,
          email: email,
          mobileNumber: mobileNumber,
          photoUrl: photoUrl,
          dateOfBirth: dateOfBirth,
          designationId: designationId,
          managerId: managerId,
        );
    debugPrint('EmployeeController.updateEmployee: updated employee uid=$uid');
    await _refresh();
    return credentials;
  }

  Future<void> deleteEmployee(String uid) async {
    debugPrint('EmployeeController.deleteEmployee: deleting employee uid=$uid');
    await ref.read(employeeRepositoryProvider).delete(uid);
    debugPrint('EmployeeController.deleteEmployee: deleted employee uid=$uid');
    await _refresh();
  }

  Future<void> resetPassword(String uid, String newPassword) async {
    debugPrint('EmployeeController.resetPassword: resetting password uid=$uid');
    await ref.read(employeeRepositoryProvider).resetPassword(uid, newPassword);
    debugPrint('EmployeeController.resetPassword: reset password succeeded uid=$uid');
  }

  Future<void> setStatus(String uid, {required bool disabled}) async {
    debugPrint('EmployeeController.setStatus: setting status uid=$uid disabled=$disabled');
    await ref.read(employeeRepositoryProvider).setStatus(uid, disabled: disabled);
    debugPrint('EmployeeController.setStatus: status set uid=$uid disabled=$disabled');
    await _refresh();
  }

  Future<void> _refresh() async {
    debugPrint('EmployeeController._refresh: refreshing employees');
    state = await AsyncValue.guard(() => ref.read(employeeRepositoryProvider).fetchAll());
    debugPrint('EmployeeController._refresh: done, hasError=${state.hasError}');
  }
}
