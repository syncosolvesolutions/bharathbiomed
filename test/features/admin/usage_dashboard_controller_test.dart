import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/usage_session.dart';
import 'package:bharathbiomedpharma/features/admin/usage_dashboard_controller.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/profile/profile_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockUsageSessionRepository extends Mock implements UsageSessionRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository authRepository;
  late MockEmployeeRepository employeeRepository;
  late MockUsageSessionRepository usageSessionRepository;

  ProviderContainer buildContainer() {
    authRepository = MockAuthRepository();
    employeeRepository = MockEmployeeRepository();
    usageSessionRepository = MockUsageSessionRepository();
    return ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      employeeRepositoryProvider.overrideWithValue(employeeRepository),
      usageSessionRepositoryProvider.overrideWithValue(usageSessionRepository),
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

  final session1 = UsageSession(
    id: 's1',
    employeeUid: 'rep1',
    username: 'rajesh_kumar',
    openedAt: DateTime(2026, 7, 1, 9),
    closedAt: DateTime(2026, 7, 1, 9, 30),
    latitude: 12.9,
    longitude: 77.6,
  );

  final session2 = UsageSession(
    id: 's2',
    employeeUid: 'rep1',
    username: 'rajesh_kumar',
    openedAt: DateTime(2026, 7, 2, 10),
    closedAt: DateTime(2026, 7, 2, 10, 15),
  );

  test('an admin sees every employee, fetched via fetchRecentForDashboard', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final admin = MockUser();
    when(() => admin.email).thenReturn('bharathbiomedpharma@gmail.com');
    when(() => admin.uid).thenReturn('admin-uid');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(admin));
    when(() => employeeRepository.fetchAll()).thenAnswer((_) async => [rep]);
    when(() => usageSessionRepository.fetchRecentForDashboard()).thenAnswer((_) async => [session1, session2]);

    // Resolve auth state first — otherwise UsageDashboardController.build()
    // could race authControllerProvider's own async build() and read a null
    // (not-yet-signed-in) user, wrongly falling back to the downline branch.
    await container.read(authControllerProvider.future);
    final data = await container.read(usageDashboardControllerProvider.future);

    expect(data.summaries, hasLength(1));
    final summary = data.summaries.single;
    expect(summary.employee, rep);
    expect(summary.sessionCount, 2);
    expect(summary.totalDuration, const Duration(minutes: 45));
    expect(summary.lastOpenedAt, session2.openedAt);
    expect(summary.hasLastLocation, isFalse);
    verifyNever(() => employeeRepository.fetchDownline(any()));
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
      permissions: ['approve_orders'],
    );
    when(() => employeeRepository.watchMine('mgr1')).thenAnswer((_) => Stream.value(managerProfile));
    when(() => employeeRepository.fetchDownline('mgr1')).thenAnswer((_) async => [rep]);
    when(() => usageSessionRepository.fetchRecentForEmployees(['rep1'])).thenAnswer((_) async => [session1]);

    // Resolve auth state, then the manager's own profile stream, before the
    // dashboard reads hasGlobalVisibilityProvider/resolveVisibleEmployees off
    // them — otherwise either read could race their own async resolution.
    await container.read(authControllerProvider.future);
    await container.read(myEmployeeProfileProvider.future);

    final data = await container.read(usageDashboardControllerProvider.future);

    expect(data.summaries, hasLength(1));
    expect(data.summaries.single.sessionCount, 1);
    expect(data.summaries.single.hasLastLocation, isTrue);
    verifyNever(() => employeeRepository.fetchAll());
    verifyNever(() => usageSessionRepository.fetchRecentForDashboard());
  });
}
