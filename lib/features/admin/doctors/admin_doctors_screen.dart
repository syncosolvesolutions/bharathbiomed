import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_logger.dart';
import '../../../core/error/user_facing_error.dart';
import '../../../core/theme/accent_palette.dart';
import '../../../data/providers.dart';
import '../../../domain/models/doctor.dart';
import '../../../domain/models/employee.dart';
import '../../doctors/doctor_controller.dart';
import '../employee_controller.dart';

/// Admin's full doctor roster (requirement 1/2/8): every doctor regardless
/// of assignment, with search, add/edit, and quick MR reassignment.
class AdminDoctorsScreen extends ConsumerStatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  ConsumerState<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends ConsumerState<AdminDoctorsScreen> {
  final _searchController = TextEditingController();
  final _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    // The admin's doctor list should always reflect Firestore, not whatever
    // was last cached on this device — mirrors how ManageEmployeesScreen
    // treats the employee list as always-live.
    Future.microtask(() => ref.read(doctorControllerProvider.notifier).sync());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Doctor> _applyFilter(List<Doctor> doctors) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return doctors;
    return doctors
        .where((doctor) =>
            doctor.name.toLowerCase().contains(query) ||
            doctor.hospitalName.toLowerCase().contains(query) ||
            (doctor.assignedMrName ?? '').toLowerCase().contains(query))
        .toList();
  }

  Future<void> _reassign(Doctor doctor) async {
    final employees = ref.read(employeeControllerProvider).value ?? const [];
    final chosen = await showDialog<Object?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Assign ${doctor.name} to'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(_unassignSentinel), child: const Text('Unassigned')),
          ...employees.map(
            (employee) => SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(employee),
              child: Text(employee.displayName),
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    setState(() => _busyIds.add(doctor.id));
    try {
      if (chosen == _unassignSentinel) {
        await ref.read(doctorRepositoryProvider).assignMr(doctor.id, mrUid: null, mrName: null);
      } else {
        final employee = chosen as Employee;
        await ref.read(doctorRepositoryProvider).assignMr(doctor.id, mrUid: employee.uid, mrName: employee.displayName);
      }
      await ref.read(doctorControllerProvider.notifier).sync();
    } catch (error, stackTrace) {
      AppLogger.error('AdminDoctors', 'reassign failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to reassign: ${UserFacingError.describe(error)}')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(doctor.id));
    }
  }

  Future<void> _delete(Doctor doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove doctor?'),
        content: Text('${doctor.name} (${doctor.hospitalName}) will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyIds.add(doctor.id));
    try {
      await ref.read(doctorRepositoryProvider).deleteDoctor(doctor.id);
      await ref.read(doctorControllerProvider.notifier).sync();
    } catch (error, stackTrace) {
      AppLogger.error('AdminDoctors', 'delete failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to remove doctor: ${UserFacingError.describe(error)}')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(doctor.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Doctors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Pending Requests',
            onPressed: () => context.push('/admin/doctors/requests'),
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
                hintText: 'Name, hospital, assigned MR',
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
                    child: Text('No doctors yet.\nTap "Add Doctor" to create one.', textAlign: TextAlign.center),
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
                    final busy = _busyIds.contains(doctor.id);
                    return ListTile(
                      onTap: () => context.push('/admin/doctors/edit', extra: doctor),
                      leading: CircleAvatar(
                        backgroundColor: AccentPalette.forLabel(doctor.name).withValues(alpha: 0.15),
                        foregroundColor: AccentPalette.forLabel(doctor.name),
                        child: Text(doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(doctor.name),
                      subtitle: Text(
                          '${doctor.hospitalName} • ${doctor.assignedMrName ?? 'Unassigned'}'),
                      trailing: busy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person_pin_circle_outlined),
                                  tooltip: 'Assign MR',
                                  onPressed: () => _reassign(doctor),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                  tooltip: 'Remove',
                                  onPressed: () => _delete(doctor),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/doctors/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
      ),
    );
  }
}

const _unassignSentinel = Object();
