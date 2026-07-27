import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/designation.dart';

final designationControllerProvider =
    AsyncNotifierProvider<DesignationController, List<Designation>>(DesignationController.new);

class DesignationController extends AsyncNotifier<List<Designation>> {
  @override
  Future<List<Designation>> build() {
    return ref.read(designationRepositoryProvider).fetchAll();
  }

  Future<void> add(String name) async {
    await ref.read(designationRepositoryProvider).add(name);
    await _refresh();
  }

  Future<void> rename(String id, String name) async {
    await ref.read(designationRepositoryProvider).rename(id, name);
    await _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(designationRepositoryProvider).delete(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(() => ref.read(designationRepositoryProvider).fetchAll());
  }
}
