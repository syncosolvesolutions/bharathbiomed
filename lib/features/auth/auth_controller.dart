import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Raw Firebase auth-state stream. Used by the router to redirect a user
/// straight to the catalog if a session already exists on launch.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    debugPrint('AuthController.build: initializing auth state');
    // Stay in sync with Firebase's own stream so sign-outs/session restores
    // triggered elsewhere still reflect here.
    ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
      next.whenData((user) => state = AsyncData(user));
    });
    debugPrint('AuthController.build: reading initial auth state from authRepository');
    final user = await ref.read(authRepositoryProvider).authStateChanges().first;
    debugPrint('AuthController.build: initial auth state resolved, signedIn=${user != null}');
    return user;
  }

  Future<void> signIn(String email, String password) async {
    debugPrint('AuthController.signIn: attempting sign-in for email=$email');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signIn(email, password));
    debugPrint('AuthController.signIn: completed, hasError=${state.hasError}');
  }

  Future<void> signOut() async {
    debugPrint('AuthController.signOut: signing out current user');
    await ref.read(authRepositoryProvider).signOut();
    debugPrint('AuthController.signOut: signed out successfully');
    state = const AsyncData(null);
  }

  /// Doesn't touch [state] — the signed-in user's identity doesn't change,
  /// only their password. Callers should catch and report failures
  /// themselves (see [features/auth/change_password_screen.dart]).
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    debugPrint('AuthController.changePassword: attempting password change');
    return ref
        .read(authRepositoryProvider)
        .changePassword(currentPassword: currentPassword, newPassword: newPassword)
        .then((value) {
      debugPrint('AuthController.changePassword: password changed successfully');
      return value;
    });
  }

  Future<void> sendPasswordResetEmail(String email) {
    debugPrint('AuthController.sendPasswordResetEmail: sending reset email to email=$email');
    return ref.read(authRepositoryProvider).sendPasswordResetEmail(email).then((value) {
      debugPrint('AuthController.sendPasswordResetEmail: reset email sent successfully');
      return value;
    });
  }
}
