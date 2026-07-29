import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/error/crash_reporter.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/utils/app_orientation.dart';
import 'firebase_options.dart';

/// Bootstraps Firebase and global error reporting, then hands off to [BharathBioMedApp].
/// The mobile app is tablet-only, fullscreen (kiosk-style), and supports
/// both portrait and landscape everywhere except the slideshow presentation
/// screen, which forces landscape for itself — see
/// features/slideshow/slideshow_screen.dart — hence the permissive
/// (portrait + landscape) orientation set and system UI overlay removal
/// below. None of that applies to the web build (the admin console, see
/// `features/admin_web/SKILL.md`) — a browser tab has no orientation lock
/// or system UI overlays to manage, so those calls are skipped on
/// `kIsWeb`. Crashlytics has no web SDK at all (unlike Analytics, which
/// does support web) — every Crashlytics call below is skipped on web for
/// the same reason `CrashReporter`'s own doc comment already limited it to
/// Android/iOS.
void main() async {
  BindingBase.debugZoneErrorsAreFatal = true;
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations(defaultOrientations);
  }
  // Keep the native splash on screen until LoginScreen removes it post-frame,
  // so there's no flash of a blank window while Firebase initializes below.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore's own offline cache is unused by this app (ProductRepository
  // uses its own sqflite cache instead), but persistence is left on since
  // it's harmless and free.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  if (!kIsWeb) {
    // Must be registered before runApp so a catalog-update push can trigger
    // a sync even while the app is backgrounded or fully terminated.
    // Foreground handling (PushNotificationService.initialize) is wired up
    // from app.dart once a BuildContext/Ref exists. Web push needs a
    // service worker this project doesn't have set up yet, and the admin
    // console has no offline-sync flow to trigger anyway.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await CrashReporter.initialize();
  }

  runApp(const ProviderScope(child: BharathBioMedApp()));

  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }
}
