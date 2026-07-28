import 'package:bharathbiomedpharma/data/local/doctor_visit_log_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/doctor_visit_log_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_log_repository.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDoctorVisitLogLocalDataSource extends Mock implements DoctorVisitLogLocalDataSource {}

class MockDoctorVisitLogRemoteDataSource extends Mock implements DoctorVisitLogRemoteDataSource {}

void main() {
  late MockDoctorVisitLogLocalDataSource local;
  late MockDoctorVisitLogRemoteDataSource remote;
  late DoctorVisitLogRepository repository;

  final log = DoctorVisitLog(
    id: 'l1',
    mrUid: 'mr1',
    doctorId: 'd1',
    doctorName: 'Dr. Rao',
    visitDate: '2026-01-01',
    visited: true,
    feedback: 'Positive',
    createdAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(log);
  });

  setUp(() {
    local = MockDoctorVisitLogLocalDataSource();
    remote = MockDoctorVisitLogRemoteDataSource();
    repository = DoctorVisitLogRepository(local: local, remote: remote);
  });

  group('logVisit', () {
    test('queues a log with no samples given by default', () async {
      when(() => local.insert(any())).thenAnswer((_) async {});

      await repository.logVisit(
        mrUid: 'mr1',
        doctorId: 'd1',
        doctorName: 'Dr. Rao',
        visitDate: '2026-01-01',
        visited: true,
        feedback: 'Positive',
      );

      final captured = verify(() => local.insert(captureAny())).captured.single as DoctorVisitLog;
      expect(captured.samplesGiven, isEmpty);
    });

    test('queues a log with the given samplesGiven', () async {
      when(() => local.insert(any())).thenAnswer((_) async {});

      await repository.logVisit(
        mrUid: 'mr1',
        doctorId: 'd1',
        doctorName: 'Dr. Rao',
        visitDate: '2026-01-01',
        visited: true,
        feedback: 'Positive',
        samplesGiven: const {'Paracetamol strip': 2},
      );

      final captured = verify(() => local.insert(captureAny())).captured.single as DoctorVisitLog;
      expect(captured.samplesGiven, {'Paracetamol strip': 2});
    });
  });

  group('countPendingUpload', () {
    test('reflects how many logs are queued locally', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [log]);
      expect(await repository.countPendingUpload(), 1);
    });

    test('is zero when nothing is queued', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);
      expect(await repository.countPendingUpload(), 0);
    });
  });

  group('fetchRecentForEmployees', () {
    test('delegates to the remote data source with the given mr uids', () async {
      when(() => remote.fetchRecentForEmployees(['mr1', 'mr2'])).thenAnswer((_) async => [log]);

      final result = await repository.fetchRecentForEmployees(['mr1', 'mr2']);

      expect(result, [log]);
      verify(() => remote.fetchRecentForEmployees(['mr1', 'mr2'])).called(1);
    });
  });
}
