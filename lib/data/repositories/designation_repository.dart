import 'package:flutter/foundation.dart';

import '../../domain/models/designation.dart';
import '../../domain/models/permission.dart';
import '../remote/designation_remote_data_source.dart';

/// Default designations seeded the first time the admin opens designation
/// management, modeled on a typical Indian pharma sales field-force
/// hierarchy (e.g. Mankind Pharma's MR -> ABM -> RBM -> ZBM ladder). Purely
/// a starting point — the admin can add, rename, or delete freely from here.
const defaultDesignations = [
  'Medical Representative',
  'Senior Medical Representative',
  'Area Business Manager',
  'Regional Business Manager',
  'Zonal Business Manager',
];

class DesignationRepository {
  DesignationRepository({DesignationRemoteDataSource? remote}) : _remote = remote ?? DesignationRemoteDataSource();

  final DesignationRemoteDataSource _remote;

  Future<List<Designation>> fetchAll() async {
    debugPrint('DesignationRepository.fetchAll: fetching designations');
    final designations = await _remote.fetchAll();
    if (designations.isNotEmpty) return designations;

    debugPrint('DesignationRepository.fetchAll: no designations found, seeding defaults');
    for (final name in defaultDesignations) {
      // Re-fetching before each seed insert (rather than trusting the single
      // check above) closes most of the race where two admins open
      // designation management for the first time concurrently and both
      // try to seed the defaults.
      final existing = await _remote.fetchAll();
      if (existing.any((d) => d.name.toLowerCase() == name.toLowerCase())) continue;
      await _remote.add({'name': name});
    }
    return _remote.fetchAll();
  }

  /// Upserts a designation ([id] null means create) and, in the same
  /// operation, writes back `parentDesignationId` on every designation whose
  /// "reports to this designation" checkbox state changed —
  /// [downlineDesignationIds] is the full desired set of children for this
  /// designation; anything currently pointing here that isn't in that set
  /// gets its parent cleared.
  Future<String> save({
    String? id,
    required String name,
    required DesignationCategory category,
    required int hierarchyLevel,
    String? parentDesignationId,
    required Set<Permission> permissions,
    required Set<String> downlineDesignationIds,
  }) async {
    debugPrint('DesignationRepository.save: saving id=$id name=$name category=$category');
    final existing = await _remote.fetchAll();
    final duplicate = existing.any((d) => d.id != id && d.name.toLowerCase() == name.toLowerCase());
    if (duplicate) {
      throw Exception('A designation named "$name" already exists.');
    }

    final data = Designation(
      id: id ?? '',
      name: name,
      category: category,
      hierarchyLevel: hierarchyLevel,
      parentDesignationId: parentDesignationId,
      permissions: permissions.map((p) => p.value).toList(),
    ).toJson();

    final savedId = id;
    String resolvedId;
    if (savedId == null) {
      resolvedId = await _remote.add(data);
    } else {
      await _remote.update(savedId, data);
      resolvedId = savedId;
    }

    if (savedId != null) {
      // Editing an existing designation: diff against who currently points
      // here so only actual changes get written.
      final currentChildren = existing.where((d) => d.parentDesignationId == savedId).map((d) => d.id).toSet();
      final toAssign = downlineDesignationIds.difference(currentChildren);
      final toClear = currentChildren.difference(downlineDesignationIds);
      if (toAssign.isNotEmpty || toClear.isNotEmpty) {
        await _remote.updateParents({
          for (final childId in toAssign) childId: resolvedId,
          for (final childId in toClear) childId: null,
        });
      }
    } else if (downlineDesignationIds.isNotEmpty) {
      // Brand-new designation can't have had any children pointing at it yet.
      await _remote.updateParents({for (final childId in downlineDesignationIds) childId: resolvedId});
    }

    debugPrint('DesignationRepository.save: saved id=$resolvedId');
    return resolvedId;
  }

  Future<void> delete(String id) async {
    debugPrint('DesignationRepository.delete: deleting designation id=$id');
    if (await _remote.isAssignedToAnyEmployee(id)) {
      throw Exception('Cannot delete a designation that is assigned to one or more employees.');
    }
    return _remote.delete(id);
  }
}
