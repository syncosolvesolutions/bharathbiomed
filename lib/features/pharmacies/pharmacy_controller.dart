import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/pharmacy.dart';

/// Holds the pharmacy list currently shown on screen — mirrors
/// [AgencyController] exactly.
final pharmacyControllerProvider = AsyncNotifierProvider<PharmacyController, List<Pharmacy>>(PharmacyController.new);

class PharmacyController extends AsyncNotifier<List<Pharmacy>> {
  @override
  Future<List<Pharmacy>> build() {
    debugPrint('PharmacyController.build: loading cached pharmacies');
    return ref.read(pharmacyRepositoryProvider).loadCached();
  }

  Future<void> sync() async {
    debugPrint('PharmacyController.sync: starting pharmacy sync with Firestore');
    final pharmacies = await ref.read(pharmacyRepositoryProvider).sync();
    debugPrint('PharmacyController.sync: pharmacy sync succeeded, ${pharmacies.length} pharmacies');
    state = AsyncData(pharmacies);
  }
}
