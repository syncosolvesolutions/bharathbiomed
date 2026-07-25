import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/error/crash_reporter.dart';
import 'firebase_options.dart';

/// Bootstraps Firebase and global error reporting, then hands off to [BharathBioMedApp].
/// This is a tablet-only, landscape-locked, fullscreen (kiosk-style) app —
/// hence the orientation lock and system UI overlay removal below.
void main() async {
  BindingBase.debugZoneErrorsAreFatal = true;
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Keep the native splash on screen until LoginScreen removes it post-frame,
  // so there's no flash of a blank window while Firebase initializes below.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore's own offline cache is unused by this app (ProductRepository
  // uses its own sqflite cache instead), but persistence is left on since
  // it's harmless and free.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await CrashReporter.initialize();

  runApp(const ProviderScope(child: BharathBioMedApp()));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
}
