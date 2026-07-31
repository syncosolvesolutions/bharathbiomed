import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_plan_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_plan.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/doctors/visit_plan_approval_controller.dart';
import 'package:bharathbiomedpharma/features/profile/profile_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockEmployeeRepository extends Mock implements EmployeeRepository {}

class MockDoctorVisitPlanRepository extends Mock implements DoctorVisitPlanRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository authRepository;
  late MockEmployeeRepository employeeRepository;
  late MockDoctorVisitPlanRepository doctorVisitPlanRepository;

  const rep = Employee(
    uid: 'mr1',
    username: 'rajesh_kumar',
    firstName: 'Rajesh',
    lastName: 'Kumar',
    designation: 'Medical Representative',
    areaName: 'North',
  );

  const managerProfile = Employee(
    uid: 'mgr1',
    username: 'manager',
    firstName: 'Manager',
    lastName: 'One',
    designation: 'Area Business Manager',
    areaName: 'North',
    permissions: ['approve_requests'],
  );

  const pendingPlan = DoctorVisitPlan(
    mrUid: 'mr1',
    doctorIdsByWeekday: {
      'monday': ['doc1']
    },
    status: VisitPlanStatus.pending,
  );

  ProviderContainer buildContainer() {
    authRepository = MockAuthRepository();
    employeeRepository = MockEmployeeRepository();
    doctorVisitPlanRepository = MockDoctorVisitPlanRepository();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      employeeRepositoryProvider.overrideWithValue(employeeRepository),
      doctorVisitPlanRepositoryProvider.overrideWithValue(doctorVisitPlanRepository),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> signedInAsManager() async {
    final container = buildContainer();
    final manager = MockUser();
    when(() => manager.email).thenReturn('manager@example.com');
    when(() => manager.uid).thenReturn('mgr1');
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(manager));
    when(() => employeeRepository.watchMine('mgr1')).thenAnswer((_) => Stream.value(managerProfile));
    when(() => employeeRepository.fetchDownline('mgr1')).thenAnswer((_) async => [rep]);
    await container.read(authControllerProvider.future);
    await container.read(myEmployeeProfileProvider.future);
    return container;
  }

  group('build', () {
    test('a manager without global visibility sees only their downline\'s pending plans', () async {
      final container = await signedInAsManager();
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => [pendingPlan]);

      final data = await container.read(visitPlanApprovalControllerProvider.future);

      expect(data.employees, [rep]);
      expect(data.plans, [pendingPlan]);
      verifyNever(() => doctorVisitPlanRepository.fetchAllPending());
    });

    test('an admin sees every pending plan via fetchAllPending', () async {
      final container = buildContainer();
      final admin = MockUser();
      when(() => admin.email).thenReturn('bharathbiomedpharma@gmail.com');
      when(() => admin.uid).thenReturn('admin1');
      when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(admin));
      when(() => employeeRepository.fetchAll()).thenAnswer((_) async => [rep]);
      when(() => doctorVisitPlanRepository.fetchAllPending()).thenAnswer((_) async => [pendingPlan]);
      await container.read(authControllerProvider.future);

      final data = await container.read(visitPlanApprovalControllerProvider.future);

      expect(data.plans, [pendingPlan]);
      verifyNever(() => doctorVisitPlanRepository.fetchPendingForEmployees(any()));
    });
  });

  group('approve', () {
    test('approves as the signed-in manager, then refreshes the pending list', () async {
      final container = await signedInAsManager();
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => [pendingPlan]);
      await container.read(visitPlanApprovalControllerProvider.future);

      when(() => doctorVisitPlanRepository.approve('mr1', approvedByUid: 'mgr1')).thenAnswer((_) async {});
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => []);

      await container.read(visitPlanApprovalControllerProvider.notifier).approve('mr1');

      verify(() => doctorVisitPlanRepository.approve('mr1', approvedByUid: 'mgr1')).called(1);
      expect(container.read(visitPlanApprovalControllerProvider).value?.plans, isEmpty);
    });
  });

  group('reject', () {
    test('rejects as the signed-in manager with an optional reason, then refreshes the pending list', () async {
      final container = await signedInAsManager();
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => [pendingPlan]);
      await container.read(visitPlanApprovalControllerProvider.future);

      when(() => doctorVisitPlanRepository.reject('mr1', approvedByUid: 'mgr1', reason: 'too many visits'))
          .thenAnswer((_) async {});
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => []);

      await container.read(visitPlanApprovalControllerProvider.notifier).reject('mr1', reason: 'too many visits');

      verify(() => doctorVisitPlanRepository.reject('mr1', approvedByUid: 'mgr1', reason: 'too many visits'))
          .called(1);
      expect(container.read(visitPlanApprovalControllerProvider).value?.plans, isEmpty);
    });

    test('a reject with no reason passes null through', () async {
      final container = await signedInAsManager();
      when(() => doctorVisitPlanRepository.fetchPendingForEmployees(['mr1'])).thenAnswer((_) async => [pendingPlan]);
      await container.read(visitPlanApprovalControllerProvider.future);

      when(() => doctorVisitPlanRepository.reject('mr1', approvedByUid: 'mgr1', reason: null)).thenAnswer((_) async {});

      await container.read(visitPlanApprovalControllerProvider.notifier).reject('mr1');

      verify(() => doctorVisitPlanRepository.reject('mr1', approvedByUid: 'mgr1', reason: null)).called(1);
    });
  });
}
