import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/domain/models/product_batch.dart';
import 'package:bharathbiomedpharma/features/admin/admin_catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockProductRepository repository;
  late ProviderContainer container;

  const product = Product(id: 'p1', name: 'Paracetamol', info: 'Pain relief', departments: {'General': 0}, imageUrl: '');
  const emptySnapshot = CatalogSnapshot(products: [], departments: []);
  const snapshotWithProduct = CatalogSnapshot(products: [product], departments: ['General']);

  setUp(() {
    repository = MockProductRepository();
    container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );

    // AdminCatalogController's mutation methods best-effort resync the
    // device's own offline catalog cache via CatalogController.sync(),
    // swallowing any failure (see AdminCatalogController._resyncDeviceCache's
    // doc comment) — stub the two calls that resync path makes so every
    // mutation test below exercises that documented "best effort" branch
    // deterministically instead of depending on unstubbed-mock behavior.
    when(() => repository.loadCachedCatalog()).thenAnswer((_) async => emptySnapshot);
    when(() => repository.sync()).thenThrow(Exception('offline'));
  });

  tearDown(() => container.dispose());

  test('build fetches the live catalog from Firestore, not the local cache', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);

    final result = await container.read(adminCatalogControllerProvider.future);

    expect(result, snapshotWithProduct);
    verifyNever(() => repository.loadCachedCatalog());
  });

  test('createProduct creates then refreshes from the live catalog', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => emptySnapshot);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.createProduct(
          name: any(named: 'name'),
          info: any(named: 'info'),
          departments: any(named: 'departments'),
          imageUrl: any(named: 'imageUrl'),
          unitPrice: any(named: 'unitPrice'),
        )).thenAnswer((_) async => 'p1');
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);

    await container.read(adminCatalogControllerProvider.notifier).createProduct(
          name: 'Paracetamol',
          info: 'Pain relief',
          departments: {'General': 0},
          imageUrl: '',
        );

    expect(container.read(adminCatalogControllerProvider).value, snapshotWithProduct);
  });

  test('deleteProduct deletes then refreshes from the live catalog', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.deleteProduct('p1')).thenAnswer((_) async {});
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => emptySnapshot);

    await container.read(adminCatalogControllerProvider.notifier).deleteProduct('p1');

    expect(container.read(adminCatalogControllerProvider).value, emptySnapshot);
    verify(() => repository.deleteProduct('p1')).called(1);
  });

  test('addDepartment adds then refreshes from the live catalog', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => emptySnapshot);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.addDepartment('Cardiology')).thenAnswer((_) async {});
    const withDepartment = CatalogSnapshot(products: [], departments: ['Cardiology']);
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => withDepartment);

    await container.read(adminCatalogControllerProvider.notifier).addDepartment('Cardiology');

    expect(container.read(adminCatalogControllerProvider).value, withDepartment);
  });

  test('adjustStock delegates the delta then refreshes', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.adjustStock('p1', 10)).thenAnswer((_) async {});
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);

    await container.read(adminCatalogControllerProvider.notifier).adjustStock('p1', 10);

    verify(() => repository.adjustStock('p1', 10)).called(1);
  });

  test('addBatch adds a batch then refreshes', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.addBatch('p1', batchNumber: 'B1', expiryDate: '2027-01-01', quantity: 100))
        .thenAnswer((_) async {});
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);

    await container
        .read(adminCatalogControllerProvider.notifier)
        .addBatch('p1', batchNumber: 'B1', expiryDate: '2027-01-01', quantity: 100);

    verify(() => repository.addBatch('p1', batchNumber: 'B1', expiryDate: '2027-01-01', quantity: 100)).called(1);
  });

  test('a failing refresh surfaces as an AsyncError state, not a thrown exception', () async {
    when(() => repository.fetchLiveCatalog()).thenAnswer((_) async => snapshotWithProduct);
    await container.read(adminCatalogControllerProvider.future);

    when(() => repository.deleteProduct('p1')).thenAnswer((_) async {});
    when(() => repository.fetchLiveCatalog()).thenThrow(Exception('network error'));

    await container.read(adminCatalogControllerProvider.notifier).deleteProduct('p1');

    expect(container.read(adminCatalogControllerProvider).hasError, isTrue);
  });

  group('expiringBatchesProvider', () {
    test('fetches batches expiring within 90 days', () async {
      const batch = ProductBatch(id: 'b1', productId: 'p1', batchNumber: 'B1', expiryDate: '2026-08-01', quantity: 5);
      when(() => repository.fetchExpiringWithinDays(90)).thenAnswer((_) async => [batch]);

      final result = await container.read(expiringBatchesProvider.future);

      expect(result, [batch]);
    });
  });

  group('productBatchesProvider', () {
    test('fetches batches for the given product id', () async {
      const batch = ProductBatch(id: 'b1', productId: 'p1', batchNumber: 'B1', expiryDate: '2026-08-01', quantity: 5);
      when(() => repository.fetchBatches('p1')).thenAnswer((_) async => [batch]);

      final result = await container.read(productBatchesProvider('p1').future);

      expect(result, [batch]);
    });
  });
}
