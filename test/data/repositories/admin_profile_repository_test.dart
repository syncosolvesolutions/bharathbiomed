import 'package:bharathbiomedpharma/data/remote/admin_profile_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/admin_profile_repository.dart';
import 'package:bharathbiomedpharma/domain/models/admin_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAdminProfileRemoteDataSource extends Mock implements AdminProfileRemoteDataSource {}

void main() {
  late MockAdminProfileRemoteDataSource remote;
  late AdminProfileRepository repository;

  const profile = AdminProfile(uid: 'admin1', firstName: 'Bharath', lastName: 'Admin', mobileNumber: '9999999999');

  setUp(() {
    remote = MockAdminProfileRemoteDataSource();
    repository = AdminProfileRepository(remote: remote);
  });

  test('watch delegates to the remote data source', () {
    when(() => remote.watch('admin1')).thenAnswer((_) => Stream.value(profile));

    expect(repository.watch('admin1'), emits(profile));
  });

  test('save delegates to the remote data source', () async {
    when(() => remote.save(profile)).thenAnswer((_) async {});

    await repository.save(profile);

    verify(() => remote.save(profile)).called(1);
  });
}
