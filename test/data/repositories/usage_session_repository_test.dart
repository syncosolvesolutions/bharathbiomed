import 'package:bharathbiomedpharma/data/local/usage_session_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/usage_session_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/domain/models/usage_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUsageSessionLocalDataSource extends Mock implements UsageSessionLocalDataSource {}

class MockUsageSessionRemoteDataSource extends Mock implements UsageSessionRemoteDataSource {}

void main() {
  late MockUsageSessionLocalDataSource local;
  late MockUsageSessionRemoteDataSource remote;
  late UsageSessionRepository repository;

  final session = UsageSession(
    id: 's1',
    employeeUid: 'uid1',
    username: 'rajesh',
    openedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    local = MockUsageSessionLocalDataSource();
    remote = MockUsageSessionRemoteDataSource();
    repository = UsageSessionRepository(local: local, remote: remote);
  });

  setUpAll(() {
    registerFallbackValue(session);
  });

  group('startSession', () {
    test('closes any dangling session for this employee before inserting the new one', () async {
      when(() => local.closeDanglingSessions('mr1')).thenAnswer((_) async {});
      when(() => local.insert(any())).thenAnswer((_) async {});

      await repository.startSession(employeeUid: 'mr1', username: 'rajesh');

      verifyInOrder([
        () => local.closeDanglingSessions('mr1'),
        () => local.insert(any()),
      ]);
    });

    test('inserts a session carrying the given employee, username, and best-effort location', () async {
      when(() => local.closeDanglingSessions(any())).thenAnswer((_) async {});
      when(() => local.insert(any())).thenAnswer((_) async {});

      await repository.startSession(employeeUid: 'mr1', username: 'rajesh', latitude: 12.9, longitude: 77.6);

      final inserted = verify(() => local.insert(captureAny())).captured.single as UsageSession;
      expect(inserted.employeeUid, 'mr1');
      expect(inserted.username, 'rajesh');
      expect(inserted.latitude, 12.9);
      expect(inserted.longitude, 77.6);
      expect(inserted.closedAt, isNull);
    });

    test('returns the new session\'s local id, for closeSession to use later', () async {
      when(() => local.closeDanglingSessions(any())).thenAnswer((_) async {});
      when(() => local.insert(any())).thenAnswer((_) async {});

      final id = await repository.startSession(employeeUid: 'mr1', username: 'rajesh');

      final inserted = verify(() => local.insert(captureAny())).captured.single as UsageSession;
      expect(id, inserted.id);
    });
  });

  group('closeSession', () {
    test('delegates to the local data source', () async {
      when(() => local.close('s1', any())).thenAnswer((_) async {});

      await repository.closeSession('s1');

      verify(() => local.close('s1', any())).called(1);
    });
  });

  group('uploadPending', () {
    test('uploads every queued session then marks them all synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [session]);
      when(() => remote.upload([session])).thenAnswer((_) async {});
      when(() => local.markSynced(['s1'])).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => remote.upload([session])).called(1);
      verify(() => local.markSynced(['s1'])).called(1);
    });

    test('does nothing when the queue is empty', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);

      await repository.uploadPending();

      verifyNever(() => remote.upload(any()));
      verifyNever(() => local.markSynced(any()));
    });
  });

  group('fetchRecentForDashboard', () {
    test('delegates to the remote data source', () async {
      when(() => remote.fetchRecent()).thenAnswer((_) async => [session]);
      expect(await repository.fetchRecentForDashboard(), [session]);
    });
  });

  group('countPendingUpload', () {
    test('reflects how many sessions are queued locally', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [session]);
      expect(await repository.countPendingUpload(), 1);
    });

    test('is zero when nothing is queued', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);
      expect(await repository.countPendingUpload(), 0);
    });
  });

  group('fetchRecentForEmployees', () {
    test('delegates to the remote data source with the given uids', () async {
      when(() => remote.fetchRecentForEmployees(['uid1', 'uid2'])).thenAnswer((_) async => [session]);

      final result = await repository.fetchRecentForEmployees(['uid1', 'uid2']);

      expect(result, [session]);
      verify(() => remote.fetchRecentForEmployees(['uid1', 'uid2'])).called(1);
    });
  });
}
