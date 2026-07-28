import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/agency.dart';

/// Holds the agency list currently shown on screen — every agency, since
/// unlike doctors this isn't scoped per-MR (see firestore.rules). Offline-
/// first like [DoctorController]: [build] only ever reads the local cache;
/// [sync] is the one place that talks to Firestore.
final agencyControllerProvider = AsyncNotifierProvider<AgencyController, List<Agency>>(AgencyController.new);

class AgencyController extends AsyncNotifier<List<Agency>> {
  @override
  Future<List<Agency>> build() {
    debugPrint('AgencyController.build: loading cached agencies');
    return ref.read(agencyRepositoryProvider).loadCached();
  }

  Future<void> sync() async {
    debugPrint('AgencyController.sync: starting agency sync with Firestore');
    final agencies = await ref.read(agencyRepositoryProvider).sync();
    debugPrint('AgencyController.sync: agency sync succeeded, ${agencies.length} agencies');
    state = AsyncData(agencies);
  }
}
