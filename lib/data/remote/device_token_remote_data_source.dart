import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// `DeviceTokens/{uid}`: this device's current FCM token, keyed by whoever's
/// signed in. Unlike the topic-based pushes used elsewhere in this app
/// (catalog updates, admin notifications), reminder-due and doctor-request-
/// reviewed pushes are targeted at one specific person, so the Cloud
/// Functions side needs a token to send to directly rather than a topic
/// broadcast every device shares. Never read back by any client — only the
/// Admin SDK reads it (see firestore.rules).
class DeviceTokenRemoteDataSource {
  DeviceTokenRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> save(String uid, String token) async {
    debugPrint('DeviceTokenRemoteDataSource.save: uid=$uid');
    await _firestore.collection('DeviceTokens').doc(uid).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
