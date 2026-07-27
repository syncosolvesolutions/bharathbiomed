import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import 'admin_catalog_controller.dart';

/// Entry point for the admin section: departments (tap to manage that
/// department's products) plus links to department/designation/employee
/// management and adding a new product.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(adminCatalogControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
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
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Usage Dashboard',
            onPressed: () => context.push('/admin/dashboard'),
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
                onPressed: () => ref.read(adminCatalogControllerProvider.notifier).refresh(),
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
            onRefresh: () => ref.read(adminCatalogControllerProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: snapshot.departments.length,
              itemBuilder: (context, index) {
                final department = snapshot.departments[index];
                final count = snapshot.products.where((p) => p.departments.containsKey(department)).length;
                return ListTile(
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
