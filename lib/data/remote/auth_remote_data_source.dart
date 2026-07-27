import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth so nothing else in the app imports
/// firebase_auth directly.
class AuthRemoteDataSource {
  AuthRemoteDataSource({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  /// Changes the signed-in user's own password. Firebase requires a recent
  /// sign-in for sensitive operations like this, so we reauthenticate with
  /// their current password first rather than surfacing a confusing
  /// `requires-recent-login` error.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user to change the password for.');
    }
    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> sendPasswordResetEmail(String email) => _firebaseAuth.sendPasswordResetEmail(email: email);
}
