import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/admin_profile.dart';

/// Unlike Employee profiles, the admin's own profile is safe to read/write
/// directly from the client — firestore.rules scopes `AdminProfile/{uid}` to
/// `isAdmin() && request.auth.uid == uid`, so this can never touch anyone
/// else's data.
class AdminProfileRemoteDataSource {
  AdminProfileRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AdminProfile?> watch(String uid) {
    debugPrint('AdminProfileRemoteDataSource.watch: watching AdminProfile doc uid=$uid');
    return _firestore.collection('AdminProfile').doc(uid).snapshots().map((doc) {
      debugPrint('AdminProfileRemoteDataSource.watch: snapshot uid=$uid exists=${doc.exists}');
      if (!doc.exists) return AdminProfile(uid: uid);
      return AdminProfile.fromJson(doc.id, doc.data()!);
    });
  }

  Future<void> save(AdminProfile profile) async {
    debugPrint('AdminProfileRemoteDataSource.save: writing AdminProfile doc uid=${profile.uid}');
    await _firestore.collection('AdminProfile').doc(profile.uid).set(profile.toJson(), SetOptions(merge: true));
    debugPrint('AdminProfileRemoteDataSource.save: wrote AdminProfile doc uid=${profile.uid}');
  }
}
