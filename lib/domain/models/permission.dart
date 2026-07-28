/// Actions a designation can be granted, independent of tree position.
/// `viewGlobalData` is the one permission that also changes *visibility*
/// (see `HierarchyService`), not just what actions are allowed — everything
/// else only gates a specific mutation. `markDelivered` is deliberately not
/// here: it's ownership-scoped (assigned field agent only), not a checkbox.
enum Permission { createOrders, approveOrders, dispatchOrders, manageInvoices, approveRequests, viewGlobalData }

extension PermissionValue on Permission {
  String get value => switch (this) {
        Permission.createOrders => 'create_orders',
        Permission.approveOrders => 'approve_orders',
        Permission.dispatchOrders => 'dispatch_orders',
        Permission.manageInvoices => 'manage_invoices',
        Permission.approveRequests => 'approve_requests',
        Permission.viewGlobalData => 'view_global_data',
      };

  String get label => switch (this) {
        Permission.createOrders => 'Create Orders',
        Permission.approveOrders => 'Approve Orders',
        Permission.dispatchOrders => 'Dispatch Orders',
        Permission.manageInvoices => 'Manage Invoices',
        Permission.approveRequests => 'Approve Requests',
        Permission.viewGlobalData => 'View Global Data (all users/regions)',
      };
}

Permission? permissionFromString(String value) {
  for (final permission in Permission.values) {
    if (permission.value == value) return permission;
  }
  return null;
}
