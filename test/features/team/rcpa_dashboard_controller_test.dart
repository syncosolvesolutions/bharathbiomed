import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/rcpa_entry.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/profile/profile_controller.dart';
import 'package:bharathbiomedpharma/features/team/rcpa_dashboard_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockRcpaRepository extends Mock implements RcpaRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository authRepository;
  late MockEmployeeRepository employeeRepository;
  late MockRcpaRepository rcpaRepository;

  ProviderContainer buildContainer() {
    authRepository = MockAuthRepository();
    employeeRepository = MockEmployeeRepository();
    rcpaRepository = MockRcpaRepository();
    return ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      employeeRepositoryProvider.overrideWithValue(employeeRepository),
      rcpaRepositoryProvider.overrideWithValue(rcpaRepository),
    ]);
  }

  const rep = Employee(
    uid: 'rep1',
    username: 'rajesh_kumar',
    firstName: 'Rajesh',
    lastName: 'Kumar',
    designation: 'Medical Representative',
    areaName: 'North',
  );

  RcpaEntry entry(String id, {required String mrUid, required DateTime createdAt}) => RcpaEntry(
        id: id,
        mrUid: mrUid,
        pharmacyId: 'ph1',
        pharmacyName: 'City Pharmacy',
        auditDate: '2026-07-01',
        createdAt: createdAt,
      );

  test('an admin sees every employee, fetched via fetchRecentForDashboard, grouped and sorted newest-first', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final admin = MockUser();
    when(() => admin.email).thenReturn('bharathbiomedpharma@gmail.com');
    when(() => admin.uid).thenReturn('admin-uid');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(admin));
    when(() => employeeRepository.fetchAll()).thenAnswer((_) async => [rep]);
    final older = entry('e1', mrUid: 'rep1', createdAt: DateTime(2026, 7, 1));
    final newer = entry('e2', mrUid: 'rep1', createdAt: DateTime(2026, 7, 2));
    when(() => rcpaRepository.fetchRecentForDashboard()).thenAnswer((_) async => [older, newer]);

    // Resolve auth state first, same rationale as UsageDashboardController's
    // own test: build() reads authControllerProvider/hasGlobalVisibilityProvider
    // synchronously, so an unresolved auth state would wrongly fall back to
    // the downline branch.
    await container.read(authControllerProvider.future);
    final data = await container.read(rcpaDashboardControllerProvider.future);

    expect(data.employees, [rep]);
    expect(data.entriesByEmployee['rep1'], [newer, older]);
    verifyNever(() => employeeRepository.fetchDownline(any()));
    verifyNever(() => rcpaRepository.fetchRecentForEmployees(any()));
  });

  test('a manager with no global-visibility permission only sees their own downline', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final manager = MockUser();
    when(() => manager.email).thenReturn('manager@example.com');
    when(() => manager.uid).thenReturn('mgr1');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(manager));

    const managerProfile = Employee(
      uid: 'mgr1',
      username: 'manager',
      firstName: 'Manager',
      lastName: 'One',
      designation: 'Area Business Manager',
      areaName: 'North',
    );
    when(() => employeeRepository.watchMine('mgr1')).thenAnswer((_) => Stream.value(managerProfile));
    when(() => employeeRepository.fetchDownline('mgr1')).thenAnswer((_) async => [rep]);
    final mine = entry('e1', mrUid: 'rep1', createdAt: DateTime(2026, 7, 1));
    when(() => rcpaRepository.fetchRecentForEmployees(['rep1'])).thenAnswer((_) async => [mine]);

    await container.read(authControllerProvider.future);
    await container.read(myEmployeeProfileProvider.future);

    final data = await container.read(rcpaDashboardControllerProvider.future);

    expect(data.employees, [rep]);
    expect(data.entriesByEmployee['rep1'], [mine]);
    verifyNever(() => employeeRepository.fetchAll());
    verifyNever(() => rcpaRepository.fetchRecentForDashboard());
  });

  test('an employee with no entries is present with no key in entriesByEmployee', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final admin = MockUser();
    when(() => admin.email).thenReturn('bharathbiomedpharma@gmail.com');
    when(() => admin.uid).thenReturn('admin-uid');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(admin));
    when(() => employeeRepository.fetchAll()).thenAnswer((_) async => [rep]);
    when(() => rcpaRepository.fetchRecentForDashboard()).thenAnswer((_) async => []);

    await container.read(authControllerProvider.future);
    final data = await container.read(rcpaDashboardControllerProvider.future);

    expect(data.employees, [rep]);
    expect(data.entriesByEmployee, isEmpty);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final admin = MockUser();
    when(() => admin.email).thenReturn('bharathbiomedpharma@gmail.com');
    when(() => admin.uid).thenReturn('admin-uid');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(admin));
    when(() => employeeRepository.fetchAll()).thenAnswer((_) async => [rep]);
    when(() => rcpaRepository.fetchRecentForDashboard()).thenAnswer((_) async => []);
    await container.read(authControllerProvider.future);
    await container.read(rcpaDashboardControllerProvider.future);

    when(() => rcpaRepository.fetchRecentForDashboard()).thenThrow(Exception('offline'));
    await container.read(rcpaDashboardControllerProvider.notifier).refresh();

    expect(container.read(rcpaDashboardControllerProvider).hasError, isTrue);
  });
}
