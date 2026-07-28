import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/admin_notification.dart';

/// Only ever populated by the `onEmployeeDobChanged` Cloud Function trigger
/// (functions/src/index.ts) — clients can read and mark-as-read but never
/// create or delete (see firestore.rules).
class AdminNotificationsRemoteDataSource {
  AdminNotificationsRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminNotification>> watchAll() {
    debugPrint('AdminNotificationsRemoteDataSource.watchAll: watching AdminNotifications collection');
    return _firestore
        .collection('AdminNotifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('AdminNotificationsRemoteDataSource.watchAll: snapshot count=${snapshot.docs.length}');
      return snapshot.docs.map((doc) => AdminNotification.fromJson(doc.id, doc.data())).toList();
    });
  }

  Future<void> markRead(String id) async {
    debugPrint('AdminNotificationsRemoteDataSource.markRead: id=$id');
    await _firestore.collection('AdminNotifications').doc(id).update({'read': true});
    debugPrint('AdminNotificationsRemoteDataSource.markRead: marked read id=$id');
  }
}
