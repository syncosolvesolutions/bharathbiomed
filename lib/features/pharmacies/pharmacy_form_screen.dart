import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../../domain/models/pharmacy.dart';
import '../auth/auth_controller.dart';
import '../doctors/doctor_controller.dart';
import '../profile/profile_controller.dart';
import '../team/team_access.dart';
import '../tracking/location_service.dart';
import 'pharmacy_controller.dart';

/// Add/edit a pharmacy/chemist — mirrors [AgencyFormScreen]'s
/// edit-vs-create-vs-propose branching exactly, plus a doctor multi-select
/// for [Pharmacy.linkedDoctorIds] (surfaced in reverse on the doctor detail
/// screen). The doctor list offered here is whatever this account's
/// [doctorControllerProvider] cache already holds — an MR sees only their
/// assigned doctors, which is a reasonable limit on who they'd be linking a
/// pharmacy to anyway.
class PharmacyFormScreen extends ConsumerStatefulWidget {
  const PharmacyFormScreen({super.key, this.pharmacy});

  final Pharmacy? pharmacy;

  @override
  ConsumerState<PharmacyFormScreen> createState() => _PharmacyFormScreenState();
}

class _PharmacyFormScreenState extends ConsumerState<PharmacyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.pharmacy?.name);
  late final _phoneController = TextEditingController(text: widget.pharmacy?.phone);
  late final _addressController = TextEditingController(text: widget.pharmacy?.address);

  late double? _latitude = widget.pharmacy?.latitude;
  late double? _longitude = widget.pharmacy?.longitude;
  late List<String> _linkedDoctorIds = List.of(widget.pharmacy?.linkedDoctorIds ?? const []);

  bool _saving = false;
  bool _locating = false;

  bool get _isEditing => widget.pharmacy != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await LocationService().getCurrentLocationBestEffort();
      if (!mounted) return;
      if (position == null) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Location unavailable',
          text: 'Could not get your current location. Check location permission and try again.',
        );
        return;
      }
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Pharmacy _buildPharmacy({String? creatorUid, String? creatorName}) {
    return Pharmacy(
      id: widget.pharmacy?.id ?? '',
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      linkedDoctorIds: _linkedDoctorIds,
      assignedMrUid: widget.pharmacy?.assignedMrUid,
      assignedMrName: widget.pharmacy?.assignedMrName,
      active: widget.pharmacy?.active ?? true,
      createdByUid: widget.pharmacy?.createdByUid ?? creatorUid,
      createdByName: widget.pharmacy?.createdByName ?? creatorName,
    );
  }

  Future<void> _save({required bool canCreateDirectly}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = ref.read(isOfficeAdminProvider)
          ? 'Office Admin'
          : (ref.read(myEmployeeProfileProvider).value?.displayName ?? '');
      final pharmacy = _buildPharmacy(creatorUid: uid, creatorName: myName);

      String message;
      if (_isEditing) {
        await ref.read(pharmacyRepositoryProvider).updatePharmacy(pharmacy);
        await ref.read(pharmacyControllerProvider.notifier).sync();
        message = 'Pharmacy updated.';
      } else if (canCreateDirectly) {
        await ref.read(pharmacyRepositoryProvider).createPharmacy(pharmacy);
        await ref.read(pharmacyControllerProvider.notifier).sync();
        message = 'Pharmacy added.';
      } else {
        await ref
            .read(entityChangeRequestRepositoryProvider)
            .submitPharmacy(pharmacy, requestedByUid: uid, requestedByName: myName);
        message = 'Submitted for Office Admin approval. You\'ll be notified once it\'s reviewed.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('PharmacyForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save pharmacy',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreateDirectly = ref.watch(isOfficeAdminProvider);
    final doctorsAsync = ref.watch(doctorControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Pharmacy' : 'Add Pharmacy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              if (!_isEditing && !canCreateDirectly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'This will be submitted to the Office Admin for approval before it\'s usable.',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Pharmacy / Chemist Name'),
                validator: (value) => Validators.required(value, fieldLabel: 'pharmacy name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              Text('Location (optional)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_latitude != null && _longitude != null
                    ? 'Location captured (${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)})'
                    : 'Use Current Location'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Text('Linked Doctors (optional)', style: Theme.of(context).textTheme.titleSmall),
              Text(
                'Doctors associated with this pharmacy — shown on their profile too.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              doctorsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Failed to load doctors: ${UserFacingError.describe(error)}'),
                data: (doctors) {
                  if (doctors.isEmpty) {
                    return const Text('No doctors available to link yet.');
                  }
                  return Column(
                    children: doctors.map((doctor) {
                      final checked = _linkedDoctorIds.contains(doctor.id);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(doctor.name),
                        subtitle: Text(doctor.hospitalName),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            _linkedDoctorIds = [..._linkedDoctorIds, doctor.id];
                          } else {
                            _linkedDoctorIds = _linkedDoctorIds.where((id) => id != doctor.id).toList();
                          }
                        }),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : () => _save(canCreateDirectly: canCreateDirectly),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing
                        ? 'Save Changes'
                        : (canCreateDirectly ? 'Add Pharmacy' : 'Submit for Approval')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
