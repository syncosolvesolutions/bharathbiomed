import 'package:firebase_auth/firebase_auth.dart';
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
    // Stay in sync with Firebase's own stream so sign-outs/session restores
    // triggered elsewhere still reflect here.
    ref.listen<AsyncValue<User?>>(authStateChangesProvider, (previous, next) {
      next.whenData((user) => state = AsyncData(user));
    });
    return ref.read(authRepositoryProvider).authStateChanges().first;
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signIn(email, password));
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  /// Doesn't touch [state] — the signed-in user's identity doesn't change,
  /// only their password. Callers should catch and report failures
  /// themselves (see [features/auth/change_password_screen.dart]).
  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return ref.read(authRepositoryProvider).changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
  }
}
