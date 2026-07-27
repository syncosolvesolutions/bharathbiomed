import '../../domain/models/designation.dart';
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
    final designations = await _remote.fetchAll();
    if (designations.isNotEmpty) return designations;

    for (final name in defaultDesignations) {
      // Re-fetching before each seed insert (rather than trusting the single
      // check above) closes most of the race where two admins open
      // designation management for the first time concurrently and both
      // try to seed the defaults.
      final existing = await _remote.fetchAll();
      if (existing.any((d) => d.name.toLowerCase() == name.toLowerCase())) continue;
      await _remote.add(name);
    }
    return _remote.fetchAll();
  }

  Future<void> add(String name) async {
    final existing = await _remote.fetchAll();
    if (existing.any((d) => d.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('A designation named "$name" already exists.');
    }
    await _remote.add(name);
  }

  Future<void> rename(String id, String name) async {
    final existing = await _remote.fetchAll();
    if (existing.any((d) => d.id != id && d.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('A designation named "$name" already exists.');
    }
    await _remote.update(id, name);
  }

  Future<void> delete(String id) => _remote.delete(id);
}
