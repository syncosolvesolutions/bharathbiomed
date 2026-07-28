import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around FirebaseAuth so nothing else in the app imports
/// firebase_auth directly.
class AuthRemoteDataSource {
  AuthRemoteDataSource({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    debugPrint('AuthRemoteDataSource.signInWithEmailAndPassword: signing in email=$email');
    final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    debugPrint('AuthRemoteDataSource.signInWithEmailAndPassword: signed in uid=${credential.user?.uid}');
    return credential.user;
  }

  Future<void> signOut() async {
    debugPrint('AuthRemoteDataSource.signOut: signing out current user');
    await _firebaseAuth.signOut();
    debugPrint('AuthRemoteDataSource.signOut: signed out successfully');
  }

  /// Changes the signed-in user's own password. Firebase requires a recent
  /// sign-in for sensitive operations like this, so we reauthenticate with
  /// their current password first rather than surfacing a confusing
  /// `requires-recent-login` error.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    debugPrint('AuthRemoteDataSource.changePassword: changing password for current user');
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user to change the password for.');
    }
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    debugPrint('AuthRemoteDataSource.changePassword: reauthenticating uid=${user.uid}');
    await user.reauthenticateWithCredential(credential);
    debugPrint('AuthRemoteDataSource.changePassword: reauthenticated, updating password uid=${user.uid}');
    await user.updatePassword(newPassword);
    debugPrint('AuthRemoteDataSource.changePassword: password updated uid=${user.uid}');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    debugPrint('AuthRemoteDataSource.sendPasswordResetEmail: sending reset email to email=$email');
    await _firebaseAuth.sendPasswordResetEmail(email: email);
    debugPrint('AuthRemoteDataSource.sendPasswordResetEmail: reset email sent to email=$email');
  }
}
