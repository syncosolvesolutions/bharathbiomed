import 'package:bharathbiomedpharma/data/remote/designation_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/designation_repository.dart';
import 'package:bharathbiomedpharma/domain/models/designation.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDesignationRemoteDataSource extends Mock implements DesignationRemoteDataSource {}

void main() {
  late MockDesignationRemoteDataSource remote;
  late DesignationRepository repository;

  const rm = Designation(id: 'd1', name: 'Regional Manager', hierarchyLevel: 1);
  const abm = Designation(id: 'd2', name: 'Area Business Manager', hierarchyLevel: 2, parentDesignationId: 'd1');
  const mr = Designation(id: 'd3', name: 'Medical Representative', hierarchyLevel: 3, parentDesignationId: 'd1');

  setUp(() {
    remote = MockDesignationRemoteDataSource();
    repository = DesignationRepository(remote: remote);
  });

  group('fetchAll', () {
    test('returns the remote list as-is when it is non-empty', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm]);

      final result = await repository.fetchAll();

      expect(result, [rm, abm]);
      verifyNever(() => remote.add(any()));
    });

    test('seeds every default designation exactly once when the collection is empty', () async {
      // Every fetchAll() call (the initial check, the per-default re-fetch,
      // and the final re-fetch) sees an empty collection — `add` is a no-op
      // mock here, so nothing ever actually gets seeded into this fake
      // collection between calls.
      when(() => remote.fetchAll()).thenAnswer((_) async => const []);
      when(() => remote.add(any())).thenAnswer((_) async => 'new-id');

      await repository.fetchAll();

      verify(() => remote.add(any())).called(defaultDesignations.length);
    });

    test('skips a default whose name (case-insensitively) already exists, without adding a duplicate', () async {
      // Simulates the race-mitigation re-fetch seeing another admin's
      // in-flight seed: the first default name in the ladder already exists
      // by the time this one is about to be added.
      final alreadySeeded = Designation(id: 'existing', name: defaultDesignations.first.toUpperCase());
      when(() => remote.add(any())).thenAnswer((_) async => 'new-id');

      // First fetchAll() (the outer check) returns empty; every subsequent
      // per-default re-fetch returns a collection that already contains the
      // first default under a different case.
      var first = true;
      when(() => remote.fetchAll()).thenAnswer((_) async {
        if (first) {
          first = false;
          return const [];
        }
        return [alreadySeeded];
      });

      await repository.fetchAll();

      // Every default except the one that "already exists" gets added.
      verify(() => remote.add(any())).called(defaultDesignations.length - 1);
    });
  });

  group('save', () {
    setUp(() {
      registerFallbackValue(<String, String?>{});
    });

    test('throws when another designation already has the same name (case-insensitive)', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm]);

      expect(
        () => repository.save(
          name: 'area business manager',
          category: DesignationCategory.field,
          hierarchyLevel: 2,
          permissions: const {},
          downlineDesignationIds: const {},
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => remote.add(any()));
      verifyNever(() => remote.update(any(), any()));
    });

    test('allows saving with its own unchanged name (excludes itself from the duplicate check)', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm]);
      when(() => remote.update('d2', any())).thenAnswer((_) async {});

      final id = await repository.save(
        id: 'd2',
        name: 'Area Business Manager',
        category: DesignationCategory.field,
        hierarchyLevel: 2,
        permissions: const {},
        downlineDesignationIds: const {},
      );

      expect(id, 'd2');
      verify(() => remote.update('d2', any())).called(1);
    });

    test('id=null creates a new designation via add', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm]);
      when(() => remote.add(any())).thenAnswer((_) async => 'new-id');

      final id = await repository.save(
        name: 'Zonal Business Manager',
        category: DesignationCategory.field,
        hierarchyLevel: 0,
        permissions: const {Permission.approveOrders},
        downlineDesignationIds: const {},
      );

      expect(id, 'new-id');
      final data = verify(() => remote.add(captureAny())).captured.single as Map<String, dynamic>;
      expect(data['name'], 'Zonal Business Manager');
      expect(data['permissions'], [Permission.approveOrders.value]);
    });

    test('a brand-new designation with a non-empty downline writes parents for all of them', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm, mr]);
      when(() => remote.add(any())).thenAnswer((_) async => 'new-id');
      when(() => remote.updateParents(any())).thenAnswer((_) async {});

      await repository.save(
        name: 'New Top Designation',
        category: DesignationCategory.field,
        hierarchyLevel: 0,
        permissions: const {},
        downlineDesignationIds: const {'d2', 'd3'},
      );

      verify(() => remote.updateParents({'d2': 'new-id', 'd3': 'new-id'})).called(1);
    });

    test('editing an existing designation only writes parents for children that actually changed', () async {
      // d2 and d3 already point at d1; the desired downline set now drops
      // d3 and adds a hypothetical d4 — only those two should be written.
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm, mr]);
      when(() => remote.update('d1', any())).thenAnswer((_) async {});
      when(() => remote.updateParents(any())).thenAnswer((_) async {});

      await repository.save(
        id: 'd1',
        name: 'Regional Manager',
        category: DesignationCategory.field,
        hierarchyLevel: 1,
        permissions: const {},
        downlineDesignationIds: const {'d2', 'd4'},
      );

      verify(() => remote.updateParents({'d4': 'd1', 'd3': null})).called(1);
    });

    test('editing an existing designation with no downline change writes no parents at all', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => const [rm, abm, mr]);
      when(() => remote.update('d1', any())).thenAnswer((_) async {});

      await repository.save(
        id: 'd1',
        name: 'Regional Manager',
        category: DesignationCategory.field,
        hierarchyLevel: 1,
        permissions: const {},
        downlineDesignationIds: const {'d2', 'd3'},
      );

      verifyNever(() => remote.updateParents(any()));
    });
  });

  group('delete', () {
    test('throws instead of deleting when the designation is assigned to an employee', () async {
      when(() => remote.isAssignedToAnyEmployee('d3')).thenAnswer((_) async => true);

      expect(() => repository.delete('d3'), throwsA(isA<Exception>()));
      verifyNever(() => remote.delete(any()));
    });

    test('deletes when nobody is assigned to it', () async {
      when(() => remote.isAssignedToAnyEmployee('d3')).thenAnswer((_) async => false);
      when(() => remote.delete('d3')).thenAnswer((_) async {});

      await repository.delete('d3');

      verify(() => remote.delete('d3')).called(1);
    });
  });
}
