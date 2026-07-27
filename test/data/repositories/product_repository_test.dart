import 'package:bharathbiomedpharma/data/local/product_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/product_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProductLocalDataSource extends Mock implements ProductLocalDataSource {}

class MockProductRemoteDataSource extends Mock implements ProductRemoteDataSource {}

void main() {
  late MockProductLocalDataSource local;
  late MockProductRemoteDataSource remote;
  late ProductRepository repository;

  const product = Product(
    id: 'p1',
    name: 'Paracetamol',
    info: 'Pain relief',
    departments: {'General': 0},
    imageUrl: 'https://example.com/p1.png',
  );

  setUpAll(() {
    registerFallbackValue(<Product>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, int>{});
    registerFallbackValue(product);
  });

  setUp(() {
    local = MockProductLocalDataSource();
    remote = MockProductRemoteDataSource();
    repository = ProductRepository(
      remote: remote,
      local: local,
      // Real image precaching hits platform channels (path_provider) that
      // aren't available in plain `test()` unit tests; these tests care
      // about repository logic, not image-cache warming, so stub it out.
      precacheImages: (_) async {},
    );
  });

  group('hasCachedCatalog', () {
    test('is false when the local cache is empty', () async {
      when(() => local.hasProducts()).thenAnswer((_) async => false);
      expect(await repository.hasCachedCatalog(), isFalse);
    });

    test('is true when the local cache has products', () async {
      when(() => local.hasProducts()).thenAnswer((_) async => true);
      expect(await repository.hasCachedCatalog(), isTrue);
    });
  });

  group('loadCachedCatalog', () {
    test('reads directly from local storage without touching Firestore', () async {
      when(() => local.getProducts()).thenAnswer((_) async => [product]);
      when(() => local.getDepartments()).thenAnswer((_) async => ['General']);

      final snapshot = await repository.loadCachedCatalog();

      expect(snapshot.products, [product]);
      expect(snapshot.departments, ['General']);
      verifyNever(() => remote.fetchProducts());
      verifyNever(() => remote.fetchDepartments());
    });
  });

  group('sync', () {
    test('fetches from Firestore and overwrites the local cache', () async {
      when(() => remote.fetchProducts()).thenAnswer((_) async => [product]);
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['General']);
      when(() => local.replaceAll(products: any(named: 'products'), departments: any(named: 'departments')))
          .thenAnswer((_) async {});

      final snapshot = await repository.sync();

      expect(snapshot.products, [product]);
      expect(snapshot.departments, ['General']);
      verify(() => local.replaceAll(products: [product], departments: ['General'])).called(1);
    });

    test('propagates remote failures without touching the local cache', () async {
      when(() => remote.fetchProducts()).thenThrow(Exception('network down'));

      expect(() => repository.sync(), throwsException);
      verifyNever(() => local.replaceAll(products: any(named: 'products'), departments: any(named: 'departments')));
    });

    test('refuses to overwrite the local cache when Firestore returns an empty catalog', () async {
      when(() => remote.fetchProducts()).thenAnswer((_) async => []);
      when(() => remote.fetchDepartments()).thenAnswer((_) async => []);

      expect(() => repository.sync(), throwsException);
      verifyNever(() => local.replaceAll(products: any(named: 'products'), departments: any(named: 'departments')));
    });

    test('kicks off best-effort precaching of product images after a successful sync', () async {
      when(() => remote.fetchProducts()).thenAnswer((_) async => [product]);
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['General']);
      when(() => local.replaceAll(products: any(named: 'products'), departments: any(named: 'departments')))
          .thenAnswer((_) async {});

      List<String>? precachedUrls;
      final repositoryWithPrecacheSpy = ProductRepository(
        remote: remote,
        local: local,
        precacheImages: (urls) async => precachedUrls = urls,
      );

      await repositoryWithPrecacheSpy.sync();
      await Future<void>.delayed(Duration.zero);

      expect(precachedUrls, [product.imageUrl]);
    });
  });

  group('admin operations', () {
    test('fetchLiveCatalog reads directly from Firestore, not the local cache', () async {
      when(() => remote.fetchProducts()).thenAnswer((_) async => [product]);
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['General']);

      final snapshot = await repository.fetchLiveCatalog();

      expect(snapshot.products, [product]);
      expect(snapshot.departments, ['General']);
      verifyNever(() => local.getProducts());
    });

    test('createProduct delegates to the remote data source', () async {
      when(() => remote.addProduct(
            name: any(named: 'name'),
            info: any(named: 'info'),
            departments: any(named: 'departments'),
            imageUrl: any(named: 'imageUrl'),
          )).thenAnswer((_) async => 'new-id');

      final id = await repository.createProduct(
        name: 'Ibuprofen',
        info: 'Pain relief',
        departments: const {'General': 1},
        imageUrl: 'https://example.com/i.png',
      );

      expect(id, 'new-id');
      verify(() => remote.addProduct(
            name: 'Ibuprofen',
            info: 'Pain relief',
            departments: const {'General': 1},
            imageUrl: 'https://example.com/i.png',
          )).called(1);
    });

    test('updateProduct and deleteProduct delegate to the remote data source', () async {
      when(() => remote.updateProduct(any())).thenAnswer((_) async {});
      when(() => remote.deleteProduct(any())).thenAnswer((_) async {});

      await repository.updateProduct(product);
      await repository.deleteProduct(product.id);

      verify(() => remote.updateProduct(product)).called(1);
      verify(() => remote.deleteProduct(product.id)).called(1);
    });

    test('department management delegates to the remote data source', () async {
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['Cardiology']);
      when(() => remote.addDepartment(any())).thenAnswer((_) async {});
      when(() => remote.renameDepartment(any(), any())).thenAnswer((_) async {});
      when(() => remote.deleteDepartment(any())).thenAnswer((_) async {});

      await repository.addDepartment('Neurology');
      await repository.renameDepartment('Cardiology', 'Cardio');
      await repository.deleteDepartment('Cardio');

      verify(() => remote.addDepartment('Neurology')).called(1);
      verify(() => remote.renameDepartment('Cardiology', 'Cardio')).called(1);
      verify(() => remote.deleteDepartment('Cardio')).called(1);
    });

    test('addDepartment rejects a name that already exists (case-insensitive)', () async {
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['Cardiology']);

      expect(() => repository.addDepartment('cardiology'), throwsException);
      verifyNever(() => remote.addDepartment(any()));
    });

    test('renameDepartment rejects a new name that collides with another department', () async {
      when(() => remote.fetchDepartments()).thenAnswer((_) async => ['Cardiology', 'Neurology']);

      expect(() => repository.renameDepartment('Cardiology', 'neurology'), throwsException);
      verifyNever(() => remote.renameDepartment(any(), any()));
    });
  });
}
