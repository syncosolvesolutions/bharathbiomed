/// Actions a designation can be granted, independent of tree position.
/// `viewGlobalData` is the one permission that also changes *visibility*
/// (see `HierarchyService`), not just what actions are allowed — everything
/// else only gates a specific mutation. `markDelivered` is deliberately not
/// here: it's ownership-scoped (assigned field agent only), not a checkbox.
enum Permission {
  createOrders,
  approveOrders,
  dispatchOrders,
  manageInvoices,

  /// Gates approving/rejecting a submitted weekly visit (beat/route) plan
  /// — see `firestore.rules`' `DoctorVisitPlans` rule and
  /// `VisitPlanApprovalController`. Despite the generic name, this is
  /// currently only checked for that one workflow, not `DoctorChangeRequests`
  /// /`EntityChangeRequests` (those stay gated to `isOfficeAdmin()`).
  approveRequests,
  viewGlobalData,
  manageAgencies,
  manageTargets,
  approveExpenses,
  approveLeave,
}

extension PermissionValue on Permission {
  String get value => switch (this) {
        Permission.createOrders => 'create_orders',
        Permission.approveOrders => 'approve_orders',
        Permission.dispatchOrders => 'dispatch_orders',
        Permission.manageInvoices => 'manage_invoices',
        Permission.approveRequests => 'approve_requests',
        Permission.viewGlobalData => 'view_global_data',
        Permission.manageAgencies => 'manage_agencies',
        Permission.manageTargets => 'manage_targets',
        Permission.approveExpenses => 'approve_expenses',
        Permission.approveLeave => 'approve_leave',
      };

  String get label => switch (this) {
        Permission.createOrders => 'Create Orders',
        Permission.approveOrders => 'Approve Orders',
        Permission.dispatchOrders => 'Dispatch Orders',
        Permission.manageInvoices => 'Manage Invoices',
        Permission.approveRequests => 'Approve Requests',
        Permission.viewGlobalData => 'View Global Data (all users/regions)',
        Permission.manageAgencies => 'Manage Agencies & Pharmacies (update, not create)',
        Permission.manageTargets => 'Set Monthly Targets (for reporting-chain downline)',
        Permission.approveExpenses => 'Approve Expense Claims (for reporting-chain downline)',
        Permission.approveLeave => 'Approve Leave Requests (for reporting-chain downline)',
      };
}

Permission? permissionFromString(String value) {
  for (final permission in Permission.values) {
    if (permission.value == value) return permission;
  }
  return null;
}
