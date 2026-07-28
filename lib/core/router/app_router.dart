import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/product.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin/admin_notifications_screen.dart';
import '../../features/admin/department_products_screen.dart';
import '../../features/admin/employee_form_screen.dart';
import '../../features/admin/employee_sessions_screen.dart';
import '../../features/admin/manage_departments_screen.dart';
import '../../features/admin/manage_designations_screen.dart';
import '../../features/admin/manage_employees_screen.dart';
import '../../features/admin/product_form_screen.dart';
import '../../features/admin/usage_dashboard_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/change_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalog/product_list_screen.dart';
import '../../features/legal/legal_content.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/slideshow/slideshow_screen.dart';
import '../auth/admin_access.dart';

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
      debugPrint('app_router.redirect: evaluating redirect for location=${state.matchedLocation}');
      final user = ref.read(authRepositoryProvider).currentUser;
      final isLoggedIn = user != null;
      final onLoginScreen = state.matchedLocation == '/login';
      if (isLoggedIn && onLoginScreen) return isAdminEmail(user.email) ? '/admin' : '/catalog';

      // Changing your password requires a signed-in user to reauthenticate
      // against; reaching this route while signed out (deep link, restored
      // back-stack) would otherwise surface a raw "no signed-in user" error.
      if (state.matchedLocation == '/account/change-password' && !isLoggedIn) return '/login';
      if (state.matchedLocation == '/account/profile' && !isLoggedIn) return '/login';

      // Admin routes are gated server-side too (Firestore rules, Cloud
      // Functions) — this redirect just keeps a non-admin (or a logged-out
      // user navigating here directly) from ever seeing the admin UI.
      final onAdminRoute = state.matchedLocation.startsWith('/admin');
      if (onAdminRoute && !isAdminEmail(user?.email)) return '/catalog';

      // A few routes require data passed via `extra` (which product to show
      // full-screen, which employee/product to edit). `extra` doesn't
      // survive process death — Android can kill the app and restore it to
      // its last route from the URL alone, with `extra` null. Redirect to a
      // safe parent screen instead of letting the builder's `as` cast crash.
      switch (state.matchedLocation) {
        case '/slideshow':
          if (state.extra is! List<Product>) return '/catalog';
        case '/admin/departments/products':
          if (state.extra is! String) return '/admin';
        case '/admin/employees/edit':
          if (state.extra is! Employee) return '/admin/employees';
        case '/admin/products/edit':
          if (state.extra is! Product) return '/admin';
        case '/admin/dashboard/sessions':
          if (state.extra is! Employee) return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/catalog', builder: (context, state) => const ProductListScreen()),
      GoRoute(path: '/account/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: '/account/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(title: 'Terms & Conditions', sections: termsAndConditionsSections),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const LegalDocumentScreen(title: 'Privacy Policy', sections: privacyPolicySections),
      ),
      GoRoute(
        path: '/slideshow',
        builder: (context, state) => SlideshowScreen(selectedProducts: state.extra as List<Product>),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: '/admin/departments', builder: (context, state) => const ManageDepartmentsScreen()),
      GoRoute(
        path: '/admin/departments/products',
        builder: (context, state) => DepartmentProductsScreen(department: state.extra as String),
      ),
      GoRoute(path: '/admin/designations', builder: (context, state) => const ManageDesignationsScreen()),
      GoRoute(path: '/admin/employees', builder: (context, state) => const ManageEmployeesScreen()),
      GoRoute(path: '/admin/notifications', builder: (context, state) => const AdminNotificationsScreen()),
      GoRoute(path: '/admin/employees/add', builder: (context, state) => const EmployeeFormScreen()),
      GoRoute(
        path: '/admin/employees/edit',
        builder: (context, state) => EmployeeFormScreen(employee: state.extra as Employee),
      ),
      GoRoute(path: '/admin/products/add', builder: (context, state) => const ProductFormScreen()),
      GoRoute(
        path: '/admin/products/edit',
        builder: (context, state) => ProductFormScreen(product: state.extra as Product),
      ),
      GoRoute(path: '/admin/dashboard', builder: (context, state) => const UsageDashboardScreen()),
      GoRoute(
        path: '/admin/dashboard/sessions',
        builder: (context, state) => EmployeeSessionsScreen(employee: state.extra as Employee),
      ),
    ],
  );
});

/// A [Listenable] go_router can watch, nudged manually via [ping] instead of
/// wrapping a raw stream (Riverpod's `.stream` accessor is deprecated).
class _GoRouterRefreshNotifier extends ChangeNotifier {
  void ping() {
    debugPrint('_GoRouterRefreshNotifier.ping: notifying router listeners');
    notifyListeners();
  }
}
