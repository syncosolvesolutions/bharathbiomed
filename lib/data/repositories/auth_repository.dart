import 'package:firebase_auth/firebase_auth.dart';

import '../remote/auth_remote_data_source.dart';

/// Auth-facing API the rest of the app depends on, independent of Firebase.
class AuthRepository {
  AuthRepository({AuthRemoteDataSource? remote}) : _remote = remote ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _remote;

  Stream<User?> authStateChanges() => _remote.authStateChanges();

  User? get currentUser => _remote.currentUser;

  Future<User?> signIn(String email, String password) {
    return _remote.signInWithEmailAndPassword(email, password);
  }

  Future<void> signOut() => _remote.signOut();
}
