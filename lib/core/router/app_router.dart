import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/agency.dart';
import '../../domain/models/designation.dart';
import '../../domain/models/doctor.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/pharmacy.dart';
import '../../domain/models/product.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin_web/admin_web_shell.dart';
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
import '../../features/admin/expiry_alerts_screen.dart';
import '../../features/admin/manage_inventory_screen.dart';
import '../../features/admin/product_batches_screen.dart';
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
import '../../features/doctors/visit_plan_approval_screen.dart';
import '../../features/doctors/visit_plan_screen.dart';
import '../../features/entity_requests/entity_requests_screen.dart';
import '../../features/expenses/expense_claim_approval_screen.dart';
import '../../features/expenses/expense_claim_form_screen.dart';
import '../../features/expenses/my_expense_claims_screen.dart';
import '../../features/leave/leave_request_approval_screen.dart';
import '../../features/leave/leave_request_form_screen.dart';
import '../../features/leave/my_leave_requests_screen.dart';
import '../../features/legal/legal_content.dart';
import '../../features/legal/legal_document_screen.dart';
import '../../features/agencies/agencies_screen.dart';
import '../../features/agencies/agency_form_screen.dart';
import '../../features/attendance/attendance_dashboard_screen.dart';
import '../../features/attendance/employee_attendance_screen.dart';
import '../../features/attendance/my_attendance_screen.dart';
import '../../features/compliance/compliance_dashboard_screen.dart';
import '../../features/compliance/compliance_log_form_screen.dart';
import '../../features/compliance/my_compliance_logs_screen.dart';
import '../../features/orders/invoices_screen.dart';
import '../../features/orders/my_orders_screen.dart';
import '../../features/orders/order_approval_screen.dart';
import '../../features/orders/order_form_screen.dart';
import '../../features/pharmacies/pharmacies_screen.dart';
import '../../features/pharmacies/pharmacy_form_screen.dart';
import '../../features/profile/complete_profile_screen.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/rcpa/rcpa_form_screen.dart';
import '../../features/rcpa/rcpa_list_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/slideshow/slideshow_screen.dart';
import '../../features/targets/my_target_screen.dart';
import '../../features/targets/set_target_screen.dart';
import '../../features/targets/team_targets_screen.dart';
import '../../features/team/employee_rcpa_entries_screen.dart';
import '../../features/team/employee_visit_logs_screen.dart';
import '../../features/team/rcpa_dashboard_screen.dart';
import '../../features/team/team_home_screen.dart';
import '../../features/team/visit_log_dashboard_screen.dart';
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
        case '/team/usage/sessions':
          if (state.extra is! Employee) return '/team/usage';
        case '/team/visit-logs/detail':
          if (state.extra is! Employee) return '/team/visit-logs';
        case '/doctors/edit':
          if (state.extra is! Doctor) return '/doctors';
        case '/doctors/detail':
          if (state.extra is! Doctor) return '/doctors';
        case '/admin/doctors/edit':
          if (state.extra is! Doctor) return '/admin/doctors';
        case '/admin/designations/edit':
          if (state.extra is! Designation) return '/admin/designations';
        case '/agencies/edit':
          if (state.extra is! Agency) return '/agencies';
        case '/pharmacies/edit':
          if (state.extra is! Pharmacy) return '/pharmacies';
        case '/team/rcpa/detail':
          if (state.extra is! Employee) return '/team/rcpa';
        case '/admin/inventory/batches':
          if (state.extra is! Product) return '/admin/inventory';
        case '/team/attendance/detail':
          if (state.extra is! Employee) return '/team/attendance';
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
            LegalDocumentScreen(title: 'Terms & Conditions', sections: termsAndConditionsSections()),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => LegalDocumentScreen(title: 'Privacy Policy', sections: privacyPolicySections()),
      ),
      GoRoute(
        path: '/slideshow',
        builder: (context, state) => SlideshowScreen(selectedProducts: state.extra as List<Product>),
      ),
      // Web gets the wide-layout console (see features/admin_web/SKILL.md)
      // instead of the mobile admin home screen; every route it reaches
      // internally (state selection, not go_router navigation) is unchanged.
      GoRoute(path: '/admin', builder: (context, state) => kIsWeb ? const AdminWebShell() : const AdminHomeScreen()),
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
      GoRoute(path: '/admin/inventory', builder: (context, state) => const ManageInventoryScreen()),
      GoRoute(
        path: '/admin/inventory/batches',
        builder: (context, state) => ProductBatchesScreen(product: state.extra as Product),
      ),
      GoRoute(path: '/admin/inventory/expiry-alerts', builder: (context, state) => const ExpiryAlertsScreen()),
      GoRoute(path: '/admin/dashboard', builder: (context, state) => const UsageDashboardScreen()),
      GoRoute(
        path: '/admin/dashboard/sessions',
        builder: (context, state) => EmployeeSessionsScreen(employee: state.extra as Employee),
      ),
      // Not under /admin — reachable by any signed-in employee. Scoped
      // internally to the caller's own reporting-chain downline (or, for a
      // view_global_data holder including the admin, everyone) — see
      // resolveVisibleEmployees in features/team/team_access.dart.
      GoRoute(path: '/team', builder: (context, state) => const TeamHomeScreen()),
      GoRoute(path: '/team/usage', builder: (context, state) => const UsageDashboardScreen()),
      GoRoute(
        path: '/team/usage/sessions',
        builder: (context, state) => EmployeeSessionsScreen(employee: state.extra as Employee),
      ),
      GoRoute(path: '/team/visit-logs', builder: (context, state) => const VisitLogDashboardScreen()),
      GoRoute(
        path: '/team/visit-logs/detail',
        builder: (context, state) => EmployeeVisitLogsScreen(employee: state.extra as Employee),
      ),
      // Agencies/pharmacies: readable by any signed-in user (not admin-
      // gated) — create is Office-Admin-only, update is
      // canManageAgenciesProvider-gated, both enforced in-screen and by
      // firestore.rules, not by route gating.
      GoRoute(path: '/agencies', builder: (context, state) => const AgenciesScreen()),
      GoRoute(path: '/agencies/add', builder: (context, state) => const AgencyFormScreen()),
      GoRoute(
        path: '/agencies/edit',
        builder: (context, state) => AgencyFormScreen(agency: state.extra as Agency),
      ),
      GoRoute(path: '/pharmacies', builder: (context, state) => const PharmaciesScreen()),
      GoRoute(path: '/pharmacies/add', builder: (context, state) => const PharmacyFormScreen()),
      GoRoute(
        path: '/pharmacies/edit',
        builder: (context, state) => PharmacyFormScreen(pharmacy: state.extra as Pharmacy),
      ),
      GoRoute(path: '/entity-requests', builder: (context, state) => const EntityRequestsScreen()),
      // Orders: an MR's own place-order flow, plus the team workflow queue
      // (approve/reject/dispatch/invoice) — not admin-gated, same reasoning
      // as /team/* (scoped in-screen by permission + reporting chain).
      GoRoute(path: '/orders', builder: (context, state) => const MyOrdersScreen()),
      GoRoute(path: '/orders/add', builder: (context, state) => const OrderFormScreen()),
      GoRoute(path: '/team/orders', builder: (context, state) => const OrderApprovalScreen()),
      GoRoute(path: '/invoices', builder: (context, state) => const InvoicesScreen()),
      // Targets: an MR's own current-month target vs. achievement, plus the
      // team view + set-target action for an RM-or-above (not admin-gated,
      // same reasoning as /team/*).
      GoRoute(path: '/targets', builder: (context, state) => const MyTargetScreen()),
      GoRoute(
        path: '/targets/set',
        builder: (context, state) => SetTargetScreen(initialEmployee: state.extra as Employee?),
      ),
      GoRoute(path: '/team/targets', builder: (context, state) => const TeamTargetsScreen()),
      // RCPA: an MR's own logged entries + form, plus the team dashboard
      // (not admin-gated, same reasoning as /team/*).
      GoRoute(path: '/rcpa', builder: (context, state) => const RcpaListScreen()),
      GoRoute(path: '/rcpa/add', builder: (context, state) => const RcpaFormScreen()),
      GoRoute(path: '/team/rcpa', builder: (context, state) => const RcpaDashboardScreen()),
      GoRoute(
        path: '/team/rcpa/detail',
        builder: (context, state) => EmployeeRcpaEntriesScreen(employee: state.extra as Employee),
      ),
      // Expense claims: an MR's own filed claims + form, plus the team
      // approval queue (not admin-gated, same reasoning as /team/*).
      GoRoute(path: '/expenses', builder: (context, state) => const MyExpenseClaimsScreen()),
      GoRoute(path: '/expenses/add', builder: (context, state) => const ExpenseClaimFormScreen()),
      GoRoute(path: '/team/expenses', builder: (context, state) => const ExpenseClaimApprovalScreen()),
      // Visit plan (beat/route plan) approvals — the plan itself is edited
      // at /doctors/plan; this is just the team review queue.
      GoRoute(path: '/team/visit-plans', builder: (context, state) => const VisitPlanApprovalScreen()),
      // Leave requests: an MR's own filed requests + form, plus the team
      // approval queue (not admin-gated, same reasoning as /team/*).
      GoRoute(path: '/leave', builder: (context, state) => const MyLeaveRequestsScreen()),
      GoRoute(path: '/leave/add', builder: (context, state) => const LeaveRequestFormScreen()),
      GoRoute(path: '/team/leave', builder: (context, state) => const LeaveRequestApprovalScreen()),
      // Attendance: an MR's own derived attendance, plus the team dashboard
      // (not admin-gated, same reasoning as /team/*).
      GoRoute(path: '/attendance', builder: (context, state) => const MyAttendanceScreen()),
      GoRoute(path: '/team/attendance', builder: (context, state) => const AttendanceDashboardScreen()),
      GoRoute(
        path: '/team/attendance/detail',
        builder: (context, state) => EmployeeAttendanceScreen(employee: state.extra as Employee),
      ),
      // Compliance (UCPMP): an MR's own logged entries + form, plus the
      // team per-doctor dashboard (not admin-gated, same reasoning as
      // /team/*).
      GoRoute(path: '/compliance', builder: (context, state) => const MyComplianceLogsScreen()),
      GoRoute(path: '/compliance/add', builder: (context, state) => const ComplianceLogFormScreen()),
      GoRoute(path: '/team/compliance', builder: (context, state) => const ComplianceDashboardScreen()),
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
