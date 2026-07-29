import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../auth/auth_controller.dart';
import 'admin_catalog_controller.dart';
import 'admin_notifications_controller.dart';
import 'employee_controller.dart';

/// Entry point for the admin section: departments (tap to manage that
/// department's products) plus links to department/designation/employee
/// management and adding a new product.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    debugPrint('AdminHomeScreen._logout: logout requested');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to reach the admin panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    debugPrint('AdminHomeScreen._logout: signing out');
    await ref.read(authControllerProvider.notifier).signOut();
    debugPrint('AdminHomeScreen._logout: signed out');
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(adminCatalogControllerProvider);
    final employees = ref.watch(employeeControllerProvider);
    final unreadNotifications = ref.watch(unreadAdminNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadNotifications'),
              isLabelVisible: unreadNotifications > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () => context.push('/admin/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/account/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'View Catalog (MR view)',
            onPressed: () => context.push('/catalog'),
          ),
          IconButton(
            icon: const Icon(Icons.apartment),
            tooltip: 'Manage Departments',
            onPressed: () => context.push('/admin/departments'),
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Manage Designations',
            onPressed: () => context.push('/admin/designations'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Employees',
            onPressed: () => context.push('/admin/employees'),
          ),
          IconButton(
            icon: const Icon(Icons.local_hospital_outlined),
            tooltip: 'Manage Doctors',
            onPressed: () => context.push('/admin/doctors'),
          ),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: 'Reminders',
            onPressed: () => context.push('/reminders'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Usage Dashboard',
            onPressed: () => context.push('/admin/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Visit Logs',
            onPressed: () => context.push('/team/visit-logs'),
          ),
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Agencies',
            onPressed: () => context.push('/agencies'),
          ),
          IconButton(
            icon: const Icon(Icons.local_pharmacy_outlined),
            tooltip: 'Pharmacies',
            onPressed: () => context.push('/pharmacies'),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Agency / Pharmacy Requests',
            onPressed: () => context.push('/entity-requests'),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Order Workflow',
            onPressed: () => context.push('/team/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.track_changes_outlined),
            tooltip: 'Team Targets',
            onPressed: () => context.push('/team/targets'),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'RCPA Entries',
            onPressed: () => context.push('/team/rcpa'),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Manage Inventory',
            onPressed: () => context.push('/admin/inventory'),
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_outlined),
            tooltip: 'Expiry Alerts',
            onPressed: () => context.push('/admin/inventory/expiry-alerts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load catalog: ${UserFacingError.describe(error)}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  debugPrint('AdminHomeScreen: retry button tapped');
                  ref.read(adminCatalogControllerProvider.notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (snapshot) {
          if (snapshot.departments.isEmpty) {
            return const Center(
              child: Text('No departments yet.\nTap the apartment icon above to add one.', textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () {
              debugPrint('AdminHomeScreen: pull-to-refresh triggered');
              return ref.read(adminCatalogControllerProvider.notifier).refresh();
            },
            child: ListView.builder(
              itemCount: snapshot.departments.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.apartment,
                            color: const Color(0xFF3470B2),
                            label: 'Departments',
                            value: snapshot.departments.length.toString(),
                            onTap: () => context.push('/admin/departments'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFF2E7D32),
                            label: 'Products',
                            value: snapshot.products.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people_outline,
                            color: const Color(0xFFEF6C00),
                            label: 'Users',
                            value: employees.maybeWhen(
                              data: (list) => list.length.toString(),
                              orElse: () => '–',
                            ),
                            onTap: () => context.push('/admin/employees'),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final department = snapshot.departments[index - 1];
                final count = snapshot.products.where((p) => p.departments.containsKey(department)).length;
                final color = AccentPalette.forLabel(department);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    foregroundColor: color,
                    child: Text(department.isNotEmpty ? department[0].toUpperCase() : '?'),
                  ),
                  title: Text(department),
                  subtitle: Text('$count product${count == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/admin/departments/products', extra: department),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/products/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.color, required this.label, required this.value, this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
