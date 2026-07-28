import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/employee.dart';

/// What an MR actually logs in with, returned after create/update so the
/// admin can be shown the right thing to hand over.
class EmployeeCredentials {
  const EmployeeCredentials({required this.username, required this.loginEmail});

  final String username;
  final String loginEmail;
}

/// Employee accounts are never written to directly from the client: creation,
/// edits, deletion, and password resets go through Cloud Functions (see
/// functions/src/index.ts), which use the Admin SDK so the admin's own
/// signed-in session is never disturbed. Reading the list back is a plain
/// Firestore query — rules restrict the `Users` collection to the admin
/// account.
class EmployeeRemoteDataSource {
  EmployeeRemoteDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<Employee>> fetchAll() async {
    debugPrint('EmployeeRemoteDataSource.fetchAll: querying Users collection where role=mr');
    final snapshot = await _firestore.collection('Users').where('role', isEqualTo: 'mr').get();
    final employees = snapshot.docs.map((doc) => Employee.fromJson(doc.id, doc.data())).toList();
    employees.sort((a, b) => a.displayName.compareTo(b.displayName));
    debugPrint('EmployeeRemoteDataSource.fetchAll: fetched ${employees.length} employees');
    return employees;
  }

  /// Streams the signed-in MR's own profile for the Profile screen — works
  /// once firestore.rules lets a caller read `Users/{uid}` where `uid ==
  /// request.auth.uid`. Emits `null` if the doc doesn't exist.
  Stream<Employee?> watchMine(String uid) {
    debugPrint('EmployeeRemoteDataSource.watchMine: watching own Users doc uid=$uid');
    return _firestore.collection('Users').doc(uid).snapshots().map((doc) {
      debugPrint('EmployeeRemoteDataSource.watchMine: snapshot uid=$uid exists=${doc.exists}');
      if (!doc.exists) return null;
      return Employee.fromJson(doc.id, doc.data()!);
    });
  }

  /// [username] is chosen by the admin (auto-suggested from the name client
  /// side, but editable) rather than derived server-side, so a collision is
  /// rejected outright — same as [update] — instead of silently appended
  /// with a suffix. [email] is required — it becomes this account's real
  /// sign-in email (the Cloud Function also enforces this, so a modified
  /// client can't skip it).
  Future<EmployeeCredentials> create({
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
  }) async {
    debugPrint('EmployeeRemoteDataSource.create: calling createEmployee callable username=$username email=$email');
    final result = await _functions.httpsCallable('createEmployee').call({
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'password': password,
      'designation': designation,
      'areaName': areaName,
      'email': email,
      if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    debugPrint('EmployeeRemoteDataSource.create: createEmployee succeeded username=${data['username']}');
    return EmployeeCredentials(username: data['username'] as String, loginEmail: data['loginEmail'] as String);
  }

  Future<EmployeeCredentials> update({
    required String uid,
    required String firstName,
    required String lastName,
    required String username,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
  }) async {
    debugPrint('EmployeeRemoteDataSource.update: calling updateEmployee callable uid=$uid username=$username');
    final result = await _functions.httpsCallable('updateEmployee').call({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'designation': designation,
      'areaName': areaName,
      'email': email,
      if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    debugPrint('EmployeeRemoteDataSource.update: updateEmployee succeeded uid=$uid');
    return EmployeeCredentials(username: username, loginEmail: data['loginEmail'] as String);
  }

  /// Self-service edit for the signed-in MR's own profile (Profile screen) —
  /// only touches firstName/lastName/mobileNumber/photoUrl/dateOfBirth, per
  /// `updateMyEmployeeProfile` in functions/src/index.ts. Username and email
  /// are never sent — the Cloud Function doesn't accept them from this call
  /// at all.
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
  }) async {
    debugPrint('EmployeeRemoteDataSource.updateMyProfile: calling updateMyEmployeeProfile callable');
    await _functions.httpsCallable('updateMyEmployeeProfile').call({
      'firstName': firstName,
      'lastName': lastName,
      if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobileNumber': mobileNumber,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
    });
    debugPrint('EmployeeRemoteDataSource.updateMyProfile: updateMyEmployeeProfile succeeded');
  }

  Future<void> delete(String uid) async {
    debugPrint('EmployeeRemoteDataSource.delete: calling deleteEmployee callable uid=$uid');
    await _functions.httpsCallable('deleteEmployee').call({'uid': uid});
    debugPrint('EmployeeRemoteDataSource.delete: deleteEmployee succeeded uid=$uid');
  }

  Future<void> resetPassword(String uid, String newPassword) async {
    debugPrint('EmployeeRemoteDataSource.resetPassword: calling resetEmployeePassword callable uid=$uid');
    await _functions.httpsCallable('resetEmployeePassword').call({'uid': uid, 'newPassword': newPassword});
    debugPrint('EmployeeRemoteDataSource.resetPassword: resetEmployeePassword succeeded uid=$uid');
  }

  /// Suspends ([disabled] true) or reactivates ([disabled] false) an MR's
  /// account without deleting it — see `setEmployeeStatus` in
  /// functions/src/index.ts.
  Future<void> setStatus(String uid, {required bool disabled}) async {
    debugPrint('EmployeeRemoteDataSource.setStatus: calling setEmployeeStatus callable uid=$uid disabled=$disabled');
    await _functions.httpsCallable('setEmployeeStatus').call({'uid': uid, 'disabled': disabled});
    debugPrint('EmployeeRemoteDataSource.setStatus: setEmployeeStatus succeeded uid=$uid');
  }
}
