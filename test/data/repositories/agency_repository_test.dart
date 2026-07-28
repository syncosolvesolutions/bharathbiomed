import 'package:bharathbiomedpharma/data/local/agency_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/agency_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/agency_repository.dart';
import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAgencyLocalDataSource extends Mock implements AgencyLocalDataSource {}

class MockAgencyRemoteDataSource extends Mock implements AgencyRemoteDataSource {}

void main() {
  late MockAgencyLocalDataSource local;
  late MockAgencyRemoteDataSource remote;
  late AgencyRepository repository;

  const agency = Agency(id: 'a1', name: 'MedSupply Co', contactPerson: 'Ravi', phone: '9999999999');

  setUp(() {
    local = MockAgencyLocalDataSource();
    remote = MockAgencyRemoteDataSource();
    repository = AgencyRepository(local: local, remote: remote);
  });

  group('sync', () {
    test('fetches from Firestore and overwrites the local cache', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [agency]);
      when(() => local.replaceAll(any())).thenAnswer((_) async {});

      final result = await repository.sync();

      expect(result, [agency]);
      verify(() => local.replaceAll([agency])).called(1);
    });
  });

  group('hasRemoteChanges', () {
    test('is false when remote matches local, regardless of order', () async {
      const agency2 = Agency(id: 'a2', name: 'PharmaLink', contactPerson: 'Asha', phone: '8888888888');
      when(() => remote.fetchAll()).thenAnswer((_) async => [agency2, agency]);
      when(() => local.getAgencies()).thenAnswer((_) async => [agency, agency2]);

      expect(await repository.hasRemoteChanges(), isFalse);
    });

    test('is true when an agency differs', () async {
      const updated = Agency(id: 'a1', name: 'MedSupply Co (Renamed)', contactPerson: 'Ravi', phone: '9999999999');
      when(() => remote.fetchAll()).thenAnswer((_) async => [updated]);
      when(() => local.getAgencies()).thenAnswer((_) async => [agency]);

      expect(await repository.hasRemoteChanges(), isTrue);
    });
  });

  group('setActive', () {
    test('delegates to the remote data source', () async {
      when(() => remote.setActive('a1', active: false)).thenAnswer((_) async {});

      await repository.setActive('a1', active: false);

      verify(() => remote.setActive('a1', active: false)).called(1);
    });
  });
}
