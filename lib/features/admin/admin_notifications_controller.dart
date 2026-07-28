import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/admin_notification.dart';

final adminNotificationsProvider = StreamProvider<List<AdminNotification>>((ref) {
  debugPrint('adminNotificationsProvider: watching admin notifications');
  return ref.watch(adminNotificationsRepositoryProvider).watchAll();
});

/// Drives the badge on the admin home app bar's bell icon.
final unreadAdminNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(adminNotificationsProvider).value ?? const [];
  return notifications.where((n) => !n.read).length;
});
