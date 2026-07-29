import 'package:bharathbiomedpharma/data/local/compliance_log_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/compliance_log_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/compliance_log_repository.dart';
import 'package:bharathbiomedpharma/domain/models/compliance_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockComplianceLogLocalDataSource extends Mock implements ComplianceLogLocalDataSource {}

class MockComplianceLogRemoteDataSource extends Mock implements ComplianceLogRemoteDataSource {}

void main() {
  late MockComplianceLogLocalDataSource local;
  late MockComplianceLogRemoteDataSource remote;
  late ComplianceLogRepository repository;

  final log = ComplianceLog(
    id: 'c1',
    mrUid: 'mr1',
    mrName: 'Rajesh',
    doctorId: 'd1',
    doctorName: 'Dr. Mehta',
    category: ComplianceCategory.sample,
    value: 500,
    logDate: '2026-07-29',
    createdAt: DateTime(2026, 7, 29),
  );

  setUpAll(() {
    registerFallbackValue(<ComplianceLog>[]);
  });

  setUp(() {
    local = MockComplianceLogLocalDataSource();
    remote = MockComplianceLogRemoteDataSource();
    repository = ComplianceLogRepository(local: local, remote: remote);
  });

  test('logEntry writes to the local queue', () async {
    when(() => local.insert(log)).thenAnswer((_) async {});
    await repository.logEntry(log);
    verify(() => local.insert(log)).called(1);
  });

  test('loadForMr delegates to the local data source', () async {
    when(() => local.getForMr('mr1')).thenAnswer((_) async => [log]);
    expect(await repository.loadForMr('mr1'), [log]);
  });

  test('countPendingUpload delegates to the local data source', () async {
    when(() => local.countUnsynced()).thenAnswer((_) async => 2);
    expect(await repository.countPendingUpload(), 2);
  });

  group('uploadPending', () {
    test('uploads unsynced logs and marks them synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [log]);
      when(() => remote.upload([log])).thenAnswer((_) async {});
      when(() => local.markSynced(['c1'])).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => remote.upload([log])).called(1);
      verify(() => local.markSynced(['c1'])).called(1);
    });

    test('does nothing when the queue is empty', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);
      await repository.uploadPending();
      verifyNever(() => remote.upload(any()));
    });
  });

  test('fetchRecentForEmployees delegates to the remote data source', () async {
    when(() => remote.fetchRecentForEmployees(['mr1', 'mr2'])).thenAnswer((_) async => [log]);
    expect(await repository.fetchRecentForEmployees(['mr1', 'mr2']), [log]);
  });
}
