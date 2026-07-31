import 'package:bharathbiomedpharma/data/local/doctor_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/doctor_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_repository.dart';
import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDoctorRemoteDataSource extends Mock implements DoctorRemoteDataSource {}

class MockDoctorLocalDataSource extends Mock implements DoctorLocalDataSource {}

void main() {
  late MockDoctorRemoteDataSource remote;
  late MockDoctorLocalDataSource local;
  late DoctorRepository repository;

  const doctor1 = Doctor(id: 'doc1', name: 'Dr. Anjali Verma', hospitalName: 'City Care Hospital');
  const doctor2 = Doctor(id: 'doc2', name: 'Dr. Ramesh Iyer', hospitalName: 'Apollo');

  setUp(() {
    remote = MockDoctorRemoteDataSource();
    local = MockDoctorLocalDataSource();
    repository = DoctorRepository(remote: remote, local: local);
  });

  group('sync', () {
    test('mrUid=null fetches every doctor (admin) and replaces the local cache', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [doctor1, doctor2]);
      when(() => local.replaceAll([doctor1, doctor2])).thenAnswer((_) async {});

      final result = await repository.sync();

      expect(result, [doctor1, doctor2]);
      verify(() => local.replaceAll([doctor1, doctor2])).called(1);
      verifyNever(() => remote.fetchAssignedTo(any()));
    });

    test('a non-null mrUid fetches only that MR\'s assigned doctors', () async {
      when(() => remote.fetchAssignedTo('mr1')).thenAnswer((_) async => [doctor1]);
      when(() => local.replaceAll([doctor1])).thenAnswer((_) async {});

      final result = await repository.sync(mrUid: 'mr1');

      expect(result, [doctor1]);
      verifyNever(() => remote.fetchAll());
    });
  });

  group('hasRemoteChanges', () {
    test('false when the remote list matches the local cache exactly', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [doctor1]);
      when(() => local.getDoctors()).thenAnswer((_) async => [doctor1]);

      expect(await repository.hasRemoteChanges(), isFalse);
    });

    test('true when the remote list differs from the local cache', () async {
      when(() => remote.fetchAll()).thenAnswer((_) async => [doctor1, doctor2]);
      when(() => local.getDoctors()).thenAnswer((_) async => [doctor1]);

      expect(await repository.hasRemoteChanges(), isTrue);
    });

    test('scopes the remote fetch to mrUid the same way sync() does', () async {
      when(() => remote.fetchAssignedTo('mr1')).thenAnswer((_) async => [doctor1]);
      when(() => local.getDoctors()).thenAnswer((_) async => [doctor1]);

      await repository.hasRemoteChanges(mrUid: 'mr1');

      verify(() => remote.fetchAssignedTo('mr1')).called(1);
      verifyNever(() => remote.fetchAll());
    });
  });

  group('local-cache passthroughs', () {
    test('hasCachedDoctors delegates to the local data source', () async {
      when(() => local.hasDoctors()).thenAnswer((_) async => true);
      expect(await repository.hasCachedDoctors(), isTrue);
    });

    test('loadCached delegates to the local data source', () async {
      when(() => local.getDoctors()).thenAnswer((_) async => [doctor1]);
      expect(await repository.loadCached(), [doctor1]);
    });
  });

  group('admin write operations', () {
    test('createDoctor delegates to the remote data source', () async {
      when(() => remote.addDoctor(doctor1)).thenAnswer((_) async => 'doc1');
      expect(await repository.createDoctor(doctor1), 'doc1');
    });

    test('updateDoctor delegates to the remote data source', () async {
      when(() => remote.updateDoctor(doctor1)).thenAnswer((_) async {});
      await repository.updateDoctor(doctor1);
      verify(() => remote.updateDoctor(doctor1)).called(1);
    });

    test('assignMr delegates to the remote data source', () async {
      when(() => remote.assignMr('doc1', mrUid: 'mr1', mrName: 'Rajesh')).thenAnswer((_) async {});
      await repository.assignMr('doc1', mrUid: 'mr1', mrName: 'Rajesh');
      verify(() => remote.assignMr('doc1', mrUid: 'mr1', mrName: 'Rajesh')).called(1);
    });

    test('assignMr with null unassigns the doctor', () async {
      when(() => remote.assignMr('doc1', mrUid: null, mrName: null)).thenAnswer((_) async {});
      await repository.assignMr('doc1', mrUid: null, mrName: null);
      verify(() => remote.assignMr('doc1', mrUid: null, mrName: null)).called(1);
    });

    test('deleteDoctor delegates to the remote data source', () async {
      when(() => remote.deleteDoctor('doc1')).thenAnswer((_) async {});
      await repository.deleteDoctor('doc1');
      verify(() => remote.deleteDoctor('doc1')).called(1);
    });
  });
}
