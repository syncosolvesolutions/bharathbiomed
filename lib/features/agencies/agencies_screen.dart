import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../data/providers.dart';
import '../../domain/models/agency.dart';
import '../team/team_access.dart';
import 'agency_controller.dart';

/// Every agency, visible to any signed-in user (see firestore.rules). Edit
/// is only offered to [canManageAgenciesProvider] holders; deactivate/
/// reactivate only to an Office Admin. Everyone else can still tap "Add
/// Agency" — it submits a request instead of saving directly (see
/// AgencyFormScreen).
class AgenciesScreen extends ConsumerStatefulWidget {
  const AgenciesScreen({super.key});

  @override
  ConsumerState<AgenciesScreen> createState() => _AgenciesScreenState();
}

class _AgenciesScreenState extends ConsumerState<AgenciesScreen> {
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
      await ref.read(agencyControllerProvider.notifier).sync();
      message = 'Synced successfully.';
    } catch (error, stackTrace) {
      AppLogger.error('AgenciesScreen', 'sync failed', error: error, stackTrace: stackTrace);
      message = 'Sync failed: ${UserFacingError.describe(error)}';
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setActive(Agency agency, {required bool active}) async {
    try {
      await ref.read(agencyRepositoryProvider).setActive(agency.id, active: active);
      await ref.read(agencyControllerProvider.notifier).sync();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(active ? 'Agency reactivated.' : 'Agency deactivated.')));
    } catch (error, stackTrace) {
      AppLogger.error('AgenciesScreen', 'setActive failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  List<Agency> _applyFilter(List<Agency> agencies) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return agencies;
    return agencies
        .where((agency) =>
            agency.name.toLowerCase().contains(query) || agency.contactPerson.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final agenciesAsync = ref.watch(agencyControllerProvider);
    final canManage = ref.watch(canManageAgenciesProvider);
    final isOfficeAdmin = ref.watch(isOfficeAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agencies'),
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
                hintText: 'Name, contact person',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: agenciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load agencies: ${UserFacingError.describe(error)}')),
              data: (agencies) {
                if (agencies.isEmpty) {
                  return const Center(
                    child: Text('No agencies yet.\nTap "Add Agency" below to propose one.', textAlign: TextAlign.center),
                  );
                }
                final filtered = _applyFilter(agencies);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No agencies match this search.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final agency = filtered[index];
                    return ListTile(
                      onTap: canManage ? () => context.push('/agencies/edit', extra: agency) : null,
                      leading: CircleAvatar(
                        backgroundColor: AccentPalette.forLabel(agency.name).withValues(alpha: 0.15),
                        foregroundColor: AccentPalette.forLabel(agency.name),
                        child: Text(agency.name.isNotEmpty ? agency.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(agency.name, style: TextStyle(color: agency.active ? null : Colors.grey)),
                      subtitle: Text(
                        '${agency.contactPerson}${agency.phone.isEmpty ? '' : ' • ${agency.phone}'}'
                        '${agency.active ? '' : ' • Inactive'}',
                      ),
                      trailing: isOfficeAdmin
                          ? IconButton(
                              icon: Icon(agency.active ? Icons.block : Icons.check_circle_outline),
                              tooltip: agency.active ? 'Deactivate' : 'Reactivate',
                              onPressed: () => _setActive(agency, active: !agency.active),
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
        onPressed: () => context.push('/agencies/add'),
        icon: const Icon(Icons.add_business_outlined),
        label: Text(isOfficeAdmin ? 'Add Agency' : 'Propose Agency'),
      ),
    );
  }
}
