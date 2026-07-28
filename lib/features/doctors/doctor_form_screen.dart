import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import '../admin/admin_access.dart';
import '../admin/employee_controller.dart';
import '../admin/widgets/photo_picker_field.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';
import '../tracking/location_service.dart';
import 'doctor_controller.dart';

/// Add/edit a doctor. Behavior branches on who's signed in:
/// - Admin: saves straight to `Doctors` (create or update), and can assign/
///   reassign the MR who visits this doctor.
/// - MR: submits a [DoctorChangeRequest] instead — queued locally so it
///   works with no signal, uploaded on the next sync — which the admin must
///   approve before it goes live (requirement 4/5).
class DoctorFormScreen extends ConsumerStatefulWidget {
  const DoctorFormScreen({super.key, this.doctor});

  final Doctor? doctor;

  @override
  ConsumerState<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends ConsumerState<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.doctor?.name);
  late final _specialisationController = TextEditingController(text: widget.doctor?.specialisation);
  late final _hospitalController = TextEditingController(text: widget.doctor?.hospitalName);
  late final _addressController = TextEditingController(text: widget.doctor?.locationAddress);
  late final _mapsLinkController = TextEditingController(text: widget.doctor?.googleMapsLink);

  late double? _latitude = widget.doctor?.latitude;
  late double? _longitude = widget.doctor?.longitude;
  late List<String> _doctorPhotos = List.of(widget.doctor?.doctorPhotoUrls ?? const []);
  late List<String> _hospitalPhotos = List.of(widget.doctor?.hospitalPhotoUrls ?? const []);
  late String? _dateOfBirth = widget.doctor?.dateOfBirth;
  late String? _anniversary = widget.doctor?.marriageAnniversary;
  late String? _assignedMrUid = widget.doctor?.assignedMrUid;
  late String? _assignedMrName = widget.doctor?.assignedMrName;

  bool _saving = false;
  bool _locating = false;

  bool get _isEditing => widget.doctor != null;

  @override
  void dispose() {
    _nameController.dispose();
    _specialisationController.dispose();
    _hospitalController.dispose();
    _addressController.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    debugPrint('DoctorFormScreen._useCurrentLocation: requesting current location');
    setState(() => _locating = true);
    try {
      final position = await LocationService().getCurrentLocationBestEffort();
      if (!mounted) return;
      if (position == null) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Location unavailable',
          text: 'Could not get your current location. Check location permission and try again, or enter it manually.',
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

  Future<void> _pickDate({required bool anniversary}) async {
    final now = DateTime.now();
    final current = anniversary ? _anniversary : _dateOfBirth;
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(current) ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (anniversary) {
        _anniversary = isoFromDate(picked);
      } else {
        _dateOfBirth = isoFromDate(picked);
      }
    });
  }

  bool get _hasLocation =>
      (_latitude != null && _longitude != null) ||
      _addressController.text.trim().isNotEmpty ||
      _mapsLinkController.text.trim().isNotEmpty;

  Doctor _buildDoctor(bool isAdmin, {String? creatorUid, String? creatorName}) {
    return Doctor(
      id: widget.doctor?.id ?? '',
      name: _nameController.text.trim(),
      specialisation: _specialisationController.text.trim(),
      hospitalName: _hospitalController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      locationAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      googleMapsLink: _mapsLinkController.text.trim().isEmpty ? null : _mapsLinkController.text.trim(),
      doctorPhotoUrls: _doctorPhotos,
      hospitalPhotoUrls: _hospitalPhotos,
      dateOfBirth: _dateOfBirth,
      marriageAnniversary: _anniversary,
      assignedMrUid: isAdmin ? _assignedMrUid : widget.doctor?.assignedMrUid,
      assignedMrName: isAdmin ? _assignedMrName : widget.doctor?.assignedMrName,
      // Carried forward unchanged on an edit — omitting them here would
      // write `null` over the original creator on every save (both
      // DoctorRemoteDataSource.updateDoctor's `.update()` and the approval
      // Cloud Function's merge write null explicitly-present fields, they
      // don't skip them).
      createdByUid: widget.doctor?.createdByUid ?? creatorUid,
      createdByName: widget.doctor?.createdByName ?? creatorName,
    );
  }

  Future<void> _save(bool isAdmin) async {
    debugPrint('DoctorFormScreen._save: save requested isAdmin=$isAdmin isEditing=$_isEditing');
    if (!_formKey.currentState!.validate()) return;
    if (!_hasLocation) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Location required',
        text: 'Please provide at least one of: current location, an address, or a Google Maps link.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = isAdmin ? 'Admin' : (ref.read(myEmployeeProfileProvider).value?.displayName ?? '');
      var doctor = _buildDoctor(isAdmin, creatorUid: uid, creatorName: myName);
      if (isAdmin) {
        if (_isEditing) {
          await ref.read(doctorRepositoryProvider).updateDoctor(doctor);
        } else {
          await ref.read(doctorRepositoryProvider).createDoctor(doctor);
        }
        await ref.read(doctorControllerProvider.notifier).sync();
      } else {
        // A doctor an MR adds for the first time is naturally theirs to
        // visit — self-assign so it's usable immediately once approved,
        // rather than landing unassigned until the admin notices and
        // assigns it. Edits to an already-assigned doctor keep whoever it's
        // currently assigned to (an MR can't reassign someone else's doctor
        // by editing it).
        if (!_isEditing) {
          doctor = doctor.copyWith(assignedMrUid: uid, assignedMrName: myName);
        }
        if (_isEditing) {
          await ref.read(doctorChangeRequestRepositoryProvider).submitUpdate(
                doctor,
                requestedByUid: uid,
                requestedByName: myName,
              );
        } else {
          await ref.read(doctorChangeRequestRepositoryProvider).submitCreate(
                doctor,
                requestedByUid: uid,
                requestedByName: myName,
              );
        }
      }

      debugPrint('DoctorFormScreen._save: save succeeded');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAdmin
            ? (_isEditing ? 'Doctor updated.' : 'Doctor added.')
            : 'Submitted for admin approval. You\'ll be notified once it\'s reviewed.'),
      ));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('DoctorFormScreen._save: save failed error=$error');
      AppLogger.error('DoctorForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save doctor',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoSlot({required String folder, required String label, required String? url, required ValueChanged<String> onUploaded}) {
    return Expanded(
      child: PhotoPickerField(folder: folder, label: label, initialImageUrl: url, onUploaded: onUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final employeesAsync = isAdmin ? ref.watch(employeeControllerProvider) : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Doctor' : 'Add Doctor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              if (!isAdmin && _isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Your changes will be reviewed by the admin before they go live.',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Doctor Name'),
                validator: (value) => Validators.name(value, fieldLabel: "doctor's name"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialisationController,
                decoration: const InputDecoration(labelText: 'Specialisation (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hospitalController,
                decoration: const InputDecoration(labelText: 'Hospital / Clinic Name'),
                validator: (value) => Validators.required(value, fieldLabel: 'hospital name'),
              ),
              const SizedBox(height: 20),
              Text('Location (at least one required)', style: Theme.of(context).textTheme.titleSmall),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _mapsLinkController,
                decoration: const InputDecoration(labelText: 'Google Maps Link (optional)'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              Text('Doctor Photos (up to 2)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  _photoSlot(
                    folder: 'doctor_photos',
                    label: 'Photo 1',
                    url: _doctorPhotos.isNotEmpty ? _doctorPhotos[0] : null,
                    onUploaded: (url) => setState(() {
                      _doctorPhotos = [url, if (_doctorPhotos.length > 1) _doctorPhotos[1]];
                    }),
                  ),
                  const SizedBox(width: 12),
                  _photoSlot(
                    folder: 'doctor_photos',
                    label: 'Photo 2',
                    url: _doctorPhotos.length > 1 ? _doctorPhotos[1] : null,
                    onUploaded: (url) => setState(() {
                      _doctorPhotos = [if (_doctorPhotos.isNotEmpty) _doctorPhotos[0], url];
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Hospital Photos (up to 2)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  _photoSlot(
                    folder: 'hospital_photos',
                    label: 'Photo 1',
                    url: _hospitalPhotos.isNotEmpty ? _hospitalPhotos[0] : null,
                    onUploaded: (url) => setState(() {
                      _hospitalPhotos = [url, if (_hospitalPhotos.length > 1) _hospitalPhotos[1]];
                    }),
                  ),
                  const SizedBox(width: 12),
                  _photoSlot(
                    folder: 'hospital_photos',
                    label: 'Photo 2',
                    url: _hospitalPhotos.length > 1 ? _hospitalPhotos[1] : null,
                    onUploaded: (url) => setState(() {
                      _hospitalPhotos = [if (_hospitalPhotos.isNotEmpty) _hospitalPhotos[0], url];
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => _pickDate(anniversary: false),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Birthday (optional)'),
                  child: Row(children: [
                    Expanded(child: Text(formatIsoForDisplay(_dateOfBirth))),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(anniversary: true),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Marriage Anniversary (optional)'),
                  child: Row(children: [
                    Expanded(child: Text(formatIsoForDisplay(_anniversary))),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ]),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                Text('Assigned MR', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                employeesAsync!.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Failed to load MRs: ${UserFacingError.describe(error)}'),
                  data: (employees) => DropdownButtonFormField<String?>(
                    initialValue: _assignedMrUid,
                    decoration: const InputDecoration(labelText: 'Assign to'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                      ...employees.map(
                        (employee) => DropdownMenuItem<String?>(value: employee.uid, child: Text(employee.displayName)),
                      ),
                    ],
                    onChanged: (uid) => setState(() {
                      _assignedMrUid = uid;
                      _assignedMrName = uid == null
                          ? null
                          : employees.firstWhere((employee) => employee.uid == uid).displayName;
                    }),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : () => _save(isAdmin),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isAdmin ? (_isEditing ? 'Save Changes' : 'Add Doctor') : 'Submit for Approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
