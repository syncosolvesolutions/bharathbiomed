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
}
