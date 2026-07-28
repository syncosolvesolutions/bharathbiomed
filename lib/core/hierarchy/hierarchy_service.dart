import '../../domain/models/employee.dart';
import '../../domain/models/permission.dart';

/// Pure, synchronous visibility/authorization checks over already-loaded
/// employee/resource data — no I/O. Both methods share the same shape: a
/// permission gate, then either a `view_global_data` short-circuit or a
/// membership check against a server-computed `reportingChainUids` list (see
/// `functions/src/hierarchy.ts` for how that list is maintained).
class HierarchyService {
  const HierarchyService._();

  /// Whether [approver] can act on a request/resource created by
  /// [creator] — holds [permission], and is either globally visible or
  /// somewhere in [creator]'s reporting chain (i.e. one of their managers).
  static bool canUserApprove({
    required Employee approver,
    required Employee creator,
    required Permission permission,
  }) {
    if (!approver.permissions.contains(permission.value)) return false;
    if (approver.permissions.contains(Permission.viewGlobalData.value)) return true;
    return creator.reportingChainUids.contains(approver.uid);
  }

  /// Whether [viewer] can see a resource: they created it themselves, they
  /// have global visibility, or they're in the resource creator's reporting
  /// chain (a manager somewhere above the creator).
  static bool canViewResource({
    required Employee viewer,
    required String resourceCreatedByUid,
    required List<String> resourceReportingChainUids,
  }) {
    if (viewer.uid == resourceCreatedByUid) return true;
    if (viewer.permissions.contains(Permission.viewGlobalData.value)) return true;
    return resourceReportingChainUids.contains(viewer.uid);
  }
}
