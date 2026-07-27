import 'package:firebase_auth/firebase_auth.dart';

import '../../core/auth/employee_login.dart';
import '../remote/auth_remote_data_source.dart';

/// Auth-facing API the rest of the app depends on, independent of Firebase.
class AuthRepository {
  AuthRepository({AuthRemoteDataSource? remote}) : _remote = remote ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _remote;

  Stream<User?> authStateChanges() => _remote.authStateChanges();

  User? get currentUser => _remote.currentUser;

  /// [identifier] is whatever the user typed into the login field: the
  /// admin's real email, or an MR's plain username — see [resolveLoginEmail].
  Future<User?> signIn(String identifier, String password) {
    return _remote.signInWithEmailAndPassword(resolveLoginEmail(identifier), password);
  }

  Future<void> signOut() => _remote.signOut();

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _remote.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  /// Only works for an [identifier] that's a real email — see
  /// [resolveLoginEmail]. A bare username has no real inbox behind it, so
  /// there's nothing Firebase can send a reset link to; callers should
  /// check for '@' themselves and offer the admin-reset path instead.
  Future<void> sendPasswordResetEmail(String email) => _remote.sendPasswordResetEmail(email);
}
