import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../data/providers.dart';
import '../../domain/models/pharmacy.dart';
import '../team/team_access.dart';
import 'pharmacy_controller.dart';

/// Every pharmacy, visible to any signed-in user — mirrors [AgenciesScreen]
/// exactly.
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  final _searchController = TextEditingController();
  bool _syncing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    String message;
    try {
      await ref.read(pharmacyControllerProvider.notifier).sync();
      message = 'Synced successfully.';
    } catch (error, stackTrace) {
      AppLogger.error('PharmaciesScreen', 'sync failed', error: error, stackTrace: stackTrace);
      message = 'Sync failed: ${UserFacingError.describe(error)}';
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setActive(Pharmacy pharmacy, {required bool active}) async {
    try {
      await ref.read(pharmacyRepositoryProvider).setActive(pharmacy.id, active: active);
      await ref.read(pharmacyControllerProvider.notifier).sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(active ? 'Pharmacy reactivated.' : 'Pharmacy deactivated.')));
    } catch (error, stackTrace) {
      AppLogger.error('PharmaciesScreen', 'setActive failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  List<Pharmacy> _applyFilter(List<Pharmacy> pharmacies) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return pharmacies;
    return pharmacies.where((pharmacy) => pharmacy.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pharmaciesAsync = ref.watch(pharmacyControllerProvider);
    final canManage = ref.watch(canManageAgenciesProvider);
    final isOfficeAdmin = ref.watch(isOfficeAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacies'),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'Sync',
            onPressed: _syncing ? null : _sync,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Pharmacy name',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: pharmaciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load pharmacies: ${UserFacingError.describe(error)}')),
              data: (pharmacies) {
                if (pharmacies.isEmpty) {
                  return const Center(
                    child:
                        Text('No pharmacies yet.\nTap "Add Pharmacy" below to propose one.', textAlign: TextAlign.center),
                  );
                }
                final filtered = _applyFilter(pharmacies);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No pharmacies match this search.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final pharmacy = filtered[index];
                    return ListTile(
                      onTap: canManage ? () => context.push('/pharmacies/edit', extra: pharmacy) : null,
                      leading: CircleAvatar(
                        backgroundColor: AccentPalette.forLabel(pharmacy.name).withValues(alpha: 0.15),
                        foregroundColor: AccentPalette.forLabel(pharmacy.name),
                        child: Text(pharmacy.name.isNotEmpty ? pharmacy.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(pharmacy.name, style: TextStyle(color: pharmacy.active ? null : Colors.grey)),
                      subtitle: Text(
                        '${pharmacy.linkedDoctorIds.length} linked doctor${pharmacy.linkedDoctorIds.length == 1 ? '' : 's'}'
                        '${pharmacy.active ? '' : ' • Inactive'}',
                      ),
                      trailing: isOfficeAdmin
                          ? IconButton(
                              icon: Icon(pharmacy.active ? Icons.block : Icons.check_circle_outline),
                              tooltip: pharmacy.active ? 'Deactivate' : 'Reactivate',
                              onPressed: () => _setActive(pharmacy, active: !pharmacy.active),
                            )
                          : (canManage ? const Icon(Icons.arrow_forward_ios, size: 16) : null),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pharmacies/add'),
        icon: const Icon(Icons.local_pharmacy_outlined),
        label: Text(isOfficeAdmin ? 'Add Pharmacy' : 'Propose Pharmacy'),
      ),
    );
  }
}
