import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/employee.dart';
import '../admin/admin_access.dart';
import '../auth/auth_controller.dart';
import '../profile/birthday_celebration.dart';
import '../profile/profile_controller.dart';
import 'catalog_controller.dart';
import 'selection_controller.dart';
import 'widgets/category_section.dart';

/// Main catalog screen: products grouped by department, with multi-select
/// (feeding the slideshow) and a manual sync button to refresh from Firestore.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  bool _isSyncing = false;

  Future<void> _syncCatalog() async {
    debugPrint('ProductListScreen._syncCatalog: sync button pressed');
    setState(() => _isSyncing = true);

    String resultMessage;
    try {
      debugPrint('ProductListScreen._syncCatalog: calling catalogController.sync');
      await ref.read(catalogControllerProvider.notifier).sync();
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
    setState(() => _isSyncing = false);
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
        title: const Text('Bharath Biomed Pharma'),
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
            icon: _isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_sharp),
            tooltip: 'Sync catalog',
            onPressed: _isSyncing ? null : _syncCatalog,
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
            return ListView.builder(
              itemCount: snapshot.departments.length,
              itemBuilder: (context, index) {
                final department = snapshot.departments[index];
                final departmentProducts = snapshot.products
                    .where((product) => product.departments.containsKey(department))
                    .toList()
                  ..sort((a, b) => a.positionIn(department).compareTo(b.positionIn(department)));
                return CategorySection(category: department, products: departmentProducts);
              },
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
