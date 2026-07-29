import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/permission.dart';
import '../admin/admin_access.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';

/// Whether the signed-in user can see every employee's data rather than
/// just their own reporting-chain downline — the hardcoded admin allowlist,
/// or a real designation holding `view_global_data`. Mirrors
/// firestore.rules' `isAdmin() || hasGlobalVisibility()`.
final hasGlobalVisibilityProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  final me = ref.watch(myEmployeeProfileProvider).value;
  return me?.permissions.contains(Permission.viewGlobalData.value) ?? false;
});

/// "Office Admin" — the hardcoded admin allowlist, or a real designation
/// whose category is Office Administration (`Employee.category ==
/// 'office_administration'`). Gates agency/pharmacy create+deactivate and
/// entity-change-request review. Mirrors firestore.rules' `isOfficeAdmin()`
/// and the Cloud Function helper of the same name.
final isOfficeAdminProvider = Provider<bool>((ref) {
  if (ref.watch(isAdminProvider)) return true;
  final me = ref.watch(myEmployeeProfileProvider).value;
  return me?.category == 'office_administration';
});

/// Whether the signed-in user holds [permission] — the hardcoded admin
/// allowlist always does, otherwise checks the denormalized permission list
/// on their own `Employee` doc. Mirrors firestore.rules' `hasPermission`.
final hasPermissionProvider = Provider.family<bool, Permission>((ref, permission) {
  if (ref.watch(isAdminProvider)) return true;
  final me = ref.watch(myEmployeeProfileProvider).value;
  return me?.permissions.contains(permission.value) ?? false;
});

/// Agency/pharmacy update access: an Office Admin, or anyone holding
/// `manage_agencies` — not the same as who may create/deactivate one (Office
/// Admin only).
final canManageAgenciesProvider = Provider<bool>((ref) {
  return ref.watch(isOfficeAdminProvider) || ref.watch(hasPermissionProvider(Permission.manageAgencies));
});

/// Monthly-target creation access: global visibility, an Office Admin, or
/// anyone holding `manage_targets` (an RM/ZBM-tier designation the admin
/// assigned it to). Further restricted per-target to the target's employee
/// being in the caller's own reporting-chain downline — see
/// firestore.rules' `SalesTargets` rule.
final canManageTargetsProvider = Provider<bool>((ref) {
  return ref.watch(hasGlobalVisibilityProvider) ||
      ref.watch(isOfficeAdminProvider) ||
      ref.watch(hasPermissionProvider(Permission.manageTargets));
});

/// Employees the signed-in user is allowed to see team-wide data for: every
/// employee if they have global visibility, otherwise just their own
/// downline (via `Employee.reportingChainUids` — empty for anyone who isn't
/// actually a manager, so this is safe to call for any signed-in user, not
/// just designated managers). Used by any "my team" screen — usage/location,
/// visit logs — instead of each one re-deriving this itself.
Future<List<Employee>> resolveVisibleEmployees(Ref ref) async {
  if (ref.read(hasGlobalVisibilityProvider)) {
    return ref.read(employeeRepositoryProvider).fetchAll();
  }
  final myUid = ref.read(authControllerProvider).value?.uid;
  if (myUid == null) return const [];
  return ref.read(employeeRepositoryProvider).fetchDownline(myUid);
}

/// Provider form of [resolveVisibleEmployees], for screens (like
/// `SetTargetScreen`) that just need a one-shot employee picker rather than
/// a full controller.
final visibleEmployeesProvider = FutureProvider<List<Employee>>((ref) => resolveVisibleEmployees(ref));
