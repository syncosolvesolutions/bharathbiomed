import 'package:bharathbiomedpharma/data/local/doctor_change_request_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/doctor_change_request_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_change_request_repository.dart';
import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDoctorChangeRequestLocalDataSource extends Mock implements DoctorChangeRequestLocalDataSource {}

class MockDoctorChangeRequestRemoteDataSource extends Mock implements DoctorChangeRequestRemoteDataSource {}

void main() {
  late MockDoctorChangeRequestLocalDataSource local;
  late MockDoctorChangeRequestRemoteDataSource remote;
  late DoctorChangeRequestRepository repository;

  const proposed = Doctor(id: 'ignored', name: 'Dr. Anjali Verma', hospitalName: 'City Care Hospital');

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    local = MockDoctorChangeRequestLocalDataSource();
    remote = MockDoctorChangeRequestRemoteDataSource();
    repository = DoctorChangeRequestRepository(local: local, remote: remote);
  });

  group('submitCreate', () {
    test('queues a pending create request with no doctorId', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});

      await repository.submitCreate(proposed, requestedByUid: 'mr1', requestedByName: 'Rajesh');

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['type'], 'create');
      expect(captured['doctorId'], isNull);
      expect(captured['status'], 'pending');
      expect(captured['requestedByUid'], 'mr1');
      expect((captured['proposedData'] as Map)['name'], 'Dr. Anjali Verma');
      // proposedDataFromDoctor strips the placeholder id — there's nothing
      // meaningful to propose an id for on a brand-new doctor.
      expect((captured['proposedData'] as Map).containsKey('id'), isFalse);
    });
  });

  group('submitUpdate', () {
    test('queues a pending update request carrying the existing doctorId', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});
      const existing = Doctor(id: 'doc1', name: 'Dr. Anjali Verma', hospitalName: 'City Care Hospital');

      await repository.submitUpdate(existing, requestedByUid: 'mr1', requestedByName: 'Rajesh');

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['type'], 'update');
      expect(captured['doctorId'], 'doc1');
    });
  });

  group('countPendingUpload', () {
    test('delegates to the local data source', () async {
      when(() => local.countUnsynced()).thenAnswer((_) async => 2);
      expect(await repository.countPendingUpload(), 2);
    });
  });

  group('uploadPending', () {
    test('uploads each queued request and marks only the successful ones synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [
            const PendingDoctorChangeRequest(localId: 'ok', data: {'type': 'create'}),
            const PendingDoctorChangeRequest(localId: 'fail', data: {'type': 'update'}),
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

  group('fetchPending / fetchMine', () {
    test('fetchPending delegates to the remote data source', () async {
      when(() => remote.fetchPending()).thenAnswer((_) async => const []);
      await repository.fetchPending();
      verify(() => remote.fetchPending()).called(1);
    });

    test('fetchMine delegates to the remote data source', () async {
      when(() => remote.fetchMine('mr1')).thenAnswer((_) async => const []);
      await repository.fetchMine('mr1');
      verify(() => remote.fetchMine('mr1')).called(1);
    });
  });

  group('review', () {
    test('delegates to the remote data source', () async {
      when(() => remote.review('req1', approve: true, reviewNote: null)).thenAnswer((_) async {});

      await repository.review('req1', approve: true);

      verify(() => remote.review('req1', approve: true, reviewNote: null)).called(1);
    });

    test('rejecting carries an optional review note through', () async {
      when(() => remote.review('req1', approve: false, reviewNote: 'duplicate entry')).thenAnswer((_) async {});

      await repository.review('req1', approve: false, reviewNote: 'duplicate entry');

      verify(() => remote.review('req1', approve: false, reviewNote: 'duplicate entry')).called(1);
    });
  });
}
