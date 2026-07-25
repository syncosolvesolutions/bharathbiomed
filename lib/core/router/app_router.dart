import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/product.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalog/product_list_screen.dart';
import '../../features/slideshow/slideshow_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier();
  // Re-evaluate redirect whenever Firebase's auth state changes (e.g. on
  // launch with an existing session, or after sign-in/out).
  ref.listen(authStateChangesProvider, (previous, next) => refreshNotifier.ping());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final onLoginScreen = state.matchedLocation == '/login';
      if (isLoggedIn && onLoginScreen) return '/catalog';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/catalog', builder: (context, state) => const ProductListScreen()),
      GoRoute(
        path: '/slideshow',
        builder: (context, state) => SlideshowScreen(selectedProducts: state.extra as List<Product>),
      ),
    ],
  );
});

/// A [Listenable] go_router can watch, nudged manually via [ping] instead of
/// wrapping a raw stream (Riverpod's `.stream` accessor is deprecated).
class _GoRouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
