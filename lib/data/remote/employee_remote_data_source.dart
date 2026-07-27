import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    final snapshot = await _firestore.collection('Users').where('role', isEqualTo: 'mr').get();
    final employees = snapshot.docs.map((doc) => Employee.fromJson(doc.id, doc.data())).toList();
    employees.sort((a, b) => a.displayName.compareTo(b.displayName));
    return employees;
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
  }) async {
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
    });
    final data = Map<String, dynamic>.from(result.data as Map);
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
  }) async {
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
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return EmployeeCredentials(username: username, loginEmail: data['loginEmail'] as String);
  }

  Future<void> delete(String uid) async {
    await _functions.httpsCallable('deleteEmployee').call({'uid': uid});
  }

  Future<void> resetPassword(String uid, String newPassword) async {
    await _functions.httpsCallable('resetEmployeePassword').call({'uid': uid, 'newPassword': newPassword});
  }

  /// Suspends ([disabled] true) or reactivates ([disabled] false) an MR's
  /// account without deleting it — see `setEmployeeStatus` in
  /// functions/src/index.ts.
  Future<void> setStatus(String uid, {required bool disabled}) async {
    await _functions.httpsCallable('setEmployeeStatus').call({'uid': uid, 'disabled': disabled});
  }
}
