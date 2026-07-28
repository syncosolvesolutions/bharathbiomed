import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../domain/models/designation.dart';
import 'designation_controller.dart';

class ManageDesignationsScreen extends ConsumerStatefulWidget {
  const ManageDesignationsScreen({super.key});

  @override
  ConsumerState<ManageDesignationsScreen> createState() => _ManageDesignationsScreenState();
}

class _ManageDesignationsScreenState extends ConsumerState<ManageDesignationsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    debugPrint('ManageDesignationsScreen.dispose: disposing');
    _searchController.dispose();
    super.dispose();
  }

  List<Designation> _applySearch(List<Designation> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((d) => d.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _runGuarded(Future<void> Function() action, {required String failureTitle}) async {
    debugPrint('ManageDesignationsScreen._runGuarded: running action "$failureTitle"');
    try {
      await action();
      debugPrint('ManageDesignationsScreen._runGuarded: action succeeded "$failureTitle"');
    } catch (error, stackTrace) {
      debugPrint('ManageDesignationsScreen._runGuarded: action failed "$failureTitle" error=$error');
      AppLogger.error('ManageDesignations', failureTitle, error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(context: context, type: QuickAlertType.error, title: failureTitle, text: UserFacingError.describe(error));
    }
  }

  Future<void> _delete(Designation designation) async {
    debugPrint('ManageDesignationsScreen._delete: delete requested id=${designation.id}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete designation?'),
        content: Text('"${designation.name}" will no longer be selectable for new employees.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runGuarded(
      () => ref.read(designationControllerProvider.notifier).delete(designation.id),
      failureTitle: 'Failed to delete designation',
    );
  }

  @override
  Widget build(BuildContext context) {
    final designations = ref.watch(designationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Designations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add designation',
            onPressed: () => context.push('/admin/designations/add'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search designations',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: designations.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(UserFacingError.describe(error))),
                data: (items) {
                  final filtered = _applySearch(items);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No designations match this search.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final designation = filtered[index];
                      final color = AccentPalette.forLabel(designation.name);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          foregroundColor: color,
                          child: Icon(Icons.badge_outlined, color: color, size: 20),
                        ),
                        title: Text(designation.name),
                        subtitle: Text('${designation.category.label} · Level ${designation.hierarchyLevel}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => context.push('/admin/designations/edit', extra: designation),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                              onPressed: () => _delete(designation),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
