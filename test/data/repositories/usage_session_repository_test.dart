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
