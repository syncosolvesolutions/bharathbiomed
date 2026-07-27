import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/user_facing_error.dart';
import 'admin_catalog_controller.dart';

class ManageDepartmentsScreen extends ConsumerStatefulWidget {
  const ManageDepartmentsScreen({super.key});

  @override
  ConsumerState<ManageDepartmentsScreen> createState() => _ManageDepartmentsScreenState();
}

class _ManageDepartmentsScreenState extends ConsumerState<ManageDepartmentsScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> _applySearch(List<String> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((name) => name.toLowerCase().contains(query)).toList();
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
      () => ref.read(adminCatalogControllerProvider.notifier).addDepartment(name),
      failureTitle: 'Failed to add department',
    );
    if (mounted) {
      setState(() => _adding = false);
      _nameController.clear();
    }
  }

  Future<void> _rename(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename department'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;

    await _runGuarded(
      () => ref.read(adminCatalogControllerProvider.notifier).renameDepartment(oldName, newName),
      failureTitle: 'Failed to rename department',
    );
  }

  Future<void> _delete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text('"$name" will be removed from every product that has it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runGuarded(
      () => ref.read(adminCatalogControllerProvider.notifier).deleteDepartment(name),
      failureTitle: 'Failed to delete department',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(adminCatalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Departments')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'New department name'),
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
                labelText: 'Search departments',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: catalog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(UserFacingError.describe(error))),
                data: (snapshot) {
                  final filtered = _applySearch(snapshot.departments);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No departments match this search.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final department = filtered[index];
                      return ListTile(
                        title: Text(department),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _rename(department)),
                            IconButton(
                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                              onPressed: () => _delete(department),
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
