import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../core/error/app_logger.dart';
import '../../domain/models/product.dart';
import '../local/product_local_data_source.dart';
import '../remote/product_remote_data_source.dart';

class CatalogSnapshot {
  const CatalogSnapshot({required this.products, required this.departments});

  final List<Product> products;
  final List<String> departments;
}

/// The catalog screen only ever reads from the local cache
/// ([loadCachedCatalog]); [sync] is the only method that talks to Firestore,
/// called after sign-in and automatically whenever connectivity returns
/// (see `app.dart`).
class ProductRepository {
  ProductRepository({
    ProductRemoteDataSource? remote,
    ProductLocalDataSource? local,
    Future<void> Function(List<String> imageUrls)? precacheImages,
  })  : _remote = remote ?? ProductRemoteDataSource(),
        _local = local ?? ProductLocalDataSource(),
        _precacheImages = precacheImages ?? _defaultPrecacheImages;

  final ProductRemoteDataSource _remote;
  final ProductLocalDataSource _local;
  final Future<void> Function(List<String> imageUrls) _precacheImages;

  Future<CatalogSnapshot> loadCachedCatalog() async {
    debugPrint('ProductRepository.loadCachedCatalog: loading catalog from local cache');
    final products = await _local.getProducts();
    final departments = await _local.getDepartments();
    debugPrint(
        'ProductRepository.loadCachedCatalog: loaded ${products.length} products, ${departments.length} departments');
    return CatalogSnapshot(products: products, departments: departments);
  }

  /// Fetches the latest catalog from Firestore and overwrites the local cache.
  ///
  /// Refuses to overwrite the cache if Firestore comes back empty: an empty
  /// result is far more likely to mean a misconfigured query, a permissions
  /// change, or a degraded connection than "the catalog is genuinely empty
  /// now" — and since this app is offline-first, silently wiping the local
  /// cache here would delete the only copy of the catalog the device has.
  Future<CatalogSnapshot> sync() async {
    debugPrint('ProductRepository.sync: fetching products from remote');
    final products = await _remote.fetchProducts().timeout(
          _syncTimeout,
          onTimeout: () => throw Exception('Timed out contacting the server. Check your connection and try again.'),
        );
    debugPrint('ProductRepository.sync: fetching departments from remote');
    final departments = await _remote.fetchDepartments().timeout(
          _syncTimeout,
          onTimeout: () => throw Exception('Timed out contacting the server. Check your connection and try again.'),
        );

    if (products.isEmpty || departments.isEmpty) {
      debugPrint('ProductRepository.sync: remote returned empty catalog, aborting sync');
      throw Exception('Server returned an empty catalog; keeping the existing data on this device.');
    }

    debugPrint(
        'ProductRepository.sync: fetched ${products.length} products, ${departments.length} departments; replacing local cache');
    await _local.replaceAll(products: products, departments: departments);

    // Best-effort: warm the image cache so the catalog is actually usable
    // offline right after a sync, instead of only caching each image the
    // first time its card happens to scroll into view. Runs in the
    // background — sync() itself must not block on every product's image
    // download, and a few failed/slow images shouldn't fail the sync.
    final imageUrls = products.map((p) => p.imageUrl).where((url) => url.isNotEmpty).toList();
    unawaited(_precacheImages(imageUrls));

    return CatalogSnapshot(products: products, departments: departments);
  }

  /// Fetches the remote catalog (same reads [sync] would do) and diffs it
  /// against the local cache instead of overwriting it — lets the sync
  /// prompt only show "update available" when something actually changed.
  /// Products are compared by id (a plain collection `.get()` has no
  /// guaranteed order), departments by list equality (a single ordered array
  /// field, so order is meaningful and stable).
  Future<bool> hasRemoteChanges() async {
    debugPrint('ProductRepository.hasRemoteChanges: fetching remote catalog to diff against local cache');
    final remoteProducts = await _remote.fetchProducts();
    final remoteDepartments = await _remote.fetchDepartments();
    final localProducts = await _local.getProducts();
    final localDepartments = await _local.getDepartments();

    final remoteById = {for (final product in remoteProducts) product.id: product};
    final localById = {for (final product in localProducts) product.id: product};
    final changed = !mapEquals(remoteById, localById) || !listEquals(remoteDepartments, localDepartments);
    debugPrint('ProductRepository.hasRemoteChanges: changed=$changed');
    return changed;
  }

  /// Live read straight from Firestore, bypassing the local cache — used by
  /// the admin section, which must always act on current server data rather
  /// than whatever this device last synced.
  Future<CatalogSnapshot> fetchLiveCatalog() async {
    debugPrint('ProductRepository.fetchLiveCatalog: fetching live catalog from remote');
    final products = await _remote.fetchProducts();
    final departments = await _remote.fetchDepartments();
    debugPrint(
        'ProductRepository.fetchLiveCatalog: fetched ${products.length} products, ${departments.length} departments');
    return CatalogSnapshot(products: products, departments: departments);
  }

  Future<String> createProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
  }) {
    debugPrint('ProductRepository.createProduct: creating product name=$name');
    return _remote.addProduct(name: name, info: info, departments: departments, imageUrl: imageUrl);
  }

  Future<void> updateProduct(Product product) {
    debugPrint('ProductRepository.updateProduct: updating product id=${product.id}');
    return _remote.updateProduct(product);
  }

  Future<void> deleteProduct(String id) {
    debugPrint('ProductRepository.deleteProduct: deleting product id=$id');
    return _remote.deleteProduct(id);
  }

  Future<void> addDepartment(String name) async {
    debugPrint('ProductRepository.addDepartment: adding department name=$name');
    final existing = await _remote.fetchDepartments();
    if (existing.any((d) => d.toLowerCase() == name.toLowerCase())) {
      throw Exception('A department named "$name" already exists.');
    }
    await _remote.addDepartment(name);
  }

  Future<void> renameDepartment(String oldName, String newName) async {
    debugPrint('ProductRepository.renameDepartment: renaming department oldName=$oldName newName=$newName');
    final existing = await _remote.fetchDepartments();
    if (existing.any((d) => d.toLowerCase() != oldName.toLowerCase() && d.toLowerCase() == newName.toLowerCase())) {
      throw Exception('A department named "$newName" already exists.');
    }
    await _remote.renameDepartment(oldName, newName);
  }

  Future<void> deleteDepartment(String name) {
    debugPrint('ProductRepository.deleteDepartment: deleting department name=$name');
    return _remote.deleteDepartment(name);
  }

  static Future<void> _defaultPrecacheImages(List<String> imageUrls) async {
    debugPrint('ProductRepository._defaultPrecacheImages: precaching ${imageUrls.length} images');
    const concurrency = 6;
    for (var i = 0; i < imageUrls.length; i += concurrency) {
      final batch = imageUrls.skip(i).take(concurrency);
      await Future.wait(batch.map((url) async {
        try {
          await DefaultCacheManager().getSingleFile(url);
        } catch (error, stackTrace) {
          debugPrint('ProductRepository._defaultPrecacheImages: failed to precache image $url error=$error');
          AppLogger.error('ProductRepository', 'failed to precache image $url', error: error, stackTrace: stackTrace);
        }
      }));
    }
  }

  static const _syncTimeout = Duration(seconds: 30);
}
