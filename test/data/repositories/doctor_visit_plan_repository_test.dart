import 'package:bharathbiomedpharma/data/local/doctor_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/doctor_visit_plan_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_plan_repository.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDoctorLocalDataSource extends Mock implements DoctorLocalDataSource {}

class MockDoctorVisitPlanRemoteDataSource extends Mock implements DoctorVisitPlanRemoteDataSource {}

void main() {
  late MockDoctorLocalDataSource local;
  late MockDoctorVisitPlanRemoteDataSource remote;
  late DoctorVisitPlanRepository repository;

  setUpAll(() {
    registerFallbackValue(const DoctorVisitPlan(mrUid: 'fallback'));
  });

  setUp(() {
    local = MockDoctorLocalDataSource();
    remote = MockDoctorVisitPlanRemoteDataSource();
    repository = DoctorVisitPlanRepository(local: local, remote: remote);
  });

  group('submitForApproval', () {
    test('fetches the live plan, marks it pending, and saves both sides', () async {
      const draft = DoctorVisitPlan(
        mrUid: 'mr1',
        doctorIdsByWeekday: {'monday': ['d1']},
        status: VisitPlanStatus.rejected,
        rejectedReason: 'too many Mondays',
      );
      when(() => remote.fetch('mr1')).thenAnswer((_) async => draft);
      when(() => remote.save(any())).thenAnswer((_) async {});
      when(() => local.saveVisitPlan(any(), synced: any(named: 'synced'))).thenAnswer((_) async {});

      final result = await repository.submitForApproval('mr1');

      expect(result.status, VisitPlanStatus.pending);
      expect(result.rejectedReason, isNull);
      expect(result.forWeekday('monday'), ['d1']);
      final captured = verify(() => remote.save(captureAny())).captured.single as DoctorVisitPlan;
      expect(captured.status, VisitPlanStatus.pending);
      verify(() => local.saveVisitPlan(any(that: isA<DoctorVisitPlan>()), synced: true)).called(1);
    });
  });

  group('fetchAllPending / fetchPendingForEmployees', () {
    test('fetchAllPending delegates to the remote data source', () async {
      when(() => remote.fetchAllPending()).thenAnswer((_) async => const [DoctorVisitPlan(mrUid: 'mr1')]);
      final result = await repository.fetchAllPending();
      expect(result, hasLength(1));
    });

    test('fetchPendingForEmployees delegates to the remote data source', () async {
      when(() => remote.fetchPendingForEmployees(['mr1', 'mr2'])).thenAnswer((_) async => const []);
      await repository.fetchPendingForEmployees(['mr1', 'mr2']);
      verify(() => remote.fetchPendingForEmployees(['mr1', 'mr2'])).called(1);
    });
  });

  group('approve/reject', () {
    test('approve delegates to the remote data source', () async {
      when(() => remote.approve('mr1', approvedByUid: 'mgr1')).thenAnswer((_) async {});
      await repository.approve('mr1', approvedByUid: 'mgr1');
      verify(() => remote.approve('mr1', approvedByUid: 'mgr1')).called(1);
    });

    test('reject delegates to the remote data source', () async {
      when(() => remote.reject('mr1', approvedByUid: 'mgr1', reason: 'too aggressive')).thenAnswer((_) async {});
      await repository.reject('mr1', approvedByUid: 'mgr1', reason: 'too aggressive');
      verify(() => remote.reject('mr1', approvedByUid: 'mgr1', reason: 'too aggressive')).called(1);
    });
  });
}
