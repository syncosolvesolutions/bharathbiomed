import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/auth_repository.dart';
import 'repositories/product_repository.dart';

/// Dependency-injection root for the data layer. Features read repositories
/// through these providers rather than constructing them directly, so tests
/// can override them with fakes/mocks.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());
