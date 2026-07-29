import 'package:bharathbiomedpharma/data/local/leave_request_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/leave_request_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/leave_request_repository.dart';
import 'package:bharathbiomedpharma/domain/models/leave_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLeaveRequestLocalDataSource extends Mock implements LeaveRequestLocalDataSource {}

class MockLeaveRequestRemoteDataSource extends Mock implements LeaveRequestRemoteDataSource {}

void main() {
  late MockLeaveRequestLocalDataSource local;
  late MockLeaveRequestRemoteDataSource remote;
  late LeaveRequestRepository repository;

  final request = LeaveRequest(
    id: '',
    mrUid: 'mr1',
    mrName: 'Rajesh',
    leaveType: LeaveType.casual,
    startDate: '2026-08-03',
    endDate: '2026-08-04',
    reason: 'Family function',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    local = MockLeaveRequestLocalDataSource();
    remote = MockLeaveRequestRemoteDataSource();
    repository = LeaveRequestRepository(local: local, remote: remote);
  });

  group('submit', () {
    test('queues the request locally with status pending and the correct dates', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});

      await repository.submit(request);

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['status'], 'pending');
      expect(captured['mrUid'], 'mr1');
      expect(captured['startDate'], '2026-08-03');
      expect(captured['endDate'], '2026-08-04');
      expect(captured['leaveType'], 'casual');
    });
  });

  group('countPendingUpload', () {
    test('delegates to the local data source', () async {
      when(() => local.countUnsynced()).thenAnswer((_) async => 1);
      expect(await repository.countPendingUpload(), 1);
    });
  });

  group('uploadPending', () {
    test('uploads each queued request and marks only the successful ones synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [
            const PendingLeaveRequest(localId: 'ok', data: {'mrUid': 'mr1'}),
            const PendingLeaveRequest(localId: 'fail', data: {'mrUid': 'mr2'}),
          ]);
      when(() => remote.create('ok', any())).thenAnswer((_) async {});
      when(() => remote.create('fail', any())).thenThrow(Exception('network down'));
      when(() => local.markSynced(any())).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => local.markSynced(['ok'])).called(1);
    });

    test('does nothing when the queue is empty', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);

      await repository.uploadPending();

      verifyNever(() => remote.create(any(), any()));
      verifyNever(() => local.markSynced(any()));
    });
  });

  group('approve/reject', () {
    test('approve delegates to the remote data source', () async {
      when(() => remote.approve('r1', approvedByUid: 'mgr1')).thenAnswer((_) async {});
      await repository.approve('r1', approvedByUid: 'mgr1');
      verify(() => remote.approve('r1', approvedByUid: 'mgr1')).called(1);
    });

    test('reject delegates to the remote data source', () async {
      when(() => remote.reject('r1', approvedByUid: 'mgr1', reason: 'team short-staffed')).thenAnswer((_) async {});
      await repository.reject('r1', approvedByUid: 'mgr1', reason: 'team short-staffed');
      verify(() => remote.reject('r1', approvedByUid: 'mgr1', reason: 'team short-staffed')).called(1);
    });
  });
}
