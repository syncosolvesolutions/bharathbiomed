import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/features/admin/employee_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

void main() {
  late MockEmployeeRepository repository;
  late ProviderContainer container;

  const employee = Employee(
    uid: 'uid1',
    username: 'rajesh_kumar',
    firstName: 'Rajesh',
    lastName: 'Kumar',
    designation: 'Medical Representative',
    areaName: 'North',
  );

  const credentials = EmployeeCredentials(username: 'rajesh_kumar', loginEmail: 'rajesh@example.com');

  setUp(() {
    repository = MockEmployeeRepository();
    container = ProviderContainer(
      overrides: [employeeRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('build fetches every employee from the repository', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);

    final result = await container.read(employeeControllerProvider.future);

    expect(result, [employee]);
  });

  test('createEmployee creates then refreshes the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => []);
    await container.read(employeeControllerProvider.future);

    when(() => repository.create(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          username: any(named: 'username'),
          password: any(named: 'password'),
          designation: any(named: 'designation'),
          areaName: any(named: 'areaName'),
          email: any(named: 'email'),
          mobileNumber: any(named: 'mobileNumber'),
          photoUrl: any(named: 'photoUrl'),
          dateOfBirth: any(named: 'dateOfBirth'),
          designationId: any(named: 'designationId'),
          managerId: any(named: 'managerId'),
        )).thenAnswer((_) async => credentials);
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);

    final notifier = container.read(employeeControllerProvider.notifier);
    final result = await notifier.createEmployee(
      firstName: 'Rajesh',
      lastName: 'Kumar',
      username: 'rajesh_kumar',
      password: 'Bharathbio@2026',
      designation: 'Medical Representative',
      areaName: 'North',
      email: '',
    );

    expect(result, credentials);
    expect(container.read(employeeControllerProvider).value, [employee]);
  });

  test('deleteEmployee deletes then refreshes the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);
    await container.read(employeeControllerProvider.future);

    when(() => repository.delete('uid1')).thenAnswer((_) async {});
    when(() => repository.fetchAll()).thenAnswer((_) async => []);

    await container.read(employeeControllerProvider.notifier).deleteEmployee('uid1');

    expect(container.read(employeeControllerProvider).value, isEmpty);
    verify(() => repository.delete('uid1')).called(1);
  });

  test('resetPassword delegates to the repository without refreshing the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);
    await container.read(employeeControllerProvider.future);

    when(() => repository.resetPassword('uid1', 'newPass123')).thenAnswer((_) async {});

    await container.read(employeeControllerProvider.notifier).resetPassword('uid1', 'newPass123');

    verify(() => repository.resetPassword('uid1', 'newPass123')).called(1);
    // build() above already called fetchAll() once to warm up the
    // container; resetPassword must not trigger a second call.
    verify(() => repository.fetchAll()).called(1);
  });

  test('setStatus disables then refreshes the list', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);
    await container.read(employeeControllerProvider.future);

    when(() => repository.setStatus('uid1', disabled: true)).thenAnswer((_) async {});
    const disabledEmployee = Employee(
      uid: 'uid1',
      username: 'rajesh_kumar',
      firstName: 'Rajesh',
      lastName: 'Kumar',
      designation: 'Medical Representative',
      areaName: 'North',
      disabled: true,
    );
    when(() => repository.fetchAll()).thenAnswer((_) async => [disabledEmployee]);

    await container.read(employeeControllerProvider.notifier).setStatus('uid1', disabled: true);

    expect(container.read(employeeControllerProvider).value!.single.disabled, isTrue);
  });

  test('a failing refresh surfaces as an AsyncError state, not a thrown exception', () async {
    when(() => repository.fetchAll()).thenAnswer((_) async => [employee]);
    await container.read(employeeControllerProvider.future);

    when(() => repository.delete('uid1')).thenAnswer((_) async {});
    when(() => repository.fetchAll()).thenThrow(Exception('network error'));

    await container.read(employeeControllerProvider.notifier).deleteEmployee('uid1');

    expect(container.read(employeeControllerProvider).hasError, isTrue);
  });
}
