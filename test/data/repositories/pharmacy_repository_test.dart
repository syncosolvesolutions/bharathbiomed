import 'package:bharathbiomedpharma/data/local/pharmacy_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/pharmacy_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/pharmacy_repository.dart';
import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPharmacyLocalDataSource extends Mock implements PharmacyLocalDataSource {}

class MockPharmacyRemoteDataSource extends Mock implements PharmacyRemoteDataSource {}

void main() {
  late MockPharmacyLocalDataSource local;
  late MockPharmacyRemoteDataSource remote;
  late PharmacyRepository repository;

  const pharmacy = Pharmacy(id: 'p1', name: 'City Chemist', linkedDoctorIds: ['d1', 'd2']);

  setUp(() {
    local = MockPharmacyLocalDataSource();
    remote = MockPharmacyRemoteDataSource();
    repository = PharmacyRepository(local: local, remote: remote);
  });

  group('sync', () {
    test('fetches from Firestore and overwrites the local cache', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [pharmacy]);
      when(() => local.replaceAll(any())).thenAnswer((_) async {});

      final result = await repository.sync();

      expect(result, [pharmacy]);
      verify(() => local.replaceAll([pharmacy])).called(1);
    });
  });

  group('hasRemoteChanges', () {
    test('is false when remote matches local', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [pharmacy]);
      when(() => local.getPharmacies()).thenAnswer((_) async => [pharmacy]);

      expect(await repository.hasRemoteChanges(), isFalse);
    });

    test('is true when linked doctors differ', () async {
      const updated = Pharmacy(id: 'p1', name: 'City Chemist', linkedDoctorIds: ['d1']);
      when(() => remote.fetchAll()).thenAnswer((_) async => [updated]);
      when(() => local.getPharmacies()).thenAnswer((_) async => [pharmacy]);

      expect(await repository.hasRemoteChanges(), isTrue);
    });
  });

  group('loadLinkedToDoctor', () {
    test('filters the local cache to pharmacies linked to the given doctor', () async {
      const other = Pharmacy(id: 'p2', name: 'Other Chemist', linkedDoctorIds: ['d9']);
      when(() => local.getPharmacies()).thenAnswer((_) async => [pharmacy, other]);

      final result = await repository.loadLinkedToDoctor('d1');

      expect(result, [pharmacy]);
    });
  });
}
