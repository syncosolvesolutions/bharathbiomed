import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../admin/widgets/photo_picker_field.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';

/// Mandatory one-time step for a newly created MR account: no back button,
/// no skip — the app router redirects here on every route until a photo and
/// name are saved (see `needsProfileCompletion` in app_router.dart). Reuses
/// [EmployeeRepository.updateMyProfile], which flips
/// `Employee.profileCompleted` to `true` as a side effect of any self-service
/// save, so completing this screen also unblocks the router.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
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

  Future<void> _save() async {
    debugPrint('CompleteProfileScreen._save: save requested');
    if (!_formKey.currentState!.validate()) return;
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Photo required',
        text: 'Please add a profile photo before continuing.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(employeeRepositoryProvider).updateMyProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            mobileNumber: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
            photoUrl: _photoUrl,
            dateOfBirth: _dateOfBirth,
          );
      debugPrint('CompleteProfileScreen._save: profile completed');
      if (!mounted) return;
      // The router's redirect re-evaluates once myEmployeeProfileProvider's
      // stream picks up profileCompleted=true, but navigate immediately too
      // rather than waiting on that round trip through Firestore.
      context.go('/catalog');
    } catch (error, stackTrace) {
      debugPrint('CompleteProfileScreen._save: failed error=$error');
      AppLogger.error('CompleteProfile', 'updateMyProfile failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save profile',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    debugPrint('CompleteProfileScreen._logout: logout requested');
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myEmployeeProfileProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          automaticallyImplyLeading: false,
          actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Log out', onPressed: _logout)],
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load profile: ${UserFacingError.describe(error)}')),
          data: (employee) {
            if (employee != null) _applyEmployee(employee);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  children: [
                    const Text(
                      "Welcome! Before you get started, please add a profile photo and confirm your name.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: PhotoPickerField(
                        folder: 'employee_photos',
                        label: 'Add Photo',
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
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(labelText: 'Mobile Number (optional)'),
                      keyboardType: TextInputType.phone,
                      validator: Validators.mobileNumber,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save & Continue'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
