import 'package:bharathbiomedpharma/data/remote/device_token_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/device_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceTokenRemoteDataSource extends Mock implements DeviceTokenRemoteDataSource {}

void main() {
  late MockDeviceTokenRemoteDataSource remote;
  late DeviceTokenRepository repository;

  setUp(() {
    remote = MockDeviceTokenRemoteDataSource();
    repository = DeviceTokenRepository(remote: remote);
  });

  test('save delegates to the remote data source', () async {
    when(() => remote.save('uid1', 'token1')).thenAnswer((_) async {});

    await repository.save('uid1', 'token1');

    verify(() => remote.save('uid1', 'token1')).called(1);
  });
}
