import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Records handled (caught) errors — the ones already shown to the user via
/// a dialog/snackbar and then discarded. [CrashReporter] only ever sees
/// fatal/uncaught errors, so without this, a report like "it just says
/// failed to create employee" has no trace anywhere to diagnose *why*:
/// nothing reaches Crashlytics, and nothing is printed even in a local debug
/// console beyond whatever the UI itself renders.
///
/// Call this from a catch block right alongside (not instead of) the
/// existing user-facing error UI — it's a side-channel for diagnosis, not a
/// replacement for [UserFacingError].
class AppLogger {
  AppLogger._();

  static void error(String feature, String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[$feature] $message${error != null ? ': $error' : ''}');
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: '$feature: $message',
        fatal: false,
      ),
    );
  }
}
