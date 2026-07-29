import 'package:bharathbiomedpharma/data/local/order_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/order_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderLocalDataSource extends Mock implements OrderLocalDataSource {}

class MockOrderRemoteDataSource extends Mock implements OrderRemoteDataSource {}

void main() {
  late MockOrderLocalDataSource local;
  late MockOrderRemoteDataSource remote;
  late OrderRepository repository;

  final order = Order(
    id: '',
    agencyId: 'a1',
    agencyName: 'MedSupply Co',
    createdByUid: 'mr1',
    createdByName: 'Rajesh',
    items: const [OrderItem(productId: 'p1', productName: 'Paracetamol', quantity: 10, unitPrice: 5)],
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    local = MockOrderLocalDataSource();
    remote = MockOrderRemoteDataSource();
    repository = OrderRepository(local: local, remote: remote);
  });

  group('submit', () {
    test('queues the order locally with status pending and the correct total', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});

      await repository.submit(order);

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['status'], 'pending');
      expect(captured['agencyId'], 'a1');
      expect(captured['totalValue'], 50);
    });
  });

  group('countPendingUpload', () {
    test('delegates to the local data source', () async {
      when(() => local.countUnsynced()).thenAnswer((_) async => 2);
      expect(await repository.countPendingUpload(), 2);
    });
  });

  group('uploadPending', () {
    test('uploads each queued order and marks only the successful ones synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [
            const PendingOrder(localId: 'ok', data: {'agencyId': 'a1'}),
            const PendingOrder(localId: 'fail', data: {'agencyId': 'a2'}),
          ]);
      when(() => remote.create('ok', any())).thenAnswer((_) async {});
      when(() => remote.create('fail', any())).thenThrow(Exception('network down'));
      when(() => local.markSynced(any())).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => local.markSynced(['ok'])).called(1);
    });
  });

  group('approve/reject/dispatch', () {
    test('approve delegates to the remote data source', () async {
      when(() => remote.approve('o1', approvedByUid: 'admin1')).thenAnswer((_) async {});
      await repository.approve('o1', approvedByUid: 'admin1');
      verify(() => remote.approve('o1', approvedByUid: 'admin1')).called(1);
    });

    test('reject delegates to the remote data source', () async {
      when(() => remote.reject('o1', approvedByUid: 'admin1', reason: 'out of stock')).thenAnswer((_) async {});
      await repository.reject('o1', approvedByUid: 'admin1', reason: 'out of stock');
      verify(() => remote.reject('o1', approvedByUid: 'admin1', reason: 'out of stock')).called(1);
    });

    test('dispatch delegates to the remote data source', () async {
      when(() => remote.dispatch('o1')).thenAnswer((_) async {});
      await repository.dispatch('o1');
      verify(() => remote.dispatch('o1')).called(1);
    });

    test('markDelivered delegates to the remote data source', () async {
      when(() => remote.markDelivered('o1')).thenAnswer((_) async {});
      await repository.markDelivered('o1');
      verify(() => remote.markDelivered('o1')).called(1);
    });
  });
}
