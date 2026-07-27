import '../../domain/models/employee.dart';
import '../remote/employee_remote_data_source.dart';

export '../remote/employee_remote_data_source.dart' show EmployeeCredentials;

class EmployeeRepository {
  EmployeeRepository({EmployeeRemoteDataSource? remote}) : _remote = remote ?? EmployeeRemoteDataSource();

  final EmployeeRemoteDataSource _remote;

  Future<List<Employee>> fetchAll() => _remote.fetchAll();

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
  }) {
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
  }) {
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
    );
  }

  Future<void> delete(String uid) => _remote.delete(uid);

  Future<void> resetPassword(String uid, String newPassword) => _remote.resetPassword(uid, newPassword);

  Future<void> setStatus(String uid, {required bool disabled}) => _remote.setStatus(uid, disabled: disabled);
}
