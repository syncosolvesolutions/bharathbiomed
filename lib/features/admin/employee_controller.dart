import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/employee_repository.dart';
import '../../domain/models/employee.dart';

final employeeControllerProvider = AsyncNotifierProvider<EmployeeController, List<Employee>>(EmployeeController.new);

class EmployeeController extends AsyncNotifier<List<Employee>> {
  @override
  Future<List<Employee>> build() {
    return ref.read(employeeRepositoryProvider).fetchAll();
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
  }) async {
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
        );
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
  }) async {
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
        );
    await _refresh();
    return credentials;
  }

  Future<void> deleteEmployee(String uid) async {
    await ref.read(employeeRepositoryProvider).delete(uid);
    await _refresh();
  }

  Future<void> resetPassword(String uid, String newPassword) {
    return ref.read(employeeRepositoryProvider).resetPassword(uid, newPassword);
  }

  Future<void> setStatus(String uid, {required bool disabled}) async {
    await ref.read(employeeRepositoryProvider).setStatus(uid, disabled: disabled);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(() => ref.read(employeeRepositoryProvider).fetchAll());
  }
}
