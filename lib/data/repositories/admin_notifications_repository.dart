import 'package:flutter/foundation.dart';

import '../../domain/models/admin_notification.dart';
import '../remote/admin_notifications_remote_data_source.dart';

class AdminNotificationsRepository {
  AdminNotificationsRepository({AdminNotificationsRemoteDataSource? remote})
      : _remote = remote ?? AdminNotificationsRemoteDataSource();

  final AdminNotificationsRemoteDataSource _remote;

  Stream<List<AdminNotification>> watchAll() {
    debugPrint('AdminNotificationsRepository.watchAll: watching notifications');
    return _remote.watchAll();
  }

  Future<void> markRead(String id) {
    debugPrint('AdminNotificationsRepository.markRead: id=$id');
    return _remote.markRead(id);
  }
}
