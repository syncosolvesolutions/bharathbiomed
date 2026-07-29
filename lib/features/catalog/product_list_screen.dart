import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/tenant/tenant_config.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/employee.dart';
import '../admin/admin_access.dart';
import '../auth/auth_controller.dart';
import '../profile/birthday_celebration.dart';
import '../profile/profile_controller.dart';
import '../sync/sync_controller.dart';
import '../team/team_access.dart';
import 'catalog_controller.dart';
import 'selection_controller.dart';
import 'widgets/category_section.dart';

/// Main catalog screen: products grouped by department, with multi-select
/// (feeding the slideshow) and a manual sync button to refresh from Firestore.
/// The app-wide progress overlay (see app.dart/SyncController) covers the
/// screen while this runs, so this button just needs to stay disabled and
/// report the end result.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncCatalog() async {
    debugPrint('ProductListScreen._syncCatalog: sync button pressed');

    String resultMessage;
    try {
      debugPrint('ProductListScreen._syncCatalog: calling syncController.startSync');
      await ref.read(syncControllerProvider.notifier).startSync();
      debugPrint('ProductListScreen._syncCatalog: sync succeeded');
      resultMessage = 'Data synced successfully.';
    } catch (error, stackTrace) {
      debugPrint('ProductListScreen._syncCatalog: sync failed error=$error');
      AppLogger.error('ProductList', 'catalog sync failed', error: error, stackTrace: stackTrace);
      // Deliberately don't rethrow: catalogControllerProvider keeps showing
      // whatever was last synced, so the user isn't left with a blank screen.
      resultMessage = 'Sync failed: ${UserFacingError.describe(error)}';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage)));
  }

  Future<void> _logout() async {
    debugPrint('ProductListScreen._logout: logout requested');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can keep browsing the catalog offline after logging out — sync just needs signing in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    debugPrint('ProductListScreen._logout: calling authController.signOut');
    await ref.read(authControllerProvider.notifier).signOut();
    debugPrint('ProductListScreen._logout: signOut succeeded');
    if (!mounted) return;
    context.go('/login');
  }

  void _openSlideshowForSelection() {
    debugPrint('ProductListScreen._openSlideshowForSelection: play button pressed');
    final selectedProducts = ref.read(selectionControllerProvider);
    if (selectedProducts.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No Products Selected',
        text: 'Please select products to play the slideshow.',
      );
      return;
    }
    context.push('/slideshow', extra: selectedProducts);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isSignedIn = ref.watch(authControllerProvider).value != null;
    final isSyncing = ref.watch(syncControllerProvider).isSyncing;
    final Employee? myProfile = isAdmin ? null : ref.watch(myEmployeeProfileProvider).value;

    // Idempotent: maybeShowBirthdayCelebration only actually shows once per
    // uid/year (tracked in shared_preferences), so it's safe to re-run every
    // time this stream emits a new snapshot.
    ref.listen<AsyncValue<Employee?>>(myEmployeeProfileProvider, (previous, next) {
      final employee = next.value;
      if (employee != null) maybeShowBirthdayCelebration(context, employee);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTenant.appName),
        actions: [
          if (myProfile?.isBirthdayToday ?? false)
            IconButton(
              icon: const Text('🎂', style: TextStyle(fontSize: 20)),
              tooltip: 'Happy Birthday!',
              onPressed: () => showBirthdayCelebration(context, myProfile!),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin',
              onPressed: () => context.push('/admin'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: "Today's Visits",
              onPressed: () => context.push('/doctors/today'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.local_hospital_outlined),
              tooltip: 'My Doctors',
              onPressed: () => context.push('/doctors'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: 'Weekly Visit Plan',
              onPressed: () => context.push('/doctors/plan'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.add_alert_outlined),
              tooltip: 'Reminders',
              onPressed: () => context.push('/reminders'),
            ),
          if (isSignedIn)
            IconButton(
              icon: const Icon(Icons.add_business_outlined),
              tooltip: 'Agencies',
              onPressed: () => context.push('/agencies'),
            ),
          if (isSignedIn)
            IconButton(
              icon: const Icon(Icons.local_pharmacy_outlined),
              tooltip: 'Pharmacies',
              onPressed: () => context.push('/pharmacies'),
            ),
          if (isSignedIn && ref.watch(isOfficeAdminProvider))
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Agency / Pharmacy Requests',
              onPressed: () => context.push('/entity-requests'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              tooltip: 'My Orders',
              onPressed: () => context.push('/orders'),
            ),
          if (isSignedIn && ref.watch(canViewInvoicesProvider))
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Invoices',
              onPressed: () => context.push('/invoices'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.track_changes_outlined),
              tooltip: 'My Target',
              onPressed: () => context.push('/targets'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'RCPA Entries',
              onPressed: () => context.push('/rcpa'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.request_page_outlined),
              tooltip: 'My Expense Claims',
              onPressed: () => context.push('/expenses'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.event_busy_outlined),
              tooltip: 'My Leave Requests',
              onPressed: () => context.push('/leave'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.event_available_outlined),
              tooltip: 'My Attendance',
              onPressed: () => context.push('/attendance'),
            ),
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.gavel_outlined),
              tooltip: 'Compliance Log',
              onPressed: () => context.push('/compliance'),
            ),
          // Shown to every non-admin signed-in employee, not just designated
          // managers — there's no cheap client-side way to know in advance
          // whether someone has reports, and the screens behind this just
          // show an empty state if they don't (see resolveVisibleEmployees).
          if (isSignedIn && !isAdmin)
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'My Team',
              onPressed: () => context.push('/team'),
            ),
          if (isSignedIn)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push('/account/profile'),
            ),
          if (isSignedIn)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Change Password',
              onPressed: () => context.push('/account/change-password'),
            ),
          if (isSignedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: _logout,
            ),
          IconButton(
            icon: isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_sharp),
            tooltip: 'Sync catalog',
            onPressed: isSyncing ? null : _syncCatalog,
            color: AppTheme.success,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load catalog: ${UserFacingError.describe(error)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    debugPrint('ProductListScreen: Retry button pressed, invalidating catalogControllerProvider');
                    ref.invalidate(catalogControllerProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (snapshot) {
            if (snapshot.departments.isEmpty) {
              return const Center(
                child: Text(
                  'No data synced yet.\nSign in and sync, or tap the sync button above, to download the catalog.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final query = _searchController.text.trim().toLowerCase();
            final departmentsWithProducts = snapshot.departments.map((department) {
              final departmentProducts = snapshot.products
                  .where((product) => product.departments.containsKey(department))
                  .where((product) =>
                      query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      product.info.toLowerCase().contains(query))
                  .toList()
                ..sort((a, b) => a.positionIn(department).compareTo(b.positionIn(department)));
              return (department: department, products: departmentProducts);
            }).where((entry) => entry.products.isNotEmpty).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: departmentsWithProducts.isEmpty
                      ? const Center(child: Text('No products match this search.'))
                      : ListView.builder(
                          itemCount: departmentsWithProducts.length,
                          itemBuilder: (context, index) {
                            final entry = departmentsWithProducts[index];
                            return CategorySection(category: entry.department, products: entry.products);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSlideshowForSelection,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
