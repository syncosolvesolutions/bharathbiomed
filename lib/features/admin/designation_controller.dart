import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/designation.dart';

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

  Future<void> add(String name) async {
    debugPrint('DesignationController.add: adding designation name=$name');
    await ref.read(designationRepositoryProvider).add(name);
    debugPrint('DesignationController.add: added designation name=$name');
    await _refresh();
  }

  Future<void> rename(String id, String name) async {
    debugPrint('DesignationController.rename: renaming id=$id to name=$name');
    await ref.read(designationRepositoryProvider).rename(id, name);
    debugPrint('DesignationController.rename: renamed id=$id to name=$name');
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
