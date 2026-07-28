import 'package:bharathbiomedpharma/data/local/entity_change_request_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/entity_change_request_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/entity_change_request_repository.dart';
import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEntityChangeRequestLocalDataSource extends Mock implements EntityChangeRequestLocalDataSource {}

class MockEntityChangeRequestRemoteDataSource extends Mock implements EntityChangeRequestRemoteDataSource {}

void main() {
  late MockEntityChangeRequestLocalDataSource local;
  late MockEntityChangeRequestRemoteDataSource remote;
  late EntityChangeRequestRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    local = MockEntityChangeRequestLocalDataSource();
    remote = MockEntityChangeRequestRemoteDataSource();
    repository = EntityChangeRequestRepository(local: local, remote: remote);
  });

  group('submitAgency', () {
    test('queues a pending create request tagged entityType=agency', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});
      const agency = Agency(id: '', name: 'New Agency', contactPerson: 'Ravi', phone: '999');

      await repository.submitAgency(agency, requestedByUid: 'mr1', requestedByName: 'Rajesh');

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['entityType'], 'agency');
      expect(captured['type'], 'create');
      expect(captured['status'], 'pending');
      expect(captured['requestedByUid'], 'mr1');
      expect((captured['proposedData'] as Map)['name'], 'New Agency');
    });
  });

  group('submitPharmacy', () {
    test('queues a pending create request tagged entityType=pharmacy', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});
      const pharmacy = Pharmacy(id: '', name: 'New Pharmacy');

      await repository.submitPharmacy(pharmacy, requestedByUid: 'mr1', requestedByName: 'Rajesh');

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['entityType'], 'pharmacy');
      expect(captured['type'], 'create');
    });
  });

  group('countPendingUpload', () {
    test('delegates to the local data source', () async {
      when(() => local.countUnsynced()).thenAnswer((_) async => 3);
      expect(await repository.countPendingUpload(), 3);
    });
  });

  group('uploadPending', () {
    test('uploads each queued request and marks only the successful ones synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [
            const PendingEntityChangeRequest(localId: 'ok', data: {'entityType': 'agency'}),
            const PendingEntityChangeRequest(localId: 'fail', data: {'entityType': 'pharmacy'}),
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
    });
  });

  group('review', () {
    test('delegates to the remote data source', () async {
      when(() => remote.review('req1', approve: true, reviewNote: null)).thenAnswer((_) async {});

      await repository.review('req1', approve: true);

      verify(() => remote.review('req1', approve: true, reviewNote: null)).called(1);
    });
  });
}
