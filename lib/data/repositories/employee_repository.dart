import 'package:flutter/foundation.dart';

import '../../domain/models/employee.dart';
import '../remote/employee_remote_data_source.dart';

export '../remote/employee_remote_data_source.dart' show EmployeeCredentials;

class EmployeeRepository {
  EmployeeRepository({EmployeeRemoteDataSource? remote}) : _remote = remote ?? EmployeeRemoteDataSource();

  final EmployeeRemoteDataSource _remote;

  Future<List<Employee>> fetchAll() {
    debugPrint('EmployeeRepository.fetchAll: fetching employees');
    return _remote.fetchAll();
  }

  /// Everyone in [managerUid]'s downline tree — see
  /// [EmployeeRemoteDataSource.fetchDownline].
  Future<List<Employee>> fetchDownline(String managerUid) {
    debugPrint('EmployeeRepository.fetchDownline: managerUid=$managerUid');
    return _remote.fetchDownline(managerUid);
  }

  Future<EmployeeCredentials> create({
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
  }) {
    debugPrint('EmployeeRepository.create: creating employee username=$username email=$email');
    return _remote.create(
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
  }

  Future<EmployeeCredentials> update({
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
  }) {
    debugPrint('EmployeeRepository.update: updating employee uid=$uid username=$username');
    return _remote.update(
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
  }

  Future<void> delete(String uid) {
    debugPrint('EmployeeRepository.delete: deleting employee uid=$uid');
    return _remote.delete(uid);
  }

  Future<void> resetPassword(String uid, String newPassword) {
    debugPrint('EmployeeRepository.resetPassword: resetting password uid=$uid');
    return _remote.resetPassword(uid, newPassword);
  }

  Future<void> setStatus(String uid, {required bool disabled}) {
    debugPrint('EmployeeRepository.setStatus: uid=$uid disabled=$disabled');
    return _remote.setStatus(uid, disabled: disabled);
  }

  /// Streams the signed-in MR's own profile for the Profile screen.
  Stream<Employee?> watchMine(String uid) {
    debugPrint('EmployeeRepository.watchMine: uid=$uid');
    return _remote.watchMine(uid);
  }

  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
  }) {
    debugPrint('EmployeeRepository.updateMyProfile: updating own profile');
    return _remote.updateMyProfile(
      firstName: firstName,
      lastName: lastName,
      mobileNumber: mobileNumber,
      photoUrl: photoUrl,
      dateOfBirth: dateOfBirth,
    );
  }
}
