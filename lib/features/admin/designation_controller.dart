import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/designation.dart';
import '../../domain/models/permission.dart';

final designationControllerProvider =
    AsyncNotifierProvider<DesignationController, List<Designation>>(DesignationController.new);

class DesignationController extends AsyncNotifier<List<Designation>> {
  @override
  Future<List<Designation>> build() async {
    debugPrint('DesignationController.build: fetching designations');
    final result = await ref.read(designationRepositoryProvider).fetchAll();
    debugPrint('DesignationController.build: fetched ${result.length} designations');
    return result;
  }

  Future<void> save({
    String? id,
    required String name,
    required DesignationCategory category,
    required int hierarchyLevel,
    String? parentDesignationId,
    required Set<Permission> permissions,
    required Set<String> downlineDesignationIds,
  }) async {
    debugPrint('DesignationController.save: saving id=$id name=$name');
    await ref.read(designationRepositoryProvider).save(
          id: id,
          name: name,
          category: category,
          hierarchyLevel: hierarchyLevel,
          parentDesignationId: parentDesignationId,
          permissions: permissions,
          downlineDesignationIds: downlineDesignationIds,
        );
    debugPrint('DesignationController.save: saved id=$id name=$name');
    await _refresh();
  }

  Future<void> delete(String id) async {
    debugPrint('DesignationController.delete: deleting id=$id');
    await ref.read(designationRepositoryProvider).delete(id);
    debugPrint('DesignationController.delete: deleted id=$id');
    await _refresh();
  }

  Future<void> _refresh() async {
    debugPrint('DesignationController._refresh: refreshing designations');
    state = await AsyncValue.guard(() => ref.read(designationRepositoryProvider).fetchAll());
    debugPrint('DesignationController._refresh: done, hasError=${state.hasError}');
  }
}
