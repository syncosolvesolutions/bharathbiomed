import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Turns exceptions from Firebase/network/local calls into short messages
/// safe to show directly in a snackbar or dialog. Sales reps using this app
/// in the field aren't going to know what a `FirebaseException` code means —
/// they need "check your connection" or "wrong password", not a stack trace.
class UserFacingError {
  UserFacingError._();

  static String describe(Object error) {
    if (error is FirebaseAuthException) return _authMessage(error);
    if (error is FirebaseException) return _firestoreMessage(error);
    if (error is TimeoutException) return 'The request timed out. Check your connection and try again.';
    if (error is SocketException) return 'No internet connection. Check your network and try again.';
    if (error is StateError) return 'You need to be signed in to do that. Please sign in and try again.';
    return error.toString();
  }

  static String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return error.message ?? 'Failed to sign in. Please check your credentials and try again.';
    }
  }

  static String _firestoreMessage(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach the server. Check your connection and try again.';
      case 'permission-denied':
        return 'You don\'t have permission to sync this data. Contact your administrator.';
      default:
        return error.message ?? 'Something went wrong talking to the server.';
    }
  }
}
