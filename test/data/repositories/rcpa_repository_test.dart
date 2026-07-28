import 'package:bharathbiomedpharma/data/local/rcpa_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/rcpa_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/domain/models/rcpa_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRcpaLocalDataSource extends Mock implements RcpaLocalDataSource {}

class MockRcpaRemoteDataSource extends Mock implements RcpaRemoteDataSource {}

void main() {
  late MockRcpaLocalDataSource local;
  late MockRcpaRemoteDataSource remote;
  late RcpaRepository repository;

  final entry = RcpaEntry(
    id: 'e1',
    mrUid: 'mr1',
    pharmacyId: 'ph1',
    pharmacyName: 'City Chemist',
    auditDate: '2026-07-28',
    ownBrandCounts: const [RcpaProductCount(productId: 'p1', productName: 'Paracetamol', count: 5)],
    competitorCounts: const [RcpaCompetitorCount(brandName: 'CompetitorX', count: 2)],
    createdAt: DateTime(2026, 7, 28),
  );

  setUpAll(() {
    registerFallbackValue(<RcpaEntry>[]);
  });

  setUp(() {
    local = MockRcpaLocalDataSource();
    remote = MockRcpaRemoteDataSource();
    repository = RcpaRepository(local: local, remote: remote);
  });

  test('logEntry writes to the local queue', () async {
    when(() => local.insert(entry)).thenAnswer((_) async {});
    await repository.logEntry(entry);
    verify(() => local.insert(entry)).called(1);
  });

  test('loadForMr delegates to the local data source', () async {
    when(() => local.getForMr('mr1')).thenAnswer((_) async => [entry]);
    expect(await repository.loadForMr('mr1'), [entry]);
  });

  test('countPendingUpload delegates to the local data source', () async {
    when(() => local.countUnsynced()).thenAnswer((_) async => 4);
    expect(await repository.countPendingUpload(), 4);
  });

  group('uploadPending', () {
    test('uploads unsynced entries and marks them synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [entry]);
      when(() => remote.upload([entry])).thenAnswer((_) async {});
      when(() => local.markSynced(['e1'])).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => remote.upload([entry])).called(1);
      verify(() => local.markSynced(['e1'])).called(1);
    });

    test('does nothing when the queue is empty', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);
      await repository.uploadPending();
      verifyNever(() => remote.upload(any()));
    });
  });

  test('fetchRecentForEmployees delegates to the remote data source', () async {
    when(() => remote.fetchRecentForEmployees(['mr1', 'mr2'])).thenAnswer((_) async => [entry]);
    expect(await repository.fetchRecentForEmployees(['mr1', 'mr2']), [entry]);
  });
}
