import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/utils/credential_share.dart';
import '../../domain/models/employee.dart';
import 'employee_controller.dart';
import 'widgets/credentials_dialog.dart';

const _defaultResetPassword = 'Bharathbio@2026';

enum _StatusFilter { all, active, suspended }

class ManageEmployeesScreen extends ConsumerStatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  ConsumerState<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends ConsumerState<ManageEmployeesScreen> {
  // Tracks employee uids with a delete/reset-password/status call in flight,
  // so a second tap can't fire a duplicate Cloud Function call before the
  // first one returns.
  final _busyUids = <String>{};
  final _searchController = TextEditingController();
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void dispose() {
    debugPrint('ManageEmployeesScreen.dispose: disposing');
    _searchController.dispose();
    super.dispose();
  }

  List<Employee> _applyFilters(List<Employee> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((employee) {
      final matchesStatus = switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.active => !employee.disabled,
        _StatusFilter.suspended => employee.disabled,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return employee.displayName.toLowerCase().contains(query) ||
          employee.username.toLowerCase().contains(query) ||
          employee.areaName.toLowerCase().contains(query) ||
          employee.designation.toLowerCase().contains(query) ||
          (employee.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Employee employee) async {
    debugPrint('ManageEmployeesScreen._delete: delete requested uid=${employee.uid}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove employee?'),
        content: Text('${employee.displayName} (${employee.username}) will no longer be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || _busyUids.contains(employee.uid)) return;

    setState(() => _busyUids.add(employee.uid));
    try {
      debugPrint('ManageEmployeesScreen._delete: calling deleteEmployee uid=${employee.uid}');
      await ref.read(employeeControllerProvider.notifier).deleteEmployee(employee.uid);
      debugPrint('ManageEmployeesScreen._delete: deleteEmployee succeeded uid=${employee.uid}');
    } catch (error, stackTrace) {
      debugPrint('ManageEmployeesScreen._delete: deleteEmployee failed error=$error');
      AppLogger.error('ManageEmployees', 'deleteEmployee failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to remove employee',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _busyUids.remove(employee.uid));
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, Employee employee) async {
    debugPrint('ManageEmployeesScreen._resetPassword: reset password requested uid=${employee.uid}');
    final controller = TextEditingController(text: _defaultResetPassword);
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset password for ${employee.displayName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Reset')),
        ],
      ),
    );
    if (newPassword == null || newPassword.length < 6 || _busyUids.contains(employee.uid)) return;

    setState(() => _busyUids.add(employee.uid));
    try {
      debugPrint('ManageEmployeesScreen._resetPassword: calling resetPassword uid=${employee.uid}');
      await ref.read(employeeControllerProvider.notifier).resetPassword(employee.uid, newPassword);
      debugPrint('ManageEmployeesScreen._resetPassword: resetPassword succeeded uid=${employee.uid}');
      if (!context.mounted) return;
      final message = buildCredentialsMessage(
        name: employee.firstName,
        username: employee.username,
        loginEmail: employee.loginIdentifier,
        password: newPassword,
      );
      await showCredentialsDialog(
        context,
        title: 'Password reset',
        message: message,
        mobileNumber: employee.mobileNumber,
      );
    } catch (error, stackTrace) {
      debugPrint('ManageEmployeesScreen._resetPassword: resetPassword failed error=$error');
      AppLogger.error('ManageEmployees', 'resetPassword failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to reset password',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _busyUids.remove(employee.uid));
    }
  }

  /// Resends just username/email (no password — it's not known once account
  /// creation/reset has happened) via the same WhatsApp/Share dialog, for
  /// when the admin wants to hand credentials to an MR again without
  /// resetting their password.
  Future<void> _sendCredentials(BuildContext context, Employee employee) async {
    debugPrint('ManageEmployeesScreen._sendCredentials: uid=${employee.uid}');
    final message = buildCredentialsMessage(
      name: employee.firstName,
      username: employee.username,
      loginEmail: employee.loginIdentifier,
    );
    await showCredentialsDialog(
      context,
      title: 'Send credentials',
      message: message,
      mobileNumber: employee.mobileNumber,
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, Employee employee, bool disabled) async {
    debugPrint('ManageEmployeesScreen._setStatus: status change requested uid=${employee.uid} disabled=$disabled');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(disabled ? 'Suspend employee?' : 'Reactivate employee?'),
        content: Text(
          disabled
              ? '${employee.displayName} will not be able to log in until reactivated. Their profile and usage '
                  'history are kept.'
              : '${employee.displayName} will be able to log in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(disabled ? 'Suspend' : 'Reactivate')),
        ],
      ),
    );
    if (confirmed != true || _busyUids.contains(employee.uid)) return;

    setState(() => _busyUids.add(employee.uid));
    try {
      debugPrint('ManageEmployeesScreen._setStatus: calling setStatus uid=${employee.uid} disabled=$disabled');
      await ref.read(employeeControllerProvider.notifier).setStatus(employee.uid, disabled: disabled);
      debugPrint('ManageEmployeesScreen._setStatus: setStatus succeeded uid=${employee.uid} disabled=$disabled');
    } catch (error, stackTrace) {
      debugPrint('ManageEmployeesScreen._setStatus: setStatus failed error=$error');
      AppLogger.error('ManageEmployees', 'setStatus failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: disabled ? 'Failed to suspend employee' : 'Failed to reactivate employee',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _busyUids.remove(employee.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Employees')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Name, username, area, designation, email',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<_StatusFilter>(
                  value: _statusFilter,
                  onChanged: (value) => setState(() => _statusFilter = value ?? _StatusFilter.all),
                  items: const [
                    DropdownMenuItem(value: _StatusFilter.all, child: Text('All')),
                    DropdownMenuItem(value: _StatusFilter.active, child: Text('Active')),
                    DropdownMenuItem(value: _StatusFilter.suspended, child: Text('Suspended')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: employees.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load employees: ${UserFacingError.describe(error)}')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No employees yet.\nTap "Add Employee" to create one.', textAlign: TextAlign.center),
                  );
                }
                final filtered = _applyFilters(items);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No employees match this search/filter.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final employee = filtered[index];
                    final isBusy = _busyUids.contains(employee.uid);
                    return ListTile(
                      onTap: () => context.push('/admin/employees/edit', extra: employee),
                      leading: CircleAvatar(
                        backgroundColor: (employee.photoUrl != null && employee.photoUrl!.isNotEmpty)
                            ? null
                            : AccentPalette.forLabel(employee.displayName).withValues(alpha: 0.15),
                        foregroundColor: AccentPalette.forLabel(employee.displayName),
                        backgroundImage: (employee.photoUrl != null && employee.photoUrl!.isNotEmpty)
                            ? NetworkImage(employee.photoUrl!)
                            : null,
                        child: (employee.photoUrl == null || employee.photoUrl!.isEmpty)
                            ? Text(
                                employee.displayName.isNotEmpty ? employee.displayName[0].toUpperCase() : '?',
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(employee.displayName)),
                          if (employee.disabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Suspended',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('${employee.designation} • ${employee.areaName} • ${employee.loginIdentifier}'),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: EdgeInsets.all(2.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(employee.disabled ? Icons.play_circle_outline : Icons.pause_circle_outline),
                                  tooltip: employee.disabled ? 'Reactivate' : 'Suspend',
                                  onPressed: () => _setStatus(context, ref, employee, !employee.disabled),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset),
                                  tooltip: 'Reset password',
                                  onPressed: () => _resetPassword(context, ref, employee),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send_outlined),
                                  tooltip: 'Send credentials',
                                  onPressed: () => _sendCredentials(context, employee),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                  tooltip: 'Remove',
                                  onPressed: () => _delete(context, ref, employee),
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
        onPressed: () => context.push('/admin/employees/add'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }
}
