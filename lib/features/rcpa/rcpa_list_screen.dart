import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import 'rcpa_controller.dart';

/// The signed-in MR's own logged RCPA entries — see
/// [MyRcpaEntriesController].
class RcpaListScreen extends ConsumerWidget {
  const RcpaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(myRcpaEntriesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('RCPA Entries')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myRcpaEntriesControllerProvider.notifier).refresh(),
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load entries: ${UserFacingError.describe(error)}')),
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('No RCPA entries yet.\nTap "New Entry" below.', textAlign: TextAlign.center),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(entry.pharmacyName),
                    subtitle: Text(
                      '${entry.auditDate} • ${entry.totalOwnBrandCount} own-brand, ${entry.totalCompetitorCount} competitor'
                      '${entry.notes.isEmpty ? '' : '\n${entry.notes}'}',
                    ),
                    isThreeLine: entry.notes.isNotEmpty,
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rcpa/add'),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('New Entry'),
      ),
    );
  }
}
