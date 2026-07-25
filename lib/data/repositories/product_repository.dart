import '../../domain/models/product.dart';
import '../local/product_local_data_source.dart';
import '../remote/product_remote_data_source.dart';

class CatalogSnapshot {
  const CatalogSnapshot({required this.products, required this.departments});

  final List<Product> products;
  final List<String> departments;
}

/// The app is used offline by default: the catalog is only ever read from the
/// local cache ([loadCachedCatalog]) unless the user explicitly triggers
/// [sync], which is the only method that talks to Firestore.
class ProductRepository {
  ProductRepository({
    ProductRemoteDataSource? remote,
    ProductLocalDataSource? local,
  })  : _remote = remote ?? ProductRemoteDataSource(),
        _local = local ?? ProductLocalDataSource();

  final ProductRemoteDataSource _remote;
  final ProductLocalDataSource _local;

  Future<bool> hasCachedCatalog() async {
    final products = await _local.getProducts();
    return products.isNotEmpty;
  }

  Future<CatalogSnapshot> loadCachedCatalog() async {
    final products = await _local.getProducts();
    final departments = await _local.getDepartments();
    return CatalogSnapshot(products: products, departments: departments);
  }

  /// Fetches the latest catalog from Firestore and overwrites the local cache.
  Future<CatalogSnapshot> sync() async {
    final products = await _remote.fetchProducts();
    final departments = await _remote.fetchDepartments();
    await _local.replaceAll(products: products, departments: departments);
    return CatalogSnapshot(products: products, departments: departments);
  }
}
