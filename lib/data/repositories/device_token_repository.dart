import '../remote/device_token_remote_data_source.dart';

class DeviceTokenRepository {
  DeviceTokenRepository({DeviceTokenRemoteDataSource? remote}) : _remote = remote ?? DeviceTokenRemoteDataSource();

  final DeviceTokenRemoteDataSource _remote;

  Future<void> save(String uid, String token) => _remote.save(uid, token);
}
