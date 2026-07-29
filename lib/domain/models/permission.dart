/// Actions a designation can be granted, independent of tree position.
/// `viewGlobalData` is the one permission that also changes *visibility*
/// (see `HierarchyService`), not just what actions are allowed — everything
/// else only gates a specific mutation. `markDelivered` is deliberately not
/// here: it's ownership-scoped (assigned field agent only), not a checkbox.
enum Permission {
  createOrders,
  approveOrders,
  dispatchOrders,

  /// Gates approving/rejecting a submitted weekly visit (beat/route) plan
  /// (`DoctorVisitPlans` rule/`VisitPlanApprovalController`), and — as of
  /// the "RM and above can approve all requests" change — also reviewing
  /// `DoctorChangeRequests`/`EntityChangeRequests` as a second, independent
  /// path alongside the hardcoded admin allowlist / `isOfficeAdmin()`
  /// respectively. Deliberately category-agnostic: a field designation
  /// (e.g. Area Business Manager and above) holding this checkbox qualifies
  /// exactly the same way an Office Administration designation does.
  approveRequests,
  viewGlobalData,
  manageAgencies,
  manageTargets,
  approveExpenses,
}

extension PermissionValue on Permission {
  String get value => switch (this) {
        Permission.createOrders => 'create_orders',
        Permission.approveOrders => 'approve_orders',
        Permission.dispatchOrders => 'dispatch_orders',
        Permission.approveRequests => 'approve_requests',
        Permission.viewGlobalData => 'view_global_data',
        Permission.manageAgencies => 'manage_agencies',
        Permission.manageTargets => 'manage_targets',
        Permission.approveExpenses => 'approve_expenses',
      };

  String get label => switch (this) {
        Permission.createOrders => 'Create Orders',
        Permission.approveOrders => 'Approve Orders',
        Permission.dispatchOrders => 'Dispatch Orders',
        Permission.approveRequests => 'Approve Requests (Doctor/Agency/Pharmacy proposals, visit plans)',
        Permission.viewGlobalData => 'View Global Data (all users/regions)',
        Permission.manageAgencies => 'Manage Agencies & Pharmacies (update, not create)',
        Permission.manageTargets => 'Set Monthly Targets (for reporting-chain downline)',
        Permission.approveExpenses => 'Approve Expense Claims (for reporting-chain downline)',
      };
}

Permission? permissionFromString(String value) {
  for (final permission in Permission.values) {
    if (permission.value == value) return permission;
  }
  return null;
}
