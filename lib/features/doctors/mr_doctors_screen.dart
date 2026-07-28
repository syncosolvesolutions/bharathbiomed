import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import 'doctor_controller.dart';

/// An MR's "My Doctors" list (requirement 6). Offline-first: shows whatever
/// was last synced; the sync button in the app bar both refreshes the
/// assigned-doctors list from Firestore and uploads anything queued locally
/// (visit logs, pending doctor create/edit requests) — the "sync everything
/// in the evening" flow (requirement 11/12).
class MrDoctorsScreen extends ConsumerStatefulWidget {
  const MrDoctorsScreen({super.key});

  @override
  ConsumerState<MrDoctorsScreen> createState() => _MrDoctorsScreenState();
}

class _MrDoctorsScreenState extends ConsumerState<MrDoctorsScreen> {
  final _searchController = TextEditingController();
  bool _syncing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    debugPrint('MrDoctorsScreen._sync: sync requested');
    setState(() => _syncing = true);
    String message;
    try {
      await ref.read(doctorControllerProvider.notifier).sync();
      await ref.read(doctorVisitLogRepositoryProvider).uploadPending();
      await ref.read(doctorChangeRequestRepositoryProvider).uploadPending();
      message = 'Synced successfully.';
    } catch (error, stackTrace) {
      debugPrint('MrDoctorsScreen._sync: sync failed error=$error');
      AppLogger.error('MrDoctorsScreen', 'sync failed', error: error, stackTrace: stackTrace);
      message = 'Sync failed: ${UserFacingError.describe(error)}';
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Doctor> _applyFilter(List<Doctor> doctors) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return doctors;
    return doctors
        .where((doctor) =>
            doctor.name.toLowerCase().contains(query) ||
            doctor.hospitalName.toLowerCase().contains(query) ||
            doctor.specialisation.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Doctors'),
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
                hintText: 'Name, hospital, specialisation',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: doctorsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load doctors: ${UserFacingError.describe(error)}')),
              data: (doctors) {
                if (doctors.isEmpty) {
                  return const Center(
                    child: Text(
                      'No doctors assigned yet.\nAsk your admin to assign some, or add one you\'re visiting for the first time.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final filtered = _applyFilter(doctors);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No doctors match this search.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doctor = filtered[index];
                    return ListTile(
                      onTap: () => context.push('/doctors/detail', extra: doctor),
                      leading: CircleAvatar(
                        backgroundColor: AccentPalette.forLabel(doctor.name).withValues(alpha: 0.15),
                        foregroundColor: AccentPalette.forLabel(doctor.name),
                        child: Text(doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(doctor.name),
                      subtitle: Text('${doctor.hospitalName}${doctor.specialisation.isEmpty ? '' : ' • ${doctor.specialisation}'}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/doctors/add'),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add Doctor'),
      ),
    );
  }
}
