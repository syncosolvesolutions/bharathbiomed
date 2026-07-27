import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/designation.dart';
import 'designation_controller.dart';

class ManageDesignationsScreen extends ConsumerStatefulWidget {
  const ManageDesignationsScreen({super.key});

  @override
  ConsumerState<ManageDesignationsScreen> createState() => _ManageDesignationsScreenState();
}

class _ManageDesignationsScreenState extends ConsumerState<ManageDesignationsScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Designation> _applySearch(List<Designation> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((d) => d.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _runGuarded(Future<void> Function() action, {required String failureTitle}) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      QuickAlert.show(context: context, type: QuickAlertType.error, title: failureTitle, text: UserFacingError.describe(error));
    }
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _adding = true);
    await _runGuarded(
      () => ref.read(designationControllerProvider.notifier).add(name),
      failureTitle: 'Failed to add designation',
    );
    if (mounted) {
      setState(() => _adding = false);
      _nameController.clear();
    }
  }

  Future<void> _rename(Designation designation) async {
    final controller = TextEditingController(text: designation.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename designation'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == designation.name) return;

    await _runGuarded(
      () => ref.read(designationControllerProvider.notifier).rename(designation.id, newName),
      failureTitle: 'Failed to rename designation',
    );
  }

  Future<void> _delete(Designation designation) async {
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
      appBar: AppBar(title: const Text('Manage Designations')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'New designation name'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _adding ? null : _add,
                  child: _adding
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                      return ListTile(
                        title: Text(designation.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _rename(designation)),
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
