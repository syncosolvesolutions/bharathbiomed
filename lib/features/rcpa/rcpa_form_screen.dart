import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/pharmacy.dart';
import '../../domain/models/product.dart';
import '../../domain/models/rcpa_entry.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_controller.dart';
import '../doctors/doctor_controller.dart';
import '../pharmacies/pharmacy_controller.dart';
import '../tracking/location_service.dart';
import 'rcpa_controller.dart';

/// Log a Retail Chemist Prescription Audit: pick the pharmacy audited (its
/// linked doctors are shown for context — this is exactly where that
/// mapping earns its keep), count scripts per own product, add freeform
/// competitor-brand counts, optional notes. Offline-first — [logEntry] only
/// ever queues locally; it reaches Firestore on the next sync.
class RcpaFormScreen extends ConsumerStatefulWidget {
  const RcpaFormScreen({super.key});

  @override
  ConsumerState<RcpaFormScreen> createState() => _RcpaFormScreenState();
}

class _OwnBrandLine {
  _OwnBrandLine({required this.product, required this.countController});

  final Product product;
  final TextEditingController countController;
}

class _CompetitorLine {
  _CompetitorLine({required this.brandController, required this.countController});

  final TextEditingController brandController;
  final TextEditingController countController;
}

class _RcpaFormScreenState extends ConsumerState<RcpaFormScreen> {
  Pharmacy? _selectedPharmacy;
  String _auditDate = isoFromDate(DateTime.now());
  final _notesController = TextEditingController();
  final List<_OwnBrandLine> _ownBrandLines = [];
  final List<_CompetitorLine> _competitorLines = [];
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _ownBrandLines) {
      line.countController.dispose();
    }
    for (final line in _competitorLines) {
      line.brandController.dispose();
      line.countController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(_auditDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _auditDate = isoFromDate(picked));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await LocationService().getCurrentLocationBestEffort();
      if (!mounted || position == null) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addOwnBrandProduct() async {
    final products = ref.read(catalogControllerProvider).value?.products ?? const <Product>[];
    final available = products.where((p) => !_ownBrandLines.any((line) => line.product.id == p.id)).toList();
    if (available.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No more products',
        text: 'Every synced product is already on this entry.',
      );
      return;
    }
    final chosen = await showDialog<Product>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add product'),
        children: available
            .map((product) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, product),
                  child: Text(product.name),
                ))
            .toList(),
      ),
    );
    if (chosen == null) return;
    setState(() {
      _ownBrandLines.add(_OwnBrandLine(product: chosen, countController: TextEditingController(text: '1')));
    });
  }

  void _addCompetitorRow() {
    setState(() {
      _competitorLines.add(_CompetitorLine(
        brandController: TextEditingController(),
        countController: TextEditingController(text: '1'),
      ));
    });
  }

  Future<void> _save() async {
    if (_selectedPharmacy == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Pharmacy required',
        text: 'Please select which pharmacy this audit was at.',
      );
      return;
    }

    final ownBrandCounts = <RcpaProductCount>[];
    for (final line in _ownBrandLines) {
      final count = int.tryParse(line.countController.text.trim()) ?? 0;
      if (count > 0) {
        ownBrandCounts.add(RcpaProductCount(productId: line.product.id, productName: line.product.name, count: count));
      }
    }
    final competitorCounts = <RcpaCompetitorCount>[];
    for (final line in _competitorLines) {
      final brand = line.brandController.text.trim();
      final count = int.tryParse(line.countController.text.trim()) ?? 0;
      if (brand.isNotEmpty && count > 0) {
        competitorCounts.add(RcpaCompetitorCount(brandName: brand, count: count));
      }
    }
    if (ownBrandCounts.isEmpty && competitorCounts.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Nothing to log',
        text: 'Add at least one own-brand or competitor count.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      await ref.read(rcpaRepositoryProvider).logEntry(RcpaEntry(
            id: const Uuid().v4(),
            mrUid: uid,
            pharmacyId: _selectedPharmacy!.id,
            pharmacyName: _selectedPharmacy!.name,
            auditDate: _auditDate,
            ownBrandCounts: ownBrandCounts,
            competitorCounts: competitorCounts,
            notes: _notesController.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
            createdAt: DateTime.now(),
          ));
      ref.invalidate(myRcpaEntriesControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('RCPA entry queued — will upload on next sync.')));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('RcpaForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save entry',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmaciesAsync = ref.watch(pharmacyControllerProvider);
    final doctorsAsync = ref.watch(doctorControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log RCPA Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            pharmaciesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load pharmacies: ${UserFacingError.describe(error)}'),
              data: (pharmacies) => DropdownButtonFormField<Pharmacy>(
                initialValue: _selectedPharmacy,
                decoration: const InputDecoration(labelText: 'Pharmacy'),
                items:
                    pharmacies.map((pharmacy) => DropdownMenuItem(value: pharmacy, child: Text(pharmacy.name))).toList(),
                onChanged: (pharmacy) => setState(() => _selectedPharmacy = pharmacy),
              ),
            ),
            if (_selectedPharmacy != null && _selectedPharmacy!.linkedDoctorIds.isNotEmpty)
              doctorsAsync.maybeWhen(
                data: (doctors) {
                  final linked =
                      doctors.where((doctor) => _selectedPharmacy!.linkedDoctorIds.contains(doctor.id)).toList();
                  if (linked.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Linked doctors: ${linked.map((d) => d.name).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Audit Date'),
                child: Row(children: [
                  Expanded(child: Text(formatIsoForDisplay(_auditDate))),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_latitude != null && _longitude != null
                  ? 'Location captured (${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)})'
                  : 'Use Current Location (optional)'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Own Brand Scripts', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(onPressed: _addOwnBrandProduct, icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            ..._ownBrandLines.map((line) => Row(
                  children: [
                    Expanded(child: Text(line.product.name)),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: line.countController,
                        decoration: const InputDecoration(labelText: 'Count', isDense: true),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _ownBrandLines.remove(line)),
                    ),
                  ],
                )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Competitor Brand Scripts', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(onPressed: _addCompetitorRow, icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            ..._competitorLines.map((line) => Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: line.brandController,
                        decoration: const InputDecoration(labelText: 'Brand name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: line.countController,
                        decoration: const InputDecoration(labelText: 'Count', isDense: true),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _competitorLines.remove(line)),
                    ),
                  ],
                )),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
