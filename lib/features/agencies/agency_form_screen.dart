import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../../domain/models/agency.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';
import '../team/team_access.dart';
import '../tracking/location_service.dart';
import 'agency_controller.dart';

/// Add/edit an agency. Behavior branches on who's signed in and whether
/// this is a create or an edit:
/// - Editing an existing agency: only reachable by someone
///   [canManageAgenciesProvider] allows (Office Admin, or a designation
///   holding `manage_agencies`) — the list screen never shows an edit
///   button to anyone else. Saves straight to `Agencies`.
/// - Creating a new one: an Office Admin saves straight to `Agencies`;
///   anyone else submits an [EntityChangeRequest] instead — queued locally
///   so it works with no signal, uploaded on the next sync — which an
///   Office Admin must approve before it goes live.
class AgencyFormScreen extends ConsumerStatefulWidget {
  const AgencyFormScreen({super.key, this.agency});

  final Agency? agency;

  @override
  ConsumerState<AgencyFormScreen> createState() => _AgencyFormScreenState();
}

class _AgencyFormScreenState extends ConsumerState<AgencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.agency?.name);
  late final _contactController = TextEditingController(text: widget.agency?.contactPerson);
  late final _phoneController = TextEditingController(text: widget.agency?.phone);
  late final _addressController = TextEditingController(text: widget.agency?.address);
  late final _gstController = TextEditingController(text: widget.agency?.gstNumber);

  late double? _latitude = widget.agency?.latitude;
  late double? _longitude = widget.agency?.longitude;

  bool _saving = false;
  bool _locating = false;

  bool get _isEditing => widget.agency != null;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
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

  Agency _buildAgency({String? creatorUid, String? creatorName}) {
    return Agency(
      id: widget.agency?.id ?? '',
      name: _nameController.text.trim(),
      contactPerson: _contactController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      gstNumber: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
      active: widget.agency?.active ?? true,
      createdByUid: widget.agency?.createdByUid ?? creatorUid,
      createdByName: widget.agency?.createdByName ?? creatorName,
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
      final agency = _buildAgency(creatorUid: uid, creatorName: myName);

      String message;
      if (_isEditing) {
        await ref.read(agencyRepositoryProvider).updateAgency(agency);
        await ref.read(agencyControllerProvider.notifier).sync();
        message = 'Agency updated.';
      } else if (canCreateDirectly) {
        await ref.read(agencyRepositoryProvider).createAgency(agency);
        await ref.read(agencyControllerProvider.notifier).sync();
        message = 'Agency added.';
      } else {
        await ref
            .read(entityChangeRequestRepositoryProvider)
            .submitAgency(agency, requestedByUid: uid, requestedByName: myName);
        message = 'Submitted for Office Admin approval. You\'ll be notified once it\'s reviewed.';
      }

      debugPrint('AgencyFormScreen._save: save succeeded');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('AgencyForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save agency',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreateDirectly = ref.watch(isOfficeAdminProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Agency' : 'Add Agency')),
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
                decoration: const InputDecoration(labelText: 'Agency Name'),
                validator: (value) => Validators.required(value, fieldLabel: 'agency name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gstController,
                decoration: const InputDecoration(labelText: 'GST Number (optional)'),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : () => _save(canCreateDirectly: canCreateDirectly),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing
                        ? 'Save Changes'
                        : (canCreateDirectly ? 'Add Agency' : 'Submit for Approval')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
