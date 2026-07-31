import 'package:bharathbiomedpharma/data/remote/employee_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEmployeeRemoteDataSource extends Mock implements EmployeeRemoteDataSource {}

void main() {
  late MockEmployeeRemoteDataSource remote;
  late EmployeeRepository repository;

  const employee = Employee(
    uid: 'mr1',
    username: 'rajesh_kumar',
    firstName: 'Rajesh',
    lastName: 'Kumar',
    designation: 'Medical Representative',
    areaName: 'North',
  );

  const credentials = EmployeeCredentials(username: 'rajesh_kumar', loginEmail: 'rajesh@example.com');

  setUp(() {
    remote = MockEmployeeRemoteDataSource();
    repository = EmployeeRepository(remote: remote);
  });

  test('fetchAll delegates to the remote data source', () async {
    when(() => remote.fetchAll()).thenAnswer((_) async => [employee]);
    expect(await repository.fetchAll(), [employee]);
  });

  test('fetchDownline delegates to the remote data source', () async {
    when(() => remote.fetchDownline('mgr1')).thenAnswer((_) async => [employee]);
    expect(await repository.fetchDownline('mgr1'), [employee]);
  });

  test('watchMine delegates to the remote data source', () {
    when(() => remote.watchMine('mr1')).thenAnswer((_) => Stream.value(employee));
    expect(repository.watchMine('mr1'), emits(employee));
  });

  test('create delegates to the remote data source with every field', () async {
    when(() => remote.create(
          firstName: 'Rajesh',
          lastName: 'Kumar',
          username: 'rajesh_kumar',
          password: 'Bharathbio@2026',
          designation: 'Medical Representative',
          areaName: 'North',
          email: '',
          mobileNumber: null,
          photoUrl: null,
          dateOfBirth: null,
          designationId: null,
          managerId: null,
        )).thenAnswer((_) async => credentials);

    final result = await repository.create(
      firstName: 'Rajesh',
      lastName: 'Kumar',
      username: 'rajesh_kumar',
      password: 'Bharathbio@2026',
      designation: 'Medical Representative',
      areaName: 'North',
      email: '',
    );

    expect(result, credentials);
  });

  test('update delegates to the remote data source with every field', () async {
    when(() => remote.update(
          uid: 'mr1',
          firstName: 'Rajesh',
          lastName: 'Kumar',
          username: 'rajesh_kumar',
          designation: 'Medical Representative',
          areaName: 'North',
          email: '',
          mobileNumber: null,
          photoUrl: null,
          dateOfBirth: null,
          designationId: null,
          managerId: null,
        )).thenAnswer((_) async => credentials);

    final result = await repository.update(
      uid: 'mr1',
      firstName: 'Rajesh',
      lastName: 'Kumar',
      username: 'rajesh_kumar',
      designation: 'Medical Representative',
      areaName: 'North',
      email: '',
    );

    expect(result, credentials);
  });

  test('delete delegates to the remote data source', () async {
    when(() => remote.delete('mr1')).thenAnswer((_) async {});
    await repository.delete('mr1');
    verify(() => remote.delete('mr1')).called(1);
  });

  test('resetPassword delegates to the remote data source', () async {
    when(() => remote.resetPassword('mr1', 'newPass123')).thenAnswer((_) async {});
    await repository.resetPassword('mr1', 'newPass123');
    verify(() => remote.resetPassword('mr1', 'newPass123')).called(1);
  });

  test('setStatus delegates to the remote data source', () async {
    when(() => remote.setStatus('mr1', disabled: true)).thenAnswer((_) async {});
    await repository.setStatus('mr1', disabled: true);
    verify(() => remote.setStatus('mr1', disabled: true)).called(1);
  });

  test('updateMyProfile delegates to the remote data source', () async {
    when(() => remote.updateMyProfile(
          firstName: 'Rajesh',
          lastName: 'Kumar',
          mobileNumber: '9999999999',
          photoUrl: null,
          dateOfBirth: '1990-01-01',
        )).thenAnswer((_) async {});

    await repository.updateMyProfile(
      firstName: 'Rajesh',
      lastName: 'Kumar',
      mobileNumber: '9999999999',
      dateOfBirth: '1990-01-01',
    );

    verify(() => remote.updateMyProfile(
          firstName: 'Rajesh',
          lastName: 'Kumar',
          mobileNumber: '9999999999',
          photoUrl: null,
          dateOfBirth: '1990-01-01',
        )).called(1);
  });
}
