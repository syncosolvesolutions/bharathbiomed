import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/tenant/tenant_config.dart';
import '../admin/admin_notifications_screen.dart';
import '../admin/doctors/admin_doctors_screen.dart';
import '../admin/doctors/doctor_requests_screen.dart';
import '../admin/expiry_alerts_screen.dart';
import '../admin/manage_departments_screen.dart';
import '../admin/manage_designations_screen.dart';
import '../admin/manage_employees_screen.dart';
import '../admin/manage_inventory_screen.dart';
import '../admin/usage_dashboard_screen.dart';
import '../agencies/agencies_screen.dart';
import '../attendance/attendance_dashboard_screen.dart';
import '../compliance/compliance_dashboard_screen.dart';
import '../entity_requests/entity_requests_screen.dart';
import '../expenses/expense_claim_approval_screen.dart';
import '../doctors/visit_plan_approval_screen.dart';
import '../leave/leave_request_approval_screen.dart';
import '../orders/invoices_screen.dart';
import '../orders/order_approval_screen.dart';
import '../pharmacies/pharmacies_screen.dart';
import '../targets/team_targets_screen.dart';
import '../team/rcpa_dashboard_screen.dart';

/// One entry in [AdminWebShell]'s sidebar: an icon/label, and the existing
/// screen widget to show for it. Every screen here is reused exactly as it
/// is on mobile — no parallel web-shaped rewrite of each one — see this
/// folder's SKILL.md for why that's a deliberate scope boundary, not an
/// oversight.
class _WebSection {
  const _WebSection(this.heading, this.items);
  final String heading;
  final List<_WebDestination> items;
}

class _WebDestination {
  const _WebDestination(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final List<_WebSection> _sections = [
  _WebSection('Catalog & People', [
    _WebDestination('Employees', Icons.people_outline, (_) => const ManageEmployeesScreen()),
    _WebDestination('Departments', Icons.apartment, (_) => const ManageDepartmentsScreen()),
    _WebDestination('Designations', Icons.badge_outlined, (_) => const ManageDesignationsScreen()),
    _WebDestination('Doctors', Icons.local_hospital_outlined, (_) => const AdminDoctorsScreen()),
    _WebDestination('Doctor Requests', Icons.fact_check_outlined, (_) => const DoctorRequestsScreen()),
    _WebDestination('Agencies', Icons.add_business_outlined, (_) => const AgenciesScreen()),
    _WebDestination('Pharmacies', Icons.local_pharmacy_outlined, (_) => const PharmaciesScreen()),
    _WebDestination('Agency/Pharmacy Requests', Icons.fact_check_outlined, (_) => const EntityRequestsScreen()),
  ]),
  _WebSection('Field Operations', [
    _WebDestination('Visit Plan Approvals', Icons.map_outlined, (_) => const VisitPlanApprovalScreen()),
    _WebDestination('RCPA Entries', Icons.fact_check_outlined, (_) => const RcpaDashboardScreen()),
    _WebDestination('Attendance', Icons.event_available_outlined, (_) => const AttendanceDashboardScreen()),
    _WebDestination('Compliance', Icons.gavel_outlined, (_) => const ComplianceDashboardScreen()),
    _WebDestination('Usage Dashboard', Icons.bar_chart, (_) => const UsageDashboardScreen()),
  ]),
  _WebSection('Financial', [
    _WebDestination('Inventory', Icons.inventory_2_outlined, (_) => const ManageInventoryScreen()),
    _WebDestination('Expiry Alerts', Icons.warning_amber_outlined, (_) => const ExpiryAlertsScreen()),
    _WebDestination('Orders', Icons.receipt_long_outlined, (_) => const OrderApprovalScreen()),
    _WebDestination('Invoices', Icons.request_quote_outlined, (_) => const InvoicesScreen()),
    _WebDestination('Targets', Icons.track_changes_outlined, (_) => const TeamTargetsScreen()),
  ]),
  _WebSection('Approvals', [
    _WebDestination('Expense Claims', Icons.request_page_outlined, (_) => const ExpenseClaimApprovalScreen()),
    _WebDestination('Leave Requests', Icons.event_busy_outlined, (_) => const LeaveRequestApprovalScreen()),
  ]),
  _WebSection('Other', [
    _WebDestination('Notifications', Icons.notifications_outlined, (_) => const AdminNotificationsScreen()),
  ]),
];

/// Wide-layout admin console for the web build — see this folder's
/// SKILL.md. Only ever reached via the `/admin` route (see
/// `core/router/app_router.dart`, which renders this instead of
/// `AdminHomeScreen` when `kIsWeb`), which is already gated to the
/// hardcoded admin allowlist by that route's own redirect logic — every
/// destination below is therefore safe to show unconditionally, since
/// whoever's looking at this is already a full admin (see
/// `hasPermissionProvider`/`hasGlobalVisibilityProvider`, both of which
/// already treat `isAdminProvider` as an automatic pass).
class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  _WebDestination _selected = _sections.first.items.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: Material(
              elevation: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: AppTheme.primary,
                    child: Text(
                      '${currentTenant.appName}\nAdmin Console',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final section in _sections) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              section.heading.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                          for (final destination in section.items)
                            ListTile(
                              leading: Icon(destination.icon),
                              title: Text(destination.label),
                              selected: identical(destination, _selected),
                              onTap: () => setState(() => _selected = destination),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _selected.builder(context)),
        ],
      ),
    );
  }
}
