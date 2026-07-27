import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/employee_repository.dart';
import '../../domain/models/employee.dart';
import 'designation_controller.dart';
import 'employee_controller.dart';
import 'widgets/photo_picker_field.dart';

const _defaultPassword = 'Bharathbio@2026';

/// Add or edit an employee. `employee == null` means "add" — the username is
/// auto-suggested from the name (editable before saving) and a password
/// field is shown, since the account doesn't exist yet; both are then shown
/// back to the admin in the confirmation alert to hand to the MR. Editing an
/// existing employee lets the username be changed too, but password changes
/// go through the separate "Reset Password" action in Manage Employees
/// instead, since that's a distinct, more sensitive action worth its own
/// confirmation step.
class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employee});

  final Employee? employee;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(text: widget.employee?.firstName);
  late final _lastNameController = TextEditingController(text: widget.employee?.lastName);
  late final _usernameController = TextEditingController(text: widget.employee?.username);
  late final _areaController = TextEditingController(text: widget.employee?.areaName);
  late final _mobileController = TextEditingController(text: widget.employee?.mobileNumber);
  late final _emailController = TextEditingController(text: widget.employee?.email);
  final _passwordController = TextEditingController(text: _defaultPassword);

  late String? _designation = widget.employee?.designation;
  late String? _photoUrl = widget.employee?.photoUrl;
  bool _saving = false;

  /// Once the admin has typed into the username field themselves, name
  /// changes stop overwriting it — the autofill is just a starting point.
  bool _usernameManuallyEdited = false;
  bool _settingUsernameProgrammatically = false;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    if (!_isEditing) {
      _firstNameController.addListener(_autofillUsername);
      _lastNameController.addListener(_autofillUsername);
    }
  }

  void _autofillUsername() {
    if (_usernameManuallyEdited) return;
    String slug(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final first = slug(_firstNameController.text);
    final last = slug(_lastNameController.text);
    final suggestion = first.isEmpty || last.isEmpty ? '$first$last' : '${first}_$last';
    _settingUsernameProgrammatically = true;
    _usernameController.text = suggestion;
    _settingUsernameProgrammatically = false;
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_autofillUsername);
    _lastNameController.removeListener(_autofillUsername);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _areaController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_designation == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Designation required',
        text: 'Please choose a designation.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final email = _emailController.text.trim();
      final mobile = _mobileController.text.trim();
      final EmployeeCredentials credentials;
      if (_isEditing) {
        credentials = await ref.read(employeeControllerProvider.notifier).updateEmployee(
              uid: widget.employee!.uid,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              username: _usernameController.text.trim(),
              designation: _designation!,
              areaName: _areaController.text.trim(),
              email: email,
              mobileNumber: mobile.isEmpty ? null : mobile,
              photoUrl: _photoUrl,
            );
      } else {
        credentials = await ref.read(employeeControllerProvider.notifier).createEmployee(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              username: _usernameController.text.trim().toLowerCase(),
              password: _passwordController.text,
              designation: _designation!,
              areaName: _areaController.text.trim(),
              email: email,
              mobileNumber: mobile.isEmpty ? null : mobile,
              photoUrl: _photoUrl,
            );
      }

      if (!mounted) return;
      final usernameLine = 'Username: ${credentials.username}';
      final loginLine = 'Email: ${credentials.loginEmail}';
      final passwordLine = _isEditing ? '' : '\nPassword: ${_passwordController.text}';
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: _isEditing ? 'Employee updated' : 'Employee created',
        text: _isEditing
            ? 'Updated login for this MR:\n$usernameLine\n$loginLine'
            : 'Login for this MR:\n$usernameLine\n$loginLine$passwordLine\n\n'
                'Share these with them directly.',
        confirmBtnText: 'Done',
        onConfirmBtnTap: () => Navigator.of(context).pop(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: _isEditing ? 'Failed to update employee' : 'Failed to create employee',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final designations = ref.watch(designationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Employee' : 'Add Employee')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              PhotoPickerField(
                folder: 'employee_photos',
                label: 'Pick Photo',
                initialImageUrl: widget.employee?.photoUrl,
                onUploaded: (url) => setState(() => _photoUrl = url),
              ),
              const SizedBox(height: 12),
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
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  helperText: _isEditing
                      ? 'Lowercase letters, numbers, dots, underscores or hyphens only.'
                      : 'Auto-filled from the name above — edit if you\'d like something different.',
                ),
                onChanged: (_) {
                  if (!_settingUsernameProgrammatically) _usernameManuallyEdited = true;
                },
                validator: Validators.username,
              ),
              const SizedBox(height: 12),
              designations.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Failed to load designations: ${UserFacingError.describe(error)}'),
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _designation,
                  decoration: const InputDecoration(labelText: 'Designation'),
                  items: items.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList(),
                  onChanged: (value) => setState(() => _designation = value),
                  validator: (value) => value == null ? 'Please choose a designation' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area / Territory'),
                validator: (value) => Validators.required(value, fieldLabel: 'area name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number (optional)'),
                keyboardType: TextInputType.phone,
                validator: Validators.mobileNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'They log in with this email, and can use "Forgot password?" to reset it themselves.',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'Defaults to a standard password — edit it if you want to set a different one.',
                  ),
                  validator: Validators.newPassword,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Update Employee' : 'Create Employee'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
