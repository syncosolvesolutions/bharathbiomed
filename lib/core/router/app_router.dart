import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/designation.dart';
import '../../domain/models/doctor.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/product.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin/admin_notifications_screen.dart';
import '../../features/admin/department_products_screen.dart';
import '../../features/admin/designation_form_screen.dart';
import '../../features/admin/doctors/admin_doctors_screen.dart';
import '../../features/admin/doctors/doctor_requests_screen.dart';
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
import '../../features/doctors/doctor_detail_screen.dart';
import '../../features/doctors/doctor_form_screen.dart';
import '../../features/doctors/mr_doctors_screen.dart';
import '../../features/doctors/today_visits_screen.dart';
import '../../features/doctors/visit_plan_screen.dart';
import '../../features/legal/legal_content.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/profile/complete_profile_screen.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/slideshow/slideshow_screen.dart';
import '../auth/admin_access.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier();
  // Re-evaluate redirect whenever Firebase's auth state changes (e.g. on
  // launch with an existing session, or after sign-in/out).
  ref.listen(authStateChangesProvider, (previous, next) => refreshNotifier.ping());
  // Also re-evaluate once the signed-in MR's own profile loads/changes —
  // needed so `needsProfileCompletion` below reacts to profileCompleted
  // flipping true right after the mandatory profile screen saves, without
  // waiting for some unrelated auth event.
  ref.listen(myEmployeeProfileProvider, (previous, next) => refreshNotifier.ping());
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

      // Mandatory first-login profile completion (photo + name) for an MR
      // account. Scoped to non-admin accounts only, and only once their
      // `Users` doc has actually loaded — `employee == null` covers both
      // "still loading" and "not an MR", so it never blocks on an unknown
      // state. Accounts created before this field existed default to
      // `profileCompleted: true` (see Employee.profileCompleted), so nobody
      // already using the app gets retroactively blocked here.
      final employee = ref.read(myEmployeeProfileProvider).value;
      final needsProfileCompletion =
          isLoggedIn && !isAdminEmail(user.email) && employee != null && !employee.profileCompleted;
      const completeProfilePath = '/account/complete-profile';
      if (needsProfileCompletion && state.matchedLocation != completeProfilePath) return completeProfilePath;
      if (!needsProfileCompletion && state.matchedLocation == completeProfilePath) return '/catalog';

      // A few routes require data passed via `extra` (which product to show
      // full-screen, which employee/product/doctor to edit). `extra` doesn't
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
        case '/doctors/edit':
          if (state.extra is! Doctor) return '/doctors';
        case '/doctors/detail':
          if (state.extra is! Doctor) return '/doctors';
        case '/admin/doctors/edit':
          if (state.extra is! Doctor) return '/admin/doctors';
        case '/admin/designations/edit':
          if (state.extra is! Designation) return '/admin/designations';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/catalog', builder: (context, state) => const ProductListScreen()),
      GoRoute(path: '/account/change-password', builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: '/account/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/account/complete-profile', builder: (context, state) => const CompleteProfileScreen()),
      GoRoute(path: '/doctors', builder: (context, state) => const MrDoctorsScreen()),
      GoRoute(path: '/doctors/add', builder: (context, state) => const DoctorFormScreen()),
      GoRoute(
        path: '/doctors/edit',
        builder: (context, state) => DoctorFormScreen(doctor: state.extra as Doctor),
      ),
      GoRoute(
        path: '/doctors/detail',
        builder: (context, state) => DoctorDetailScreen(doctor: state.extra as Doctor),
      ),
      GoRoute(path: '/doctors/plan', builder: (context, state) => const VisitPlanScreen()),
      GoRoute(path: '/doctors/today', builder: (context, state) => const TodayVisitsScreen()),
      GoRoute(path: '/reminders', builder: (context, state) => const RemindersScreen()),
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
      GoRoute(path: '/admin/designations/add', builder: (context, state) => const DesignationFormScreen()),
      GoRoute(
        path: '/admin/designations/edit',
        builder: (context, state) => DesignationFormScreen(designation: state.extra as Designation),
      ),
      GoRoute(path: '/admin/employees', builder: (context, state) => const ManageEmployeesScreen()),
      GoRoute(path: '/admin/notifications', builder: (context, state) => const AdminNotificationsScreen()),
      GoRoute(path: '/admin/doctors', builder: (context, state) => const AdminDoctorsScreen()),
      GoRoute(path: '/admin/doctors/add', builder: (context, state) => const DoctorFormScreen()),
      GoRoute(
        path: '/admin/doctors/edit',
        builder: (context, state) => DoctorFormScreen(doctor: state.extra as Doctor),
      ),
      GoRoute(path: '/admin/doctors/requests', builder: (context, state) => const DoctorRequestsScreen()),
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
