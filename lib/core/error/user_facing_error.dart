import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Turns exceptions from Firebase/network/local calls into short messages
/// safe to show directly in a snackbar or dialog. Sales reps using this app
/// in the field aren't going to know what a `FirebaseException` code means —
/// they need "check your connection" or "wrong password", not a stack trace.
class UserFacingError {
  UserFacingError._();

  static String describe(Object error) {
    debugPrint('UserFacingError.describe: mapping error of type=${error.runtimeType}');
    if (error is FirebaseAuthException) return _authMessage(error);
    if (error is FirebaseFunctionsException) return _functionsMessage(error);
    if (error is FirebaseException) return _firestoreMessage(error);
    if (error is TimeoutException) return 'The request timed out. Check your connection and try again.';
    if (error is SocketException) return 'No internet connection. Check your network and try again.';
    if (error is StateError) return 'You need to be signed in to do that. Please sign in and try again.';
    return error.toString();
  }

  static String _authMessage(FirebaseAuthException error) {
    debugPrint('UserFacingError._authMessage: mapping auth error code=${error.code}');
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

  /// Cloud Functions callable errors (admin-only actions like create/edit/
  /// delete employee) use a different code namespace than Firestore's, and
  /// "unauthenticated" specifically means the request reached Firebase
  /// without a valid signed-in session attached — the one thing an admin can
  /// usually self-fix by signing out and back in, so the message says so
  /// instead of a generic failure.
  static String _functionsMessage(FirebaseFunctionsException error) {
    debugPrint('UserFacingError._functionsMessage: mapping functions error code=${error.code}');
    switch (error.code) {
      case 'unauthenticated':
        return 'Your session isn\'t valid anymore. Please log out and sign back in, then try again.';
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'already-exists':
        return error.message ?? 'That already exists.';
      case 'resource-exhausted':
        return error.message ?? 'Too many attempts. Please wait a moment and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach the server. Check your connection and try again.';
      default:
        return error.message ?? 'Something went wrong talking to the server.';
    }
  }

  static String _firestoreMessage(FirebaseException error) {
    debugPrint('UserFacingError._firestoreMessage: mapping firestore error code=${error.code}');
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
