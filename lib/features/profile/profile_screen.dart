import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../../domain/models/admin_profile.dart';
import '../../domain/models/employee.dart';
import '../admin/admin_access.dart';
import '../admin/widgets/photo_picker_field.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';

/// Profile screen for both roles: an MR sees their admin-managed
/// username/email/designation/area as read-only alongside editable
/// photo/name/mobile/date-of-birth; the admin (no `Users` doc at all) edits
/// their own small `AdminProfile` doc directly.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: isAdmin ? const _AdminProfileForm() : const _EmployeeProfileForm(),
    );
  }
}

class _EmployeeProfileForm extends ConsumerStatefulWidget {
  const _EmployeeProfileForm();

  @override
  ConsumerState<_EmployeeProfileForm> createState() => _EmployeeProfileFormState();
}

class _EmployeeProfileFormState extends ConsumerState<_EmployeeProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  String? _photoUrl;
  String? _dateOfBirth;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _applyEmployee(Employee employee) {
    if (_initialized) return;
    _initialized = true;
    _firstNameController.text = employee.firstName;
    _lastNameController.text = employee.lastName;
    _mobileController.text = employee.mobileNumber ?? '';
    _photoUrl = employee.photoUrl;
    _dateOfBirth = employee.dateOfBirth;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(_dateOfBirth) ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = isoFromDate(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(employeeRepositoryProvider).updateMyProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            mobileNumber: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
            photoUrl: _photoUrl,
            dateOfBirth: _dateOfBirth,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error, stackTrace) {
      AppLogger.error('ProfileScreen', 'updateMyProfile failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to update profile',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myEmployeeProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load profile: ${UserFacingError.describe(error)}')),
      data: (employee) {
        if (employee == null) {
          return const Center(child: Text('No profile found.'));
        }
        _applyEmployee(employee);
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                Center(
                  child: PhotoPickerField(
                    folder: 'employee_photos',
                    label: 'Change Photo',
                    initialImageUrl: _photoUrl,
                    onUploaded: (url) => setState(() => _photoUrl = url),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (value) => Validators.name(value, fieldLabel: 'first name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (value) => Validators.name(value, fieldLabel: 'last name'),
                ),
                const SizedBox(height: 12),
                _ReadOnlyField(label: 'Username', value: employee.username),
                const SizedBox(height: 12),
                _ReadOnlyField(label: 'Email', value: employee.email ?? '—'),
                const SizedBox(height: 12),
                _ReadOnlyField(label: 'Designation', value: employee.designation),
                const SizedBox(height: 12),
                _ReadOnlyField(label: 'Area / Territory', value: employee.areaName),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                  validator: Validators.mobileNumber,
                  maxLength: 10,
                ),
                const SizedBox(height: 4),
                _DateOfBirthTile(
                  value: _dateOfBirth,
                  isBirthdayToday: employee.isBirthdayToday,
                  onTap: _pickDateOfBirth,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminProfileForm extends ConsumerStatefulWidget {
  const _AdminProfileForm();

  @override
  ConsumerState<_AdminProfileForm> createState() => _AdminProfileFormState();
}

class _AdminProfileFormState extends ConsumerState<_AdminProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  String? _photoUrl;
  String? _dateOfBirth;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _applyProfile(AdminProfile profile) {
    if (_initialized) return;
    _initialized = true;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _mobileController.text = profile.mobileNumber ?? '';
    _photoUrl = profile.photoUrl;
    _dateOfBirth = profile.dateOfBirth;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(_dateOfBirth) ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = isoFromDate(picked));
  }

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminProfileRepositoryProvider).save(AdminProfile(
            uid: uid,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            mobileNumber: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
            photoUrl: _photoUrl,
            dateOfBirth: _dateOfBirth,
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error, stackTrace) {
      AppLogger.error('ProfileScreen', 'admin profile save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to update profile',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myAdminProfileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load profile: ${UserFacingError.describe(error)}')),
      data: (profile) {
        final uid = ref.watch(authControllerProvider).value?.uid ?? '';
        final resolved = profile ?? AdminProfile(uid: uid);
        _applyProfile(resolved);
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                Center(
                  child: PhotoPickerField(
                    folder: 'employee_photos',
                    label: 'Change Photo',
                    initialImageUrl: _photoUrl,
                    onUploaded: (url) => setState(() => _photoUrl = url),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (value) => Validators.name(value, fieldLabel: 'first name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (value) => Validators.name(value, fieldLabel: 'last name'),
                ),
                const SizedBox(height: 12),
                const _ReadOnlyField(label: 'Email', value: 'bharathbiomedpharma@gmail.com'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                  validator: Validators.mobileNumber,
                  maxLength: 10,
                ),
                const SizedBox(height: 4),
                _DateOfBirthTile(value: _dateOfBirth, isBirthdayToday: false, onTap: _pickDateOfBirth),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(resolved.uid.isNotEmpty ? resolved.uid : profile?.uid ?? ''),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _DateOfBirthTile extends StatelessWidget {
  const _DateOfBirthTile({required this.value, required this.isBirthdayToday, required this.onTap});

  final String? value;
  final bool isBirthdayToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Date of Birth'),
        child: Row(
          children: [
            Expanded(child: Text(formatIsoForDisplay(value))),
            if (isBirthdayToday) ...[
              const SizedBox(width: 8),
              Text('🎂', style: Theme.of(context).textTheme.titleMedium),
            ],
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
