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
  });

  setUp(() {
    local = MockProductLocalDataSource();
    remote = MockProductRemoteDataSource();
    repository = ProductRepository(remote: remote, local: local);
  });

  group('hasCachedCatalog', () {
    test('is false when the local cache is empty', () async {
      when(() => local.getProducts()).thenAnswer((_) async => []);
      expect(await repository.hasCachedCatalog(), isFalse);
    });

    test('is true when the local cache has products', () async {
      when(() => local.getProducts()).thenAnswer((_) async => [product]);
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
  });
}
