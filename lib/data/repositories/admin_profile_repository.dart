import 'package:flutter/foundation.dart';

import '../../domain/models/admin_profile.dart';
import '../remote/admin_profile_remote_data_source.dart';

class AdminProfileRepository {
  AdminProfileRepository({AdminProfileRemoteDataSource? remote})
      : _remote = remote ?? AdminProfileRemoteDataSource();

  final AdminProfileRemoteDataSource _remote;

  Stream<AdminProfile?> watch(String uid) {
    debugPrint('AdminProfileRepository.watch: uid=$uid');
    return _remote.watch(uid);
  }

  Future<void> save(AdminProfile profile) {
    debugPrint('AdminProfileRepository.save: uid=${profile.uid}');
    return _remote.save(profile);
  }
}
